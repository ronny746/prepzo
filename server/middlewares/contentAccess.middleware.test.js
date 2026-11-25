const test = require('node:test');
const assert = require('node:assert/strict');
const BatchModel = require('../modules/batches/batches.model');
const { getStudentAccess } = require('./contentAccess.middleware');

const mockBatches = (batches) => {
  BatchModel.find = () => ({ populate: async () => batches });
};

test('getStudentAccess ORs each feature across enrolled batches', async () => {
  mockBatches([
    { courseId: { access: { liveClasses: true, dpps: false } } },
    { courseId: { access: { dpps: true, testSeries: false } } },
    { courseId: null },
  ]);
  assert.deepEqual(await getStudentAccess('u1'), {
    liveClasses: true, studyMaterials: false, dpps: true, testSeries: false,
  });
});

test('getStudentAccess is all false with no batches', async () => {
  mockBatches([]);
  assert.deepEqual(await getStudentAccess('u1'), {
    liveClasses: false, studyMaterials: false, dpps: false, testSeries: false,
  });
});
