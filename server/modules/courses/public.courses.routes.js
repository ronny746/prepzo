const express = require('express');
const router = express.Router();
const CourseModel = require('./courses.model');

const courseSlug = (name = '') => String(name).toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '') || 'course';

// Public route to get all active courses
router.get('/', async (req, res, next) => {
  try {
    const query = {
      isActive: true, 
      isPublished: { $ne: false },
      $or: [
        { endDate: { $exists: false } },
        { endDate: null },
        { endDate: { $gt: new Date() } }
      ]
    };
    if (req.query.instituteId) {
      query.instituteId = req.query.instituteId;
    }
    if (req.query.targetExam && req.query.targetExam !== 'ALL') {
      const strictGoal = req.query.strictGoal === 'true';
      query.$and = query.$and || [];
      query.$and.push({
        $or: strictGoal
          ? [
              { targetExam: req.query.targetExam },
              { targetExams: req.query.targetExam }
            ]
          : [
              { targetExam: req.query.targetExam },
              { targetExam: 'ALL' },
              { targetExam: { $exists: false } },
              { targetExams: req.query.targetExam },
              { targetExams: 'ALL' }
            ]
      });
    }
    if (req.query.targetClass && req.query.targetClass !== 'ALL') {
      query.$and = query.$and || [];
      query.$and.push({
        $or: [
          { targetClass: req.query.targetClass },
          { targetClass: 'ALL' },
          { targetClass: { $exists: false } },
          { targetClasses: req.query.targetClass },
          { targetClasses: 'ALL' }
        ]
      });
    }
    if (req.query.medium && req.query.medium !== 'ALL') {
      query.$and = query.$and || [];
      query.$and.push({
        $or: [
          { medium: req.query.medium },
          { medium: 'ALL' },
          { medium: { $exists: false } }
        ]
      });
    }
    const courses = await CourseModel.find(query)
      .populate('faculties', 'firstName lastName email phone profilePictureUrl metadata role')
      .sort({ updatedAt: -1, createdAt: -1 });
    return res.status(200).json({ success: true, data: courses.map(course => {
      const item = course.toObject();
      item.slug = item.slug || courseSlug(item.name);
      return item;
    }) });
  } catch (error) {
    next(error);
  }
});

// Public route to get a single course by id
router.get('/:id', async (req, res, next) => {
  try {
    const mongoose = require('mongoose');
    if (!req.params.id) return res.status(404).json({ success: false, message: 'Course not found' });
    const identifier = req.params.id.toLowerCase();
    const identity = mongoose.Types.ObjectId.isValid(identifier)
      ? { $or: [{ _id: identifier }, { slug: identifier }] }
      : { slug: identifier };
    let course = await CourseModel.findOne({
      ...identity,
      isActive: true, 
      isPublished: { $ne: false },
      $or: [
        { endDate: { $exists: false } },
        { endDate: null },
        { endDate: { $gt: new Date() } }
      ]
    }).populate('faculties', 'firstName lastName email phone profilePictureUrl metadata role');
    // Older courses may not have a persisted slug yet. Resolve their generated
    // name slug once so existing catalogue entries get the new URL format too.
    if (!course && !mongoose.Types.ObjectId.isValid(identifier)) {
      const candidates = await CourseModel.find({
        isActive: true,
        isPublished: { $ne: false },
        $or: [
          { endDate: { $exists: false } },
          { endDate: null },
          { endDate: { $gt: new Date() } }
        ]
      }).populate('faculties', 'firstName lastName email phone profilePictureUrl metadata role');
      course = candidates.find(item => (item.slug || courseSlug(item.name)) === identifier) || null;
    }
    if (!course) return res.status(404).json({ success: false, message: 'Course not found' });
    const data = course.toObject();
    data.slug = data.slug || courseSlug(data.name);
    return res.status(200).json({ success: true, data });
  } catch (error) {
    next(error);
  }
});

// Public route to get exams for a course
router.get('/:id/exams', async (req, res, next) => {
  try {
    const CourseService = require('./courses.service');
    // Extract token if present
    let user = null;
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      try {
        const jwt = require('jsonwebtoken');
        const token = authHeader.split(' ')[1];
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'secret');
        user = decoded;
      } catch (e) {}
    }
    const data = await CourseService.getCourseExams(req.params.id, user);
    return res.status(200).json({ success: true, data });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
