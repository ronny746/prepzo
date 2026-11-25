const test = require('node:test');
const assert = require('node:assert/strict');
const { computeAnswerCounts, gradeStoredAnswer, coerceAnswerInput } = require('./practice.helpers');

const intQuestion = { questionId: 'q1', options: [], correctAnswerText: '42', marks: 4, negativeMarks: 1 };
const mcq = { questionId: 'q2', options: [{ _id: 'a', isCorrect: true }, { _id: 'b' }], marks: 4, negativeMarks: 1 };

test('integer answer in subjectiveAnswerText is graded correct', () => {
  const ans = coerceAnswerInput({ selectedOptionId: null, subjectiveAnswerText: '42.0' });
  assert.equal(gradeStoredAnswer(ans, intQuestion), 4);
  assert.equal(ans.isCorrect, true);
});

test('legacy builds sending the typed number in selectedOptionId are graded', () => {
  const ans = coerceAnswerInput({ selectedOptionId: '7' });
  assert.equal(ans.subjectiveAnswerText, '7');
  assert.equal(gradeStoredAnswer(ans, intQuestion), -1);
  assert.equal(ans.isCorrect, false);
});

test('MCQ grading is unchanged and unattempted scores 0', () => {
  assert.equal(gradeStoredAnswer({ selectedOptionId: 'a' }, mcq), 4);
  assert.equal(gradeStoredAnswer({ selectedOptionId: 'b' }, mcq), -1);
  assert.equal(gradeStoredAnswer({}, mcq), 0);
});

test('computeAnswerCounts tallies correct, wrong, attempted and is 0-safe', () => {
  const counts = computeAnswerCounts({
    questions: [{}, {}, {}, {}],
    answers: [
      { selectedOptionId: 'a', isCorrect: true },
      { subjectiveAnswerText: '9', isCorrect: false },
      { subjectiveAnswerText: '5', isCorrect: true },
      { status: 'NOT_ANSWERED', timeSpentSeconds: 3 },
    ],
  });
  assert.deepEqual(counts, { correctCount: 2, wrongCount: 1, attemptedCount: 3, totalQuestions: 4 });
  assert.deepEqual(computeAnswerCounts({}), { correctCount: 0, wrongCount: 0, attemptedCount: 0, totalQuestions: 0 });
  assert.equal(computeAnswerCounts({ totalQuestions: 10, answers: [] }).totalQuestions, 10);
});
