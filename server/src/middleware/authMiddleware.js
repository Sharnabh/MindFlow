/**
 * Express middleware for Firebase authentication
 * Verifies Firebase JWT tokens for HTTP requests
 */
const { getAuth } = require('firebase-admin/auth');
const logger = require('../utils/logger');

// Check if we're in development mode
const isDevelopment = process.env.NODE_ENV === 'development';

module.exports = async (req, res, next) => {
  // For development mode, use a test user
  if (isDevelopment) {
    logger.debug('Development mode - bypassing authentication');
    // Create a test user object
    req.user = {
      uid: 'test-user-id',
      email: 'test@example.com',
      displayName: 'Test User',
      photoURL: null
    };
    return next();
  }

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
    
    try {
      const decodedToken = await auth.verifyIdToken(token);
      
      if (!decodedToken) {
        return res.status(401).json({ error: 'Invalid authentication token' });
      }
      
      // Get user record
      const userRecord = await auth.getUser(decodedToken.uid);
      
      // Attach user to request object
      req.user = userRecord;
      
      next();
    } catch (tokenError) {
      logger.error(`Authentication error: ${tokenError.message}`, {
        service: "mindflow-collaboration-server"
      });
      return res.status(401).json({ error: 'Authentication failed' });
    }
    
  } catch (error) {
    logger.error(`Server error in auth middleware: ${error.message}`, {
      service: "mindflow-collaboration-server"
    });
    return res.status(500).json({ error: 'Server error' });
  }
}; 