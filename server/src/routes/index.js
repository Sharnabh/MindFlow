const express = require('express');
const router = express.Router();
const documentRoutes = require('./documentRoutes');
const syncRoutes = require('./syncRoutes');
const authMiddleware = require('../middleware/authMiddleware');

// Health check route
router.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date() });
});

// Apply authentication middleware to all secure routes
router.use(authMiddleware);

// API routes
router.use('/documents', documentRoutes);
router.use('/sync', syncRoutes);

module.exports = router; 