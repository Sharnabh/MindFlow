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
router.post('/:documentId/invite', documentController.addCollaborator);

// Get document collaborators
router.get('/:documentId/collaborators', documentController.getCollaborators);

// Update collaborator access
router.put('/:documentId/collaborators/:userId', documentController.updateCollaboratorAccess);

// Remove collaborator
router.delete('/:documentId/collaborators/:userId', documentController.removeCollaborator);

module.exports = router; 