const Joi = require('joi');

// Digits and a leading/inner "+" only, so nothing but a dialable number is stored.
const PHONE_PATTERN = /^[+\d]*$/;

/** Support contact details; every field optional and may be cleared with ''. */
exports.supportContactSchema = Joi.object({
  phone: Joi.string().pattern(PHONE_PATTERN).max(20).allow('').optional(),
  whatsapp: Joi.string().pattern(PHONE_PATTERN).max(20).allow('').optional(),
  email: Joi.string().email().max(254).allow('').optional(),
  website: Joi.string().uri({ scheme: ['http', 'https'] }).max(255).allow('').optional()
});

exports.updateConfigSchema = Joi.object({
  academicYear: Joi.string().optional(),
  activeTerm: Joi.string().optional(),
  preferences: Joi.object().optional(),
  authSettings: Joi.object({
    enableRollNumberLogin: Joi.boolean().optional()
  }).unknown(true).optional(),
  performanceSettings: Joi.object({
    redBelow: Joi.number().min(0).max(99).optional(),
    yellowBelow: Joi.number().min(1).max(100).optional()
  }).optional(),
  appUpdate: Joi.object({
    latestVersion: Joi.string().optional().allow('', null),
    minRequiredVersion: Joi.string().optional().allow('', null),
    isMandatory: Joi.boolean().optional(),
    updateUrl: Joi.string().optional().allow('', null),
    updateNotes: Joi.string().optional().allow('', null)
  }).unknown(true).optional(),
  supportContact: exports.supportContactSchema.optional(),
  neetExamConfig: Joi.object({
    examTitle: Joi.string().optional().allow('', null),
    examDate: Joi.date().iso().optional().allow(null, ''),
    targetDateLabel: Joi.string().optional().allow('', null),
    isTentative: Joi.boolean().optional(),
    startDate: Joi.date().iso().optional().allow(null, ''),
    subtitle: Joi.string().optional().allow('', null),
    daysLabel: Joi.string().optional().allow('', null)
  }).unknown(true).optional()
}).unknown(true);
