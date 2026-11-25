// Pure grading helpers shared by submitExam, practice and the analysis
// endpoints, so the score saved at submit and the per-question review never
// disagree. Ported from ARKE; Prepzo keeps its request coercion and the rule
// that an un-keyed typed question never costs negative marks.
const mongoose = require('mongoose');

/** Max stored length of a typed (integer/numerical) answer. */
const MAX_SUBJECTIVE_ANSWER_LENGTH = 64;

const OBJECT_ID_HEX = /^[0-9a-fA-F]{24}$/;

/**
 * True only for real 24-hex ObjectIds. mongoose's isValid alone also accepts
 * any 12-character string (e.g. "123456789012"), which would let a typed
 * number such as "4" style input slip through as an option id.
 * @param {*} value
 * @returns {boolean}
 */
const isObjectIdString = (value) =>
  (typeof value === 'string' || (value && typeof value.toString === 'function')) &&
  OBJECT_ID_HEX.test(String(value)) &&
  mongoose.Types.ObjectId.isValid(String(value));

/**
 * Normalise the answer fields of a save-answer request body.
 *
 * Old mobile builds send a typed integer in `selectedOptionId`; we route any
 * non-ObjectId value there into `subjectiveAnswerText` so it is stored instead
 * of failing the ObjectId cast. Passing neither (or null/empty) clears both.
 *
 * @param {{selectedOptionId?: *, subjectiveAnswerText?: *, selectedOptionIds?: Array, numericAnswer?: *}} body
 * @returns {{selectedOptionId: (string|null), subjectiveAnswerText: (string|null), selectedOptionIds?: string[], numericAnswer?: (string|null)}}
 */
const coerceAnswerInput = (body = {}) => {
  const { selectedOptionId, subjectiveAnswerText } = body;
  let optionId = null;
  let text = null;

  if (selectedOptionId !== undefined && selectedOptionId !== null && String(selectedOptionId).trim() !== '') {
    if (isObjectIdString(selectedOptionId)) optionId = String(selectedOptionId);
    else text = String(selectedOptionId);
  }
  // An explicit text field wins over the legacy fallback.
  if (subjectiveAnswerText !== undefined && subjectiveAnswerText !== null && String(subjectiveAnswerText).trim() !== '') {
    text = String(subjectiveAnswerText);
  }
  if (text !== null) {
    text = text.trim().slice(0, MAX_SUBJECTIVE_ANSWER_LENGTH);
    if (!text) text = null;
  }
  // An option selection and a typed value are mutually exclusive.
  if (optionId) text = null;
  const result = { selectedOptionId: optionId, subjectiveAnswerText: text };
  // Newer app builds send multi-correct picks and typed numbers in their own
  // fields; keep them (validated) so gradeAnswer can use them.
  if (Array.isArray(body.selectedOptionIds)) {
    result.selectedOptionIds = body.selectedOptionIds.map(String).filter(isObjectIdString);
  }
  if (body.numericAnswer !== undefined) {
    const n = body.numericAnswer === null ? '' : String(body.numericAnswer).trim().slice(0, MAX_SUBJECTIVE_ANSWER_LENGTH);
    result.numericAnswer = n === '' ? null : n;
  }
  return result;
};


const stripHtml = (value) => String(value ?? '')
  .replace(/<[^>]*>/g, ' ')
  .replace(/&nbsp;| /gi, ' ')
  .replace(/\s+/g, ' ')
  .trim();

// An option with no text and no image is a placeholder ("A", "(B)", "") that
// some imports create for typed-answer questions; it is not a real choice.
const isPlaceholderOption = (option) => {
  if (!option) return true;
  if (option.imageUrl && String(option.imageUrl).trim()) return false;
  const text = stripHtml(option.text);
  return text === '' || /^(?:\(?[A-Da-d1-4]\)?[.)]?|option\s*[A-Da-d1-4])$/i.test(text);
};

const hasRealOptions = (q) => Array.isArray(q?.options) && q.options.some((o) => !isPlaceholderOption(o));

const isTypedAnswerQuestion = (q) => {
  if (['INTEGER', 'NUMERICAL'].includes(q?.type)) return true;
  if (q?.type === 'FILL_BLANKS') return true;
  return !hasRealOptions(q) && Boolean(stripHtml(q?.correctAnswerText));
};

const hasValue = (v) => v !== undefined && v !== null && String(v).trim() !== '';

// The typed value of an answer, whichever field an app version stored it in.
const typedValue = (ans) => {
  if (!ans) return '';
  if (hasValue(ans.numericAnswer)) return String(ans.numericAnswer).trim();
  if (hasValue(ans.subjectiveAnswerText)) return String(ans.subjectiveAnswerText).trim();
  return '';
};

const answerHasValue = (ans) => Boolean(ans) && (
  hasValue(ans.selectedOptionId) ||
  (Array.isArray(ans.selectedOptionIds) && ans.selectedOptionIds.length > 0) ||
  hasValue(ans.numericAnswer) ||
  hasValue(ans.subjectiveAnswerText)
);

