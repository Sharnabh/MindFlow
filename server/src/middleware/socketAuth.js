/**
 * Socket.io authentication middleware
 * Verifies Firebase JWT tokens for WebSocket connections
 */
const logger = require('../utils/logger');

/**
 * Socket.io middleware for Firebase authentication
 * @param {object} auth - Firebase Auth instance
 * @returns {function} Socket.io middleware function
 */
module.exports = function(auth) {
  return async (socket, next) => {
    try {
      const token = socket.handshake.auth.token || 
                   socket.handshake.headers.authorization?.split('Bearer ')[1];
      
      if (!token) {
        return next(new Error('Authentication required'));
      }
      
      // Verify the token with Firebase Auth
      const decodedToken = await auth.verifyIdToken(token);
      
      if (!decodedToken) {
        return next(new Error('Invalid authentication token'));
      }
      
      // Get additional user info
      const userRecord = await auth.getUser(decodedToken.uid);
      
      // Attach the user to the socket
      socket.user = userRecord;
      
      logger.debug(`User authenticated: ${userRecord.uid}`);
      
      // Continue with the connection
      next();
      
    } catch (error) {
      logger.error(`Socket authentication error: ${error.message}`);
      next(new Error('Authentication failed'));
    }
  };
}; 