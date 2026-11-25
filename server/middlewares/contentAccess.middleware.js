const BatchModel = require('../modules/batches/batches.model');
const { errorResponse } = require('../common/responses');

const ACCESS_FEATURES = ['liveClasses', 'studyMaterials', 'dpps', 'testSeries'];

/**
 * Compute which plan features a student can use: a feature is on when any
 * batch they are enrolled in belongs to a course whose `access[feature]` is true.
 * @param {string} userId
 * @returns {Promise<{liveClasses: boolean, studyMaterials: boolean, dpps: boolean, testSeries: boolean}>}
 */
const getStudentAccess = async (userId) => {
  const batches = await BatchModel.find({ students: userId }).populate('courseId', 'access');
  const access = {};
  for (const feature of ACCESS_FEATURES) {
    access[feature] = batches.some((b) => Boolean(b.courseId && b.courseId.access && b.courseId.access[feature]));
  }
  return access;
};

/**
 * Express handler for GET /users/me/access. Non-students are never plan-gated
 * (checkAccess bypasses them too), so they get everything true.
 */
const getMyAccess = async (req, res) => {
  try {
    const isStudent = String(req.user.role).toLowerCase() === 'student';
    const data = isStudent
      ? await getStudentAccess(req.user.userId)
      : Object.fromEntries(ACCESS_FEATURES.map((f) => [f, true]));
    return res.status(200).json({ success: true, data });
  } catch (err) {
    console.error('Access Fetch Error:', err);
    return errorResponse(res, 'Internal Server Error during access check', null, 500);
  }
};

/**
 * Middleware to check if the student has purchased a course that includes a specific feature.
 * @param {string} feature - e.g., 'liveClasses', 'studyMaterials', 'dpps', 'testSeries'
 */
const checkAccess = (feature) => {
  return async (req, res, next) => {
    try {
      // Allow if not a student (teachers, admins, etc. bypass this check)
      if (req.user.role !== 'student' && req.user.role !== 'STUDENT') {
        return next();
      }

      // Fetch all batches the student is enrolled in, populated with course access
      const access = await getStudentAccess(req.user.userId);
      const hasAccess = Boolean(access[feature]);

      if (!hasAccess) {
        const featureNames = {
          liveClasses: 'Live Classes',
          studyMaterials: 'Study Materials',
          dpps: 'DPPs',
          testSeries: 'Test Series'
        };
        const featureName = featureNames[feature] || feature;
        return errorResponse(res, `You do not have access to ${featureName} in your current plan.`, null, 403);
      }

      next();
    } catch (err) {
      console.error('Access Check Error:', err);
      return errorResponse(res, 'Internal Server Error during access check', null, 500);
    }
  };
};

// Individual tests can be marked FREE or PAID. FREE tests still require a
// logged-in student, but do not require course enrollment; PAID tests retain
// the existing enrollment/feature check.
const checkExamAccess = async (req, res, next) => {
  try {
    if (req.user.role !== 'student' && req.user.role !== 'STUDENT') return next();
    const Exam = require('../modules/exams/exam.model');
    const exam = await Exam.findById(req.params.id).select('accessMode');
    if (exam?.accessMode === 'FREE') return next();
    return checkAccess('testSeries')(req, res, next);
  } catch (err) {
    console.error('Exam Access Check Error:', err);
    return errorResponse(res, 'Internal Server Error during exam access check', null, 500);
  }
};

module.exports = {
  checkAccess,
  getStudentAccess,
  getMyAccess,
  checkExamAccess
};