// Concurrent saves can leave two entries for one question. Prefer the last
// entry that actually carries an answer, so an empty duplicate never hides it.
const findStudentAnswer = (answers, questionId) => {
  if (!Array.isArray(answers) || !questionId) return undefined;
  const id = String(questionId);
  const matches = answers.filter((a) => a?.questionId && String(a.questionId) === id);
  if (matches.length === 0) return undefined;
  for (let i = matches.length - 1; i >= 0; i -= 1) {
    if (answerHasValue(matches[i])) return matches[i];
  }
  return matches[matches.length - 1];
};

const toNumber = (value) => {
  const s = String(value).replace(/,/g, '').trim();
  if (s === '' || !/^[-+]?(?:\d+\.?\d*|\.\d+)(?:e[-+]?\d+)?$/i.test(s)) return NaN;
  return Number(s);
};

// Accepted answers: "2", "2.00", "<p>2</p>", "Ans: 2", "2 or 3", "2; 3", a range
// "1.5 to 1.6" / "1.5-1.6", or the text of the option marked correct.
const expectedValues = (q) => {
  const raw = stripHtml(q?.correctAnswerText).replace(/^\[?ans(?:wer)?\.?\]?\s*[:\-]?\s*/i, '');
  const values = raw ? raw.split(/\s*(?:\bor\b|;)\s*/i).filter(Boolean) : [];
  if (values.length === 0 && Array.isArray(q?.options)) {
    q.options.filter((o) => o?.isCorrect).forEach((o) => {
      const t = stripHtml(o.text);
      if (t) values.push(t);
    });
  }
  return values;
};

const matchesExpected = (studentVal, expected) => {
  const student = String(studentVal).trim();
  const sNum = toNumber(student);
  const range = expected.match(/^([-+]?\d*\.?\d+)\s*(?:to|–|—|-(?=\s*\d))\s*([-+]?\d*\.?\d+)$/i);
  if (range && !Number.isNaN(sNum)) {
    const lo = Math.min(Number(range[1]), Number(range[2]));
    const hi = Math.max(Number(range[1]), Number(range[2]));
    if (sNum >= lo - 1e-9 && sNum <= hi + 1e-9) return true;
  }
  const eNum = toNumber(expected);
  if (!Number.isNaN(sNum) && !Number.isNaN(eNum)) {
    return Math.abs(sNum - eNum) < 1e-4 * Math.max(1, Math.abs(eNum));
  }
  return student.toLowerCase() === expected.trim().toLowerCase();
};

/**
 * Grades one question. Returns { attempted, isCorrect, gradable, marksObtained }.
 * A question only marked for review (no value) is not attempted.
 */
const gradeAnswer = (q, ans) => {
  const qMarks = q?.marks !== undefined && q?.marks !== null ? Number(q.marks) : 4;
  const qNegative = q?.negativeMarks !== undefined && q?.negativeMarks !== null ? Number(q.negativeMarks) : 1;
  // gradable=false means there is no answer key to mark against; such an
  // attempt scores 0 instead of costing negative marks.
  const result = (attempted, isCorrect, gradable = true) => ({
    attempted,
    isCorrect,
    gradable,
    marksObtained: !attempted || !gradable ? 0 : (isCorrect ? qMarks : -qNegative),
  });
  if (!ans) return result(false, false);

  if (isTypedAnswerQuestion(q)) {
    const studentVal = typedValue(ans);
    if (!studentVal) return result(false, false);
    const expected = expectedValues(q);
    if (expected.length === 0) return result(true, false, false);
    return result(true, expected.some((e) => matchesExpected(studentVal, e)));
  }

  const options = Array.isArray(q?.options) ? q.options : [];
  if (q?.type === 'MULTIPLE_CORRECT') {
    const selected = Array.isArray(ans.selectedOptionIds) && ans.selectedOptionIds.length > 0
      ? ans.selectedOptionIds.map(String)
      : (ans.selectedOptionId ? [String(ans.selectedOptionId)] : []);
    if (selected.length === 0) return result(false, false);
    const correct = options.filter((o) => o.isCorrect).map((o) => String(o._id));
    return result(true, correct.length === selected.length && correct.every((id) => selected.includes(id)));
  }

  if (!ans.selectedOptionId) return result(false, false);
  const correctOpt = options.find((o) => o.isCorrect);
  return result(true, Boolean(correctOpt) && String(correctOpt._id) === String(ans.selectedOptionId));
};

/**
 * Whether the student gave any answer (option, options, or typed value).
 * @param {object|null|undefined} answer
 * @returns {boolean}
 */
const isAttempted = (answer) => answerHasValue(answer);

/**
 * Compare a typed answer with one key value (see matchesExpected).
 * @param {string} given
 * @param {string} expected
 * @returns {boolean}
 */
const textMatches = (given, expected) => {
  const a = String(given ?? '').trim();
  const b = String(expected ?? '').trim();
  if (a === '' || b === '') return false;
  return matchesExpected(a, b);
};

module.exports = {
  MAX_SUBJECTIVE_ANSWER_LENGTH,
  coerceAnswerInput,
  isAttempted,
  textMatches,
  stripHtml,
  isPlaceholderOption,
  hasRealOptions,
  isTypedAnswerQuestion,
  typedValue,
  answerHasValue,
  findStudentAnswer,
  expectedValues,
  matchesExpected,
  gradeAnswer,
};
