require('dotenv').config();
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');
const logger = require('./utils/logger');
const socketAuth = require('./middleware/socketAuth');

// Initialize Firebase Admin first before importing routes which use Firestore
try {
  // Use a direct path to the firebase config file
  const serviceAccountPath = path.join(__dirname, '..', 'firebase-config', 'mindflow-a1d72-firebase-adminsdk-fbsvc-f3f9ed7ff0.json');
  
  // Check if file exists
  if (!fs.existsSync(serviceAccountPath)) {
    throw new Error(`Firebase service account file not found at: ${serviceAccountPath}`);
  }
  
  logger.info(`Loading Firebase service account from: ${serviceAccountPath}`);
  const serviceAccount = require(serviceAccountPath);
  
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
  
  logger.info('Firebase Admin initialized successfully');
} catch (error) {
  logger.error('Failed to initialize Firebase Admin:', error);
  process.exit(1);
}

// Now that Firebase is initialized, import routes
const routes = require('./routes');

// Initialize Express app
const app = express();
const server = http.createServer(app);

// Configure middleware
app.use(helmet());
app.use(cors({
  origin: process.env.CORS_ORIGIN?.split(',') || '*',
  methods: ['GET', 'POST'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());

// Initialize Firestore
const db = admin.firestore();
const auth = admin.auth();

// Setup Socket.io
const io = socketIo(server, {
  cors: {
    origin: process.env.CORS_ORIGIN?.split(',') || '*',
    methods: ['GET', 'POST']
  },
  pingInterval: parseInt(process.env.WEBSOCKET_PING_INTERVAL) || 30000,
  pingTimeout: parseInt(process.env.WEBSOCKET_PING_TIMEOUT) || 10000
});

// Socket authentication middleware
io.use(socketAuth(auth));

// Active document sessions
const activeSessions = new Map();

// Socket connection handling
io.on('connection', socket => {
  logger.info(`Socket connected: ${socket.id}`);
  
  // Store user data from auth middleware
  const userId = socket.user.uid;
  const userDisplayName = socket.user.displayName || 'Anonymous';
  const userPhotoURL = socket.user.photoURL || null;
  
  // In development mode, the documentId is already in the socket from the middleware
  if (process.env.NODE_ENV === 'development' && socket.documentId) {
    // Automatically join the document specified in the connection
    handleJoinDocument(socket, socket.documentId);
  }
  
  // Join a document collaboration session
  socket.on('joinDocument', async (documentId) => {
    handleJoinDocument(socket, documentId);
  });
  
  // Handle joining a document
  async function handleJoinDocument(socket, documentId) {
    try {
      // Verify document exists and user has access
      const docRef = db.collection('documents').doc(documentId);
      const doc = await docRef.get();
      
      if (!doc.exists) {
        socket.emit('error', { message: 'Document not found' });
        return;
      }
      
      const docData = doc.data();
      
      // Check access permissions - in development mode, bypass for testing
      if (process.env.NODE_ENV !== 'development' && 
          !docData.collaborators.includes(userId) && 
          docData.creatorId !== userId) {
        socket.emit('error', { message: 'Access denied' });
        return;
      }
      
      // Leave any previous document room
      if (socket.currentDocument) {
        socket.leave(socket.currentDocument);
        
        // Remove from active users in the previous document
        removeActiveUser(socket.currentDocument, userId);
      }
      
      // Join new document room
      socket.join(documentId);
      socket.currentDocument = documentId;
      
      // Add to active users for this document
      addActiveUser(documentId, {
        id: userId,
        displayName: userDisplayName,
        photoURL: userPhotoURL,
        color: generateUserColor(userId),
        lastActive: new Date()
      });
      
      // Notify other users that this user joined
      socket.to(documentId).emit('userJoined', {
        type: 'userJoined',
        senderId: 'system',
        timestamp: new Date(),
        payload: getActiveUser(documentId, userId)
      });
      
      // Send connection established confirmation
      socket.emit('connectionEstablished', {
        type: 'connectionEstablished',
        senderId: 'system',
        timestamp: new Date(),
        payload: {
          documentId,
          collaborators: getActiveUsers(documentId)
        }
      });
      
      logger.info(`User ${userId} joined document ${documentId}`);
      
    } catch (error) {
      logger.error(`Error joining document: ${error.message}`);
      socket.emit('error', { message: 'Failed to join document session' });
    }
  }
  
  // Handle topic changes
  socket.on('topicChange', async (changeData) => {
    try {
      if (!socket.currentDocument) {
        socket.emit('error', { message: 'Not connected to a document' });
        return;
      }
      
      const documentId = socket.currentDocument;
      
      // Validate the change object
      if (!changeData || !changeData.topicId || !changeData.changeType) {
        socket.emit('error', { message: 'Invalid change data' });
        return;
      }
      
      // Store the change in Firestore
      const changeRef = db.collection('documents').doc(documentId)
        .collection('changes').doc();
        
      await changeRef.set({
        ...changeData,
        id: changeRef.id,
        userId,
        timestamp: new Date()
      });
      
      // Update document version
      await db.collection('documents').doc(documentId).update({
        version: changeData.version,
        lastModified: new Date()
      });
      
      // Update user's last active timestamp
      updateUserActivity(documentId, userId);
      
      // Broadcast the change to other clients
      socket.to(documentId).emit('topicChange', {
        type: 'topicChange',
        senderId: userId,
        timestamp: new Date(),
        payload: changeData
      });
      
      logger.debug(`Topic change from user ${userId} in document ${documentId}`);
      
    } catch (error) {
      logger.error(`Error handling topic change: ${error.message}`);
      socket.emit('error', { message: 'Failed to process topic change' });
    }
  });
  
  // Handle disconnection
  socket.on('disconnect', () => {
    if (socket.currentDocument) {
      // Remove from active users
      removeActiveUser(socket.currentDocument, userId);
      
      // Notify other users
      socket.to(socket.currentDocument).emit('userLeft', {
        type: 'userLeft',
        senderId: 'system',
        timestamp: new Date(),
        payload: userId
      });
      
      logger.info(`User ${userId} disconnected from document ${socket.currentDocument}`);
    }
    
    logger.info(`Socket disconnected: ${socket.id}`);
  });
});

// Setup API routes
app.use('/api', routes);

// Active user management functions
function addActiveUser(documentId, user) {
  if (!activeSessions.has(documentId)) {
    activeSessions.set(documentId, new Map());
  }
  activeSessions.get(documentId).set(user.id, user);
}

function removeActiveUser(documentId, userId) {
  if (activeSessions.has(documentId)) {
    activeSessions.get(documentId).delete(userId);
    
    // If no active users, clean up the session
    if (activeSessions.get(documentId).size === 0) {
      activeSessions.delete(documentId);
    }
  }
}

function getActiveUser(documentId, userId) {
  if (activeSessions.has(documentId)) {
    return activeSessions.get(documentId).get(userId);
  }
  return null;
}

function getActiveUsers(documentId) {
  if (activeSessions.has(documentId)) {
    return Array.from(activeSessions.get(documentId).values());
  }
  return [];
}

function updateUserActivity(documentId, userId) {
  const user = getActiveUser(documentId, userId);
  if (user) {
    user.lastActive = new Date();
    activeSessions.get(documentId).set(userId, user);
  }
}

// Generate consistent color for a user based on their ID
function generateUserColor(userId) {
  // Simple hash function to convert user ID to a color
  const hash = Array.from(userId).reduce((acc, char) => {
    return (acc << 5) - acc + char.charCodeAt(0) | 0;
  }, 0);
  
  // Generate HSL color with good saturation and lightness
  const hue = Math.abs(hash) % 360;
  return `hsl(${hue}, 70%, 60%)`;
}

// Start server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  logger.info(`Server running on port ${PORT}`);
});

// Handle graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  server.close(() => {
    logger.info('Server closed');
    process.exit(0);
  });
}); 