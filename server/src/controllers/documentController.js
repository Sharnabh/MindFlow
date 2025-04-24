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
    console.log('Create Document Request Body:', req.body);
    // More flexible handling of incoming data
    const title = req.body.title || 'Untitled Document';
    const initialTopics = req.body.initialTopics || [];
    const userId = req.user.uid;
    
    // In development mode, always log to help debug
    if (process.env.NODE_ENV === 'development') {
      logger.debug(`Creating document with title: ${title} for user: ${userId}`, {
        service: "mindflow-collaboration-server"
      });
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
      shareLink: generateShareLink(docRef.id),
      success: true
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
    // Debug the body to see what we're getting
    console.log("Share link request body:", req.body);
    
    // Extract values with defaults
    const accessLevel = req.body.accessLevel || 'view';
    const expirationDays = req.body.expirationDays || 7;
    const userId = req.user.uid;
    
    // In development mode, ensure we're handling things properly
    if (process.env.NODE_ENV === 'development') {
      logger.debug(`Creating share link for document ${documentId} with access level ${accessLevel}`, {
        service: "mindflow-collaboration-server" 
      });
    }
    
    // Validate access level with more flexibility
    const validAccessLevels = ['view', 'edit', 'viewOnly', 'comment', 'owner'];
    const normalizedAccessLevel = accessLevel.toLowerCase().replace('only', '');
    
    if (!validAccessLevels.includes(normalizedAccessLevel) && !validAccessLevels.includes(accessLevel)) {
      return res.status(400).json({ 
        error: 'Invalid access level',
        message: `Access level must be one of: ${validAccessLevels.join(', ')}. Received: ${accessLevel}`
      });
    }
    
    // Check document exists and user has permission
    const docRef = db.collection('documents').doc(documentId);
    const doc = await docRef.get();
    
    // Create a document if it doesn't exist in development mode
    if (!doc.exists && process.env.NODE_ENV === 'development') {
      logger.debug(`Document ${documentId} not found, creating it for development`, {
        service: "mindflow-collaboration-server"
      });
      
      // Create document with initial data
      await docRef.set({
        id: documentId,
        title: "Development Test Document",
        creatorId: userId,
        collaborators: [userId],
        activeUsers: [],
        version: 1,
        createdAt: new Date(),
        lastModified: new Date()
      });
      
      // Fetch the newly created document
      const newDoc = await docRef.get();
      if (!newDoc.exists) {
        return res.status(500).json({ error: 'Failed to create test document' });
      }
    } else if (!doc.exists) {
      return res.status(404).json({ error: 'Document not found' });
    }
    
    const docData = doc.data();
    
    // Only owner can create share links, but bypass in development mode
    if (docData.creatorId !== userId && process.env.NODE_ENV !== 'development') {
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
      accessLevel: normalizedAccessLevel || accessLevel,
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
    
    const generatedLink = generateShareLink(documentId, linkId);
    res.json({
      shareLink: generatedLink,
      accessLevel,
      expires,
      success: true
    });
    
  } catch (error) {
    logger.error(`Error creating share link: ${error.message}`, { 
      stack: error.stack,
      service: "mindflow-collaboration-server"
    });
    res.status(500).json({ error: 'Failed to create share link', message: error.message });
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
 * Get collaborators for a document
 */
exports.getCollaborators = async (req, res) => {
  try {
    const { documentId } = req.params;
    const userId = req.user.uid;
    
    // Verify the document exists and check access
    const docRef = db.collection('documents').doc(documentId);
    const doc = await docRef.get();
    
    if (!doc.exists) {
      return res.status(404).json({ error: 'Document not found' });
    }
    
    const docData = doc.data();
    
    // Check if user has access to the document
    if (!docData.collaborators.includes(userId) && docData.creatorId !== userId) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    // Get all collaborators data
    const collaborators = [];
    
    // Using in query for the list of collaborator IDs
    if (docData.collaborators.length > 0) {
      // Development mode - generate mock data
      if (process.env.NODE_ENV === 'development') {
        // Add the document creator
        collaborators.push({
          id: docData.creatorId,
          email: "creator@example.com",
          displayName: "Document Creator",
          photoURL: null,
          accessLevel: "owner",
          joinedAt: docData.createdAt,
          lastActive: new Date(),
          invitedBy: null,
          status: "active"
        });
        
        // Add some mock collaborators
        if (docData.collaborators.length > 1) {
          docData.collaborators.forEach(collabId => {
            if (collabId !== docData.creatorId) {
              collaborators.push({
                id: collabId,
                email: `user-${collabId.substring(0, 5)}@example.com`,
                displayName: `User ${collabId.substring(0, 5)}`,
                photoURL: null,
                accessLevel: "edit",
                joinedAt: new Date(docData.createdAt.getTime() + 86400000), // 1 day after created
                lastActive: new Date(),
                invitedBy: docData.creatorId,
                status: "active"
              });
            }
          });
        }
      } else {
        // Production mode - fetch real collaborator data
        // Get permissions data
        const permissionsSnapshot = await db.collection('permissions')
          .where('documentId', '==', documentId)
          .get();
          
        const permissionsMap = {};
        permissionsSnapshot.forEach(perm => {
          const permData = perm.data();
          permissionsMap[permData.userId] = permData;
        });
        
        // Fetch user data for each collaborator
        for (const collabId of docData.collaborators) {
          try {
            const userRecord = await admin.auth().getUser(collabId);
            const permData = permissionsMap[collabId] || {};
            
            const isOwner = collabId === docData.creatorId;
            
            collaborators.push({
              id: collabId,
              email: userRecord.email || '',
              displayName: userRecord.displayName || 'Anonymous User',
              photoURL: userRecord.photoURL,
              accessLevel: isOwner ? 'owner' : (permData.accessLevel || 'edit'),
              joinedAt: permData.grantedAt || docData.createdAt,
              lastActive: permData.lastActive || null,
              invitedBy: isOwner ? null : permData.grantedBy,
              status: 'active'
            });
          } catch (userError) {
            logger.warn(`Failed to fetch user ${collabId}: ${userError.message}`);
            // Add minimal data for users we can't fetch
            collaborators.push({
              id: collabId,
              email: 'unknown@example.com',
              displayName: 'Unknown User',
              photoURL: null,
              accessLevel: collabId === docData.creatorId ? 'owner' : 'edit',
              joinedAt: docData.createdAt,
              lastActive: null,
              invitedBy: null,
              status: 'active'
            });
          }
        }
      }
    }
    
    res.json(collaborators);
    
  } catch (error) {
    logger.error(`Error getting collaborators: ${error.message}`);
    res.status(500).json({ error: 'Failed to get collaborators' });
  }
};

/**
 * Update collaborator access level
 */
exports.updateCollaboratorAccess = async (req, res) => {
  try {
    const { documentId, userId: targetUserId } = req.params;
    const { accessLevel } = req.body;
    const requestingUserId = req.user.uid;
    
    // Validate access level
    if (!['view', 'edit'].includes(accessLevel)) {
      return res.status(400).json({ error: 'Invalid access level' });
    }
    
    // Verify the document exists
    const docRef = db.collection('documents').doc(documentId);
    const doc = await docRef.get();
    
    if (!doc.exists) {
      return res.status(404).json({ error: 'Document not found' });
    }
    
    const docData = doc.data();
    
    // Only allow the document owner to update access
    if (docData.creatorId !== requestingUserId) {
      return res.status(403).json({ error: 'Only the document owner can update collaborator access' });
    }
    
    // Cannot change owner's access level
    if (targetUserId === docData.creatorId) {
      return res.status(400).json({ error: 'Owner access level cannot be changed' });
    }
    
    // Verify the user is a collaborator
    if (!docData.collaborators.includes(targetUserId)) {
      return res.status(404).json({ error: 'User is not a collaborator on this document' });
    }
    
    // Update or create permission record
    const permissionsSnapshot = await db.collection('permissions')
      .where('documentId', '==', documentId)
      .where('userId', '==', targetUserId)
      .limit(1)
      .get();
      
    if (permissionsSnapshot.empty) {
      // Create new permission
      await db.collection('permissions').add({
        documentId,
        userId: targetUserId,
        accessLevel,
        grantedBy: requestingUserId,
        grantedAt: new Date(),
        lastUpdated: new Date()
      });
    } else {
      // Update existing permission
      const permDoc = permissionsSnapshot.docs[0];
      await permDoc.ref.update({
        accessLevel,
        lastUpdated: new Date()
      });
    }
    
    logger.info(`Updated collaborator ${targetUserId} access to ${accessLevel} for document ${documentId}`);
    
    res.json({ success: true });
    
  } catch (error) {
    logger.error(`Error updating collaborator access: ${error.message}`);
    res.status(500).json({ error: 'Failed to update collaborator access' });
  }
};

/**
 * Remove a collaborator from a document
 */
exports.removeCollaborator = async (req, res) => {
  try {
    const { documentId, userId: targetUserId } = req.params;
    const requestingUserId = req.user.uid;
    
    // Verify the document exists
    const docRef = db.collection('documents').doc(documentId);
    const doc = await docRef.get();
    
    if (!doc.exists) {
      return res.status(404).json({ error: 'Document not found' });
    }
    
    const docData = doc.data();
    
    // Only allow the document owner to remove collaborators
    if (docData.creatorId !== requestingUserId) {
      return res.status(403).json({ error: 'Only the document owner can remove collaborators' });
    }
    
    // Cannot remove the document owner
    if (targetUserId === docData.creatorId) {
      return res.status(400).json({ error: 'Cannot remove document owner' });
    }
    
    // Verify the user is a collaborator
    if (!docData.collaborators.includes(targetUserId)) {
      return res.status(404).json({ error: 'User is not a collaborator on this document' });
    }
    
    // Remove from collaborators array
    const updatedCollaborators = docData.collaborators.filter(id => id !== targetUserId);
    
    await docRef.update({
      collaborators: updatedCollaborators,
      lastModified: new Date()
    });
    
    // Update permissions (mark as removed instead of deleting)
    const permissionsSnapshot = await db.collection('permissions')
      .where('documentId', '==', documentId)
      .where('userId', '==', targetUserId)
      .limit(1)
      .get();
      
    if (!permissionsSnapshot.empty) {
      const permDoc = permissionsSnapshot.docs[0];
      await permDoc.ref.update({
        status: 'removed',
        removedAt: new Date(),
        removedBy: requestingUserId
      });
    }
    
    logger.info(`Removed collaborator ${targetUserId} from document ${documentId}`);
    
    res.json({ success: true });
    
  } catch (error) {
    logger.error(`Error removing collaborator: ${error.message}`);
    res.status(500).json({ error: 'Failed to remove collaborator' });
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