const express = require('express');
const controller = require('./prepzo-paper-import.controller');

const router = express.Router();
router.post('/', controller.importPaper);

module.exports = router;
