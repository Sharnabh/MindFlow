/**
 * Express middleware for Firebase authentication
 * Verifies Firebase JWT tokens for HTTP requests
 */
const { getAuth } = require('firebase-admin/auth');
const logger = require('../utils/logger');

module.exports = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    
    const token = authHeader.split('Bearer ')[1];
    
    if (!token) {
      return res.status(401).json({ error: 'Invalid authentication token format' });
    }
    
    // Verify the token
    const auth = getAuth();
    const decodedToken = await auth.verifyIdToken(token);
    
    if (!decodedToken) {
      return res.status(401).json({ error: 'Invalid authentication token' });
    }
    
    // Get user record
    const userRecord = await auth.getUser(decodedToken.uid);
    
    // Attach user to request object
    req.user = userRecord;
    
    next();
    
  } catch (error) {
    logger.error(`Authentication error: ${error.message}`);
    
    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({ error: 'Token expired' });
    }
    
    if (error.code === 'auth/id-token-revoked') {
      return res.status(401).json({ error: 'Token revoked' });
    }
    
    if (error.code === 'auth/invalid-id-token') {
      return res.status(401).json({ error: 'Invalid token' });
    }
    
    if (error.code === 'auth/user-not-found') {
      return res.status(401).json({ error: 'User not found' });
    }
    
    res.status(401).json({ error: 'Authentication failed' });
  }
}; 