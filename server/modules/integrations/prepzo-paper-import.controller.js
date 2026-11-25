const crypto = require('crypto');
const mongoose = require('mongoose');
const Exam = require('../exams/exam.model');
const ExamQuestion = require('../exams/exam-question.model');
const QuestionBank = require('../exams/question-bank.model');
const Institute = require('../institutes/institutes.model');
const User = require('../users/users.model');

const safeEqual = (provided, expected) => {
  if (!provided || !expected) return false;
  const a = Buffer.from(String(provided));
  const b = Buffer.from(String(expected));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
};

const normalizeType = (question) => {
  const raw = String(question?.question_type || question?.type || '').toUpperCase();
  if (raw === 'TRUE_FALSE' || raw === 'TRUE/FALSE') return 'TRUE_FALSE';
  return 'MCQ';
};

const normalizeQuestion = (question, examId, order) => {
  const correctOption = String(question.correct_option ?? question.correctAnswer ?? '').trim().toLowerCase();
  const options = Array.isArray(question.options)
    ? question.options.map((option, index) => ({
        text: option?.text || option?.value || '',
        imageUrl: option?.image || option?.imageUrl || '',
        isCorrect: Boolean(
          (correctOption && String(option?.key ?? '').trim().toLowerCase() === correctOption) ||
          (correctOption && String.fromCharCode(97 + index) === correctOption) ||
          (question.correct_answer != null && String(option?.text || '').trim() === String(question.correct_answer).trim())
        ),
      }))
    : [];

  return {
    exam: examId,
    type: normalizeType(question),
    questionText: question.question || question.questionText || '',
    questionImageUrl: question.question_image || question.questionImageUrl || '',
    options,
    correctAnswerText: question.correct_answer ?? question.correctAnswerText ?? '',
    explanation: question.solution || question.explanation || '',
    difficulty: ['Easy', 'Medium', 'Hard'].includes(question.difficulty) ? question.difficulty : 'Medium',
    marks: Number(question.marks) || 4,
    negativeMarks: Number(question.negative_marks ?? question.negativeMarks ?? 1),
    order,
  };
};

const ensureQuestionBank = async ({ paper, instituteId, createdBy, sourceId }) => {
  const existing = await QuestionBank.findOne({ institute: instituteId, sourceSystem: 'arkebank', sourcePaperId: sourceId }).select('_id title totalQuestions totalMarks');
  if (existing) return { bank: existing, alreadyImported: true };

  const questions = paper.questions.map((question, index) => {
    const normalized = normalizeQuestion(question, null, index + 1);
    const { exam: _exam, order: _order, ...bankQuestion } = normalized;
    bankQuestion.subjectName = question.subject || 'General';
    bankQuestion.chapterName = question.topic || 'General';
    bankQuestion.topicName = question.sub_topic || 'General';
    return bankQuestion;
  });

  const bank = await QuestionBank.create({
    title: paper.title,
    description: paper.description || 'Imported from Prepzo Question Bank',
    bankType: 'FULL_PAPER',
    institute: instituteId,
    createdBy,
    questions,
    totalQuestions: questions.length,
    totalMarks: questions.reduce((sum, question) => sum + (Number(question.marks) || 4), 0),
    sourceSystem: 'arkebank',
    sourcePaperId: sourceId,
  });
  return { bank, alreadyImported: false };
};

exports.importPaper = async (req, res) => {
  try {
    const expectedSecret = process.env.PREPZO_IMPORT_SHARED_SECRET;
    if (!expectedSecret) return res.status(503).json({ success: false, message: 'PREPZO paper import is not configured.' });
    if (!safeEqual(req.header('x-prepzo-import-secret'), expectedSecret)) {
      return res.status(401).json({ success: false, message: 'Invalid import credentials.' });
    }

    const { paper, sourcePaperId, sourceTenant = 'prepzo' } = req.body || {};
    if (!paper || !paper.title || !Array.isArray(paper.questions) || paper.questions.length === 0) {
      return res.status(400).json({ success: false, message: 'A paper title and at least one question are required.' });
    }
    const sourceId = String(sourcePaperId || paper.id || '').trim();
    if (!sourceId) return res.status(400).json({ success: false, message: 'sourcePaperId is required for idempotent import.' });

    let instituteId = process.env.PREPZO_IMPORT_INSTITUTE_ID;
    if (!instituteId) {
      const institute = await Institute.findOne({ isActive: { $ne: false }, $or: [{ subdomain: 'prepzo' }, { name: /prepzo/i }] }).sort({ createdAt: 1 }).select('_id');
      instituteId = institute?._id?.toString();
    }
    if (!instituteId || !mongoose.Types.ObjectId.isValid(instituteId)) {
      return res.status(503).json({ success: false, message: 'PREPZO import institute is not configured.' });
    }

    let createdBy = process.env.PREPZO_IMPORT_CREATED_BY;
    if (!createdBy) {
      const admin = await User.findOne({ instituteId, role: 'admin', isActive: { $ne: false } }).select('_id');
      createdBy = admin?._id?.toString();
    }
    if (!createdBy || !mongoose.Types.ObjectId.isValid(createdBy)) {
      return res.status(503).json({ success: false, message: 'PREPZO import creator is not configured.' });
    }

    const existing = await Exam.findOne({ institute: instituteId, sourceSystem: 'arkebank', sourcePaperId: sourceId }).select('_id title totalQuestions totalMarks status');
    const questionBank = await ensureQuestionBank({ paper, instituteId, createdBy, sourceId });
    if (existing) return res.status(200).json({ success: true, alreadyImported: true, exam: existing, questionBank: questionBank.bank, message: 'Paper is already present in PREPZO Exam Papers and Full Papers.' });

    const now = new Date();
    const exam = await Exam.create({
      title: paper.title,
      description: paper.description || `Imported from ${sourceTenant}`,
      institute: instituteId,
      createdBy,
      examType: 'INTERNAL',
      status: 'DRAFT',
      sourceSystem: 'arkebank',
      sourcePaperId: sourceId,
      settings: {
        startTime: now,
        endTime: new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000),
        durationMinutes: Number.parseInt(String(paper.timeAllowed || '60'), 10) || 60,
        passingMarks: 0,
        showResultsAfterSubmit: true,
      },
      security: { requireFullScreen: true, disableCopyPaste: true, maxTabSwitchesAllowed: 3, enableProctoring: false, proctoringIntervalSeconds: 5 },
      totalQuestions: paper.questions.length,
      totalMarks: paper.questions.reduce((sum, question) => sum + (Number(question.marks) || 4), 0),
    });

    try {
      await ExamQuestion.insertMany(paper.questions.map((question, index) => normalizeQuestion(question, exam._id, index + 1)));
    } catch (error) {
      await Exam.deleteOne({ _id: exam._id });
      throw error;
    }

    return res.status(201).json({ success: true, alreadyImported: questionBank.alreadyImported, exam, questionBank: questionBank.bank, message: 'Paper imported into PREPZO Exam Papers and Full Papers.' });
  } catch (error) {
    console.error('[PREPZO IMPORT] Paper import failed:', error);
    return res.status(500).json({ success: false, message: error.message || 'Paper import failed.' });
  }
};
