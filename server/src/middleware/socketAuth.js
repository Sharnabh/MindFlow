/**
 * Socket.io middleware for Firebase authentication
 * Verifies Firebase JWT tokens for WebSocket connections
 */
const { getAuth } = require('firebase-admin/auth');
const logger = require('../utils/logger');

// Check if we're in development mode
const isDevelopment = process.env.NODE_ENV === 'development';

module.exports = (auth) => {
  return async (socket, next) => {
    // In development mode, we'll use a simplified authentication
    if (isDevelopment) {
      // Get userId from the handshake query, which we added in the client
      const userId = socket.handshake.query.userId;
      const documentId = socket.handshake.query.documentId;
      
      if (!userId) {
        logger.debug('Development mode - missing userId parameter', {
          service: "mindflow-collaboration-server"
        });
        return next(new Error('Authentication failed: Missing userId parameter'));
      }
      
      if (!documentId) {
        logger.debug('Development mode - missing documentId parameter', {
          service: "mindflow-collaboration-server"
        });
        return next(new Error('Authentication failed: Missing documentId parameter'));
      }
      
      logger.debug('Development mode - bypassing authentication', {
        service: "mindflow-collaboration-server"
      });
      
      // Set mock user info
      socket.user = {
        uid: userId,
        displayName: 'Test User',
        email: 'test@example.com',
        photoURL: null
      };
      
      // Store the document ID for easy access
      socket.documentId = documentId;
      
      return next();
    }
    
    try {
      // Get the token from the auth header in the socket handshake
      const authHeader = socket.handshake.auth?.token || 
                           socket.handshake.headers?.authorization;
      
      if (!authHeader || (typeof authHeader === 'string' && !authHeader.startsWith('Bearer '))) {
        return next(new Error('Authentication failed: Invalid token format'));
      }
      
      // Extract the token
      const token = typeof authHeader === 'string' 
        ? authHeader.split('Bearer ')[1] 
        : authHeader;
      
      if (!token) {
        return next(new Error('Authentication failed: Token missing'));
      }
      
      try {
        // Verify the token
        const decodedToken = await auth.verifyIdToken(token);
        
        // Get the user record
        const userRecord = await auth.getUser(decodedToken.uid);
        
        // Attach the user to the socket
        socket.user = userRecord;
        
        logger.debug(`User authenticated: ${userRecord.uid}`, {
          service: "mindflow-collaboration-server"
        });
        
        next();
      } catch (tokenError) {
        logger.error(`Authentication error: ${tokenError.message}`, {
          service: "mindflow-collaboration-server"
        });
        next(new Error('Authentication failed: Invalid token'));
      }
    } catch (error) {
      logger.error(`Socket auth error: ${error.message}`, {
        service: "mindflow-collaboration-server"
      });
      next(new Error('Authentication failed'));
    }
  };
}; 