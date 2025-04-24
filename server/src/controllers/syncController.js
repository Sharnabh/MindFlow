const { getFirestore } = require('firebase-admin/firestore');
const logger = require('../utils/logger');

const db = getFirestore();

/**
 * Process a batch of changes from a client that was offline
 */
exports.processOfflineChanges = async (req, res) => {
  try {
    const { documentId } = req.params;
    const { changes, baseVersion } = req.body;
    const userId = req.user.uid;
    
    if (!changes || !Array.isArray(changes) || changes.length === 0) {
      return res.status(400).json({ error: 'No changes provided' });
    }
    
    // Verify document exists and user has access
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
    
    // Get current document version
    const currentVersion = docData.version || 1;
    
    // Handle version conflict
    if (baseVersion < currentVersion) {
      logger.warn(`Version conflict for document ${documentId}: Base ${baseVersion}, Current ${currentVersion}`);
      
      // Fetch changes since the client's base version
      const serverChangesSnapshot = await docRef.collection('changes')
        .where('version', '>', baseVersion)
        .where('version', '<=', currentVersion)
        .orderBy('version')
        .get();
        
      const serverChanges = [];
      serverChangesSnapshot.forEach(change => {
        serverChanges.push({
          id: change.id,
          ...change.data()
        });
      });
      
      // Return conflict information to client
      return res.status(409).json({
        error: 'Version conflict',
        currentVersion,
        serverChanges,
        message: 'Please resolve conflicts and retry with the latest version'
      });
    }
    
    // Apply all changes in a transaction
    await db.runTransaction(async (transaction) => {
      // Calculate new version
      const newVersion = currentVersion + changes.length;
      
      // Store each change
      for (let i = 0; i < changes.length; i++) {
        const change = changes[i];
        const version = baseVersion + i + 1;
        
        const changeRef = docRef.collection('changes').doc();
        
        transaction.set(changeRef, {
          ...change,
          id: changeRef.id,
          userId,
          timestamp: new Date(),
          version
        });
      }
      
      // Update document version
      transaction.update(docRef, {
        version: newVersion,
        lastModified: new Date()
      });
    });
    
    logger.info(`Processed ${changes.length} offline changes for document ${documentId} from user ${userId}`);
    
    res.json({
      success: true,
      newVersion: currentVersion + changes.length,
      processedChanges: changes.length
    });
    
  } catch (error) {
    logger.error(`Error processing offline changes: ${error.message}`);
    res.status(500).json({ error: 'Failed to process offline changes' });
  }
};

/**
 * Get changes since a specific version
 */
exports.getChangesSince = async (req, res) => {
  try {
    const { documentId } = req.params;
    const { sinceVersion } = req.query;
    const userId = req.user.uid;
    
    if (!sinceVersion || isNaN(parseInt(sinceVersion))) {
      return res.status(400).json({ error: 'Valid sinceVersion parameter is required' });
    }
    
    const version = parseInt(sinceVersion);
    
    // Verify document exists and user has access
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
    
    // Get current document version
    const currentVersion = docData.version || 1;
    
    // Fetch changes since the requested version
    const changesSnapshot = await docRef.collection('changes')
      .where('version', '>', version)
      .orderBy('version')
      .get();
      
    const changes = [];
    changesSnapshot.forEach(change => {
      changes.push({
        id: change.id,
        ...change.data()
      });
    });
    
    logger.info(`Retrieved ${changes.length} changes since version ${version} for document ${documentId}`);
    
    res.json({
      currentVersion,
      changes
    });
    
  } catch (error) {
    logger.error(`Error getting changes: ${error.message}`);
    res.status(500).json({ error: 'Failed to get changes' });
  }
}; 