const { coerceAnswerInput, isAttempted, gradeAnswer } = require('../exams/answer-grading');

/** Statuses that mean the student committed an answer (not just viewed/marked). */
const COMMITTED_STATUSES = ['ANSWERED', 'ANSWERED_AND_MARKED_FOR_REVIEW'];

/**
 * Per-session answer tallies, computed from stored answers so old sessions
 * (which never stored counts) work too. Zero-safe for empty/missing arrays.
 * @param {{answers?: Array, questions?: Array, totalQuestions?: number}} session
 * @returns {{correctCount: number, wrongCount: number, attemptedCount: number, totalQuestions: number}}
 */
const computeAnswerCounts = (session) => {
  const answers = (session && session.answers) || [];
  let correctCount = 0;
  let wrongCount = 0;
  answers.forEach((a) => {
    if (!isAttempted(a)) return;
    if (a.isCorrect) correctCount += 1;
    else wrongCount += 1;
  });
  const totalQuestions = Number(session?.totalQuestions) || (session?.questions || []).length || 0;
  return { correctCount, wrongCount, attemptedCount: correctCount + wrongCount, totalQuestions };
};

/**
 * Grade one stored answer against its snapshot question and write the result
 * (isCorrect) onto it. Returns the score delta (0 when unattempted or ungradable
 * so an un-keyed integer question never costs negative marks).
 * @param {object} ans mongoose subdoc or plain answer
 * @param {object|undefined} question snapshot question
 * @returns {number}
 */
const gradeStoredAnswer = (ans, question) => {
  if (!question) return 0;
  const { attempted, isCorrect, gradable } = gradeAnswer(question, ans);
  ans.isCorrect = attempted && isCorrect;
  if (!attempted || !gradable) return 0;
  return isCorrect ? (question.marks || 4) : -(question.negativeMarks || 1);
};

module.exports = { COMMITTED_STATUSES, coerceAnswerInput, computeAnswerCounts, gradeStoredAnswer };
