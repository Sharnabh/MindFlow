const express = require('express');
const router = express.Router();
const documentController = require('../controllers/documentController');

// Create a new document
router.post('/', documentController.createDocument);

// Get document details
router.get('/:documentId', documentController.getDocument);

// Generate share link
router.post('/:documentId/share', documentController.createShareLink);

// Add collaborator
router.post('/:documentId/collaborators', documentController.addCollaborator);

module.exports = router; 