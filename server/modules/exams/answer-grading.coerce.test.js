// Prepzo's request coercion and the un-keyed (gradable=false) rule. The
// saveAnswer / submitExam controller paths are covered by answer-grading.test.js.
const test = require('node:test');
const assert = require('node:assert');

const { coerceAnswerInput, gradeAnswer, textMatches, isAttempted } = require('./answer-grading');

const OID = '507f1f77bcf86cd799439011';
const OID2 = '507f1f77bcf86cd799439012';

test('coerceAnswerInput keeps a real ObjectId as the option', () => {
  assert.deepStrictEqual(coerceAnswerInput({ selectedOptionId: OID }),
    { selectedOptionId: OID, subjectiveAnswerText: null });
});

test('coerceAnswerInput moves legacy typed value into subjectiveAnswerText', () => {
  assert.deepStrictEqual(coerceAnswerInput({ selectedOptionId: ' 4 ' }),
    { selectedOptionId: null, subjectiveAnswerText: '4' });
  // 12-char strings pass mongoose isValid but are not 24-hex ids.
  assert.deepStrictEqual(coerceAnswerInput({ selectedOptionId: '123456789012' }),
    { selectedOptionId: null, subjectiveAnswerText: '123456789012' });
});

test('coerceAnswerInput prefers explicit text, trims and caps, and clears', () => {
  assert.strictEqual(coerceAnswerInput({ subjectiveAnswerText: ' -2.5 ' }).subjectiveAnswerText, '-2.5');
  assert.strictEqual(coerceAnswerInput({ subjectiveAnswerText: '9'.repeat(200) }).subjectiveAnswerText.length, 64);
  assert.deepStrictEqual(coerceAnswerInput({ selectedOptionId: null }),
    { selectedOptionId: null, subjectiveAnswerText: null });
  assert.deepStrictEqual(coerceAnswerInput({ selectedOptionId: null, subjectiveAnswerText: '  ' }),
    { selectedOptionId: null, subjectiveAnswerText: null });
  assert.deepStrictEqual(coerceAnswerInput({}), { selectedOptionId: null, subjectiveAnswerText: null });
});

test('textMatches numeric tolerance and string fallback', () => {
  assert.ok(textMatches('4', '4.0'));
  assert.ok(textMatches(' 0.1000000001 ', '0.1'));
  assert.ok(!textMatches('4', '5'));
  assert.ok(textMatches(' Abc ', 'aBC'));
  assert.ok(!textMatches('', ''));
});

test('gradeAnswer: MCQ behaviour unchanged', () => {
  const q = { options: [{ _id: OID, isCorrect: true }, { _id: OID2, isCorrect: false }] };
  assert.strictEqual(gradeAnswer(q, { selectedOptionId: OID }).isCorrect, true);
  assert.strictEqual(gradeAnswer(q, { selectedOptionId: OID2 }).isCorrect, false);
  assert.strictEqual(gradeAnswer(q, null).attempted, false);
  // Text on an MCQ never counts as correct.
  assert.strictEqual(gradeAnswer(q, { subjectiveAnswerText: '1' }).isCorrect, false);
});

test('gradeAnswer: integer question graded by correctAnswerText', () => {
  const q = { options: [], correctAnswerText: '4' };
  assert.deepStrictEqual(gradeAnswer(q, { subjectiveAnswerText: '4' }),
    { attempted: true, isCorrect: true, gradable: true, marksObtained: 4 });
  assert.strictEqual(gradeAnswer(q, { subjectiveAnswerText: '5' }).isCorrect, false);
  assert.strictEqual(gradeAnswer(q, {}).attempted, false);
  assert.strictEqual(gradeAnswer({ type: 'INTEGER', options: [], correctAnswerText: '' }, { subjectiveAnswerText: '1' }).gradable, false);
  assert.ok(isAttempted({ subjectiveAnswerText: '0' }));
});
