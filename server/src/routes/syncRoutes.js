const express = require('express');
const router = express.Router();
const syncController = require('../controllers/syncController');

// Process offline changes
router.post('/:documentId/changes/batch', syncController.processOfflineChanges);

// Get changes since a specific version
router.get('/:documentId/changes', syncController.getChangesSince);

module.exports = router; 