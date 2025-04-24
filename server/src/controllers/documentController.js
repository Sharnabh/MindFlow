/**
 * Document Controller
 * Handles all document-related operations
 */
const admin = require('firebase-admin');
const { v4: uuidv4 } = require('uuid');
const logger = require('../utils/logger');

// Get the Firestore instance from the existing Admin SDK initialization
const db = admin.firestore();

/**
 * Create a new collaborative document
 */
exports.createDocument = async (req, res) => {
  try {
    const { title, initialTopics = [] } = req.body;
    const userId = req.user.uid;
    
    if (!title) {
      return res.status(400).json({ error: 'Document title is required' });
    }
    
    // Create document with initial data
    const docRef = db.collection('documents').doc();
    
    const document = {
      id: docRef.id,
      title,
      creatorId: userId,
      collaborators: [userId],
      activeUsers: [],
      version: 1,
      createdAt: new Date(),
      lastModified: new Date(),
      accessLevel: 'owner'
    };
    
    await docRef.set(document);
    
    // Store initial topics if provided
    if (initialTopics.length > 0) {
      const batch = db.batch();
      
      initialTopics.forEach(topic => {
        const topicRef = docRef.collection('topics').doc(topic.id || uuidv4());
        batch.set(topicRef, {
          ...topic,
          createdAt: new Date(),
          createdBy: userId
        });
      });
      
      await batch.commit();
    }
    
    logger.info(`Document created: ${docRef.id} by user ${userId}`);
    
    res.status(201).json({ 
      documentId: docRef.id,
      shareLink: generateShareLink(docRef.id) 
    });
    
  } catch (error) {
    logger.error(`Error creating document: ${error.message}`);
    res.status(500).json({ error: 'Failed to create document' });
  }
};

/**
 * Get document details
 */
exports.getDocument = async (req, res) => {
  try {
    const { documentId } = req.params;
    const userId = req.user.uid;
    
    const docRef = db.collection('documents').doc(documentId);
    const doc = await docRef.get();
    
    if (!doc.exists) {
      return res.status(404).json({ error: 'Document not found' });
    }
    
    const docData = doc.data();
    
    // Check access permissions
    if (!docData.collaborators.includes(userId) && docData.creatorId !== userId) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    // Get topics
    const topicsSnapshot = await docRef.collection('topics').get();
    const topics = [];
    
    topicsSnapshot.forEach(topic => {
      topics.push({
        id: topic.id,
        ...topic.data()
      });
    });
    
    // Get change history (limited to last 50 changes)
    const changesSnapshot = await docRef.collection('changes')
      .orderBy('timestamp', 'desc')
      .limit(50)
      .get();
      
    const changes = [];
    
    changesSnapshot.forEach(change => {
      changes.push({
        id: change.id,
        ...change.data()
      });
    });
    
    // Determine access level for current user
    let accessLevel = 'view';
    if (docData.creatorId === userId) {
      accessLevel = 'owner';
    } else if (docData.collaborators.includes(userId)) {
      accessLevel = 'edit';
    }
    
    res.json({
      id: doc.id,
      ...docData,
      topics,
      changes,
      currentUserAccess: accessLevel
    });
    
  } catch (error) {
    logger.error(`Error getting document: ${error.message}`);
    res.status(500).json({ error: 'Failed to get document' });
  }
};

/**
 * Generate a share link for a document
 */
exports.createShareLink = async (req, res) => {
  try {
    const { documentId } = req.params;
    const { accessLevel = 'view', expirationDays = 7 } = req.body;
    const userId = req.user.uid;
    
    // Validate access level
    if (!['view', 'edit'].includes(accessLevel)) {
      return res.status(400).json({ error: 'Invalid access level' });
    }
    
    // Check document exists and user has permission
    const docRef = db.collection('documents').doc(documentId);
    const doc = await docRef.get();
    
    if (!doc.exists) {
      return res.status(404).json({ error: 'Document not found' });
    }
    
    const docData = doc.data();
    
    // Only owner can create share links
    if (docData.creatorId !== userId) {
      return res.status(403).json({ error: 'Only the document owner can create share links' });
    }
    
    // Create share link document
    const linkId = uuidv4();
    const expires = new Date();
    expires.setDate(expires.getDate() + expirationDays);
    
    const shareLink = {
      id: linkId,
      documentId,
      createdBy: userId,
      accessLevel,
      createdAt: new Date(),
      expires,
      isActive: true
    };
    
    await db.collection('shareLinks').doc(linkId).set(shareLink);
    
    // Update document with share link information
    await docRef.update({
      shareLink: linkId,
      lastModified: new Date()
    });
    
    logger.info(`Share link created for document ${documentId}: ${linkId}`);
    
    res.json({
      shareLink: generateShareLink(documentId, linkId),
      accessLevel,
      expires
    });
    
  } catch (error) {
    logger.error(`Error creating share link: ${error.message}`);
    res.status(500).json({ error: 'Failed to create share link' });
  }
};

/**
 * Add a collaborator to a document
 */
exports.addCollaborator = async (req, res) => {
  try {
    const { documentId } = req.params;
    const { email, accessLevel = 'edit' } = req.body;
    const userId = req.user.uid;
    
    if (!email) {
      return res.status(400).json({ error: 'Collaborator email is required' });
    }
    
    // Validate access level
    if (!['view', 'edit'].includes(accessLevel)) {
      return res.status(400).json({ error: 'Invalid access level' });
    }
    
    // Check document exists and user has permission
    const docRef = db.collection('documents').doc(documentId);
    const doc = await docRef.get();
    
    if (!doc.exists) {
      return res.status(404).json({ error: 'Document not found' });
    }
    
    const docData = doc.data();
    
    // Only owner can add collaborators
    if (docData.creatorId !== userId) {
      return res.status(403).json({ error: 'Only the document owner can add collaborators' });
    }
    
    // Find user by email
    const usersSnapshot = await db.collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();
      
    if (usersSnapshot.empty) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    const collaboratorId = usersSnapshot.docs[0].id;
    
    // Don't add if already a collaborator
    if (docData.collaborators.includes(collaboratorId)) {
      return res.status(400).json({ error: 'User is already a collaborator' });
    }
    
    // Add to collaborators array
    await docRef.update({
      collaborators: [...docData.collaborators, collaboratorId],
      lastModified: new Date()
    });
    
    // Create collaboration permission record
    await db.collection('permissions').add({
      documentId,
      userId: collaboratorId,
      accessLevel,
      grantedBy: userId,
      grantedAt: new Date()
    });
    
    logger.info(`Collaborator ${collaboratorId} added to document ${documentId}`);
    
    res.json({ success: true, message: 'Collaborator added successfully' });
    
  } catch (error) {
    logger.error(`Error adding collaborator: ${error.message}`);
    res.status(500).json({ error: 'Failed to add collaborator' });
  }
};

/**
 * Generate a share link URL from document and link IDs
 */
function generateShareLink(documentId, linkId = null) {
  const baseUrl = process.env.CLIENT_BASE_URL || 'https://app.mindflow.com';
  
  if (linkId) {
    return `${baseUrl}/documents/${documentId}?share=${linkId}`;
  } else {
    return `${baseUrl}/documents/${documentId}`;
  }
} 