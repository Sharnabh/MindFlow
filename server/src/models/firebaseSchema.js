/**
 * Firebase Firestore Database Schema
 * This file documents the data model for MindFlow collaboration.
 * 
 * Note: This is a documentation file, not actual code.
 * The schema is implemented through the application code.
 */

/**
 * Collection: documents
 * Stores collaborative document metadata
 * 
 * Document structure:
 * {
 *   id: string,              // Document ID
 *   title: string,           // Document title
 *   creatorId: string,       // User ID of creator
 *   collaborators: string[], // Array of user IDs with access
 *   activeUsers: string[],   // Currently active users (updated by WebSocket)
 *   version: number,         // Current document version number
 *   createdAt: timestamp,    // Creation timestamp
 *   lastModified: timestamp, // Last modification timestamp
 *   shareLink: string,       // ID of active share link (if any)
 *   isPublic: boolean,       // Whether document is publicly accessible
 * }
 * 
 * Subcollection: documents/{documentId}/topics
 * Stores the topic data for the document
 * 
 * Document structure:
 * {
 *   id: string,              // Topic ID
 *   name: string,            // Topic name
 *   position: {x: number, y: number}, // Position in canvas
 *   parentId: string,        // Parent topic ID (if any)
 *   subtopics: [],           // Array of subtopic IDs
 *   backgroundColor: string, // Color in hex
 *   borderColor: string,     // Border color in hex
 *   foregroundColor: string, // Text color in hex
 *   note: {                  // Optional note
 *     content: string        // Note content
 *   },
 *   createdAt: timestamp,    // Creation timestamp
 *   createdBy: string,       // User ID of creator
 *   relations: string[],     // Related topic IDs
 *   metadata: {              // Additional metadata
 *     icon: string,          // Optional icon
 *     ... 
 *   }
 * }
 * 
 * Subcollection: documents/{documentId}/changes
 * Stores the change history for the document
 * 
 * Document structure:
 * {
 *   id: string,              // Change ID
 *   topicId: string,         // Topic ID this change affects
 *   userId: string,          // User ID who made the change
 *   timestamp: timestamp,    // When the change was made
 *   changeType: string,      // Type: create/update/delete/move/connect/disconnect
 *   properties: {            // Changed properties (differs by change type)
 *     name: string,          // For name changes
 *     position: {x, y},      // For position changes
 *     ... 
 *   },
 *   version: number          // Document version for this change
 * }
 */

/**
 * Collection: shareLinks
 * Stores document sharing links
 * 
 * Document structure:
 * {
 *   id: string,              // Share link ID
 *   documentId: string,      // Document ID this link refers to
 *   createdBy: string,       // User ID who created the link
 *   accessLevel: string,     // Access level: view/edit
 *   createdAt: timestamp,    // Creation timestamp
 *   expires: timestamp,      // Expiration timestamp
 *   isActive: boolean,       // Whether link is still active
 *   usedBy: string[],        // Users who have used this link
 * }
 */

/**
 * Collection: permissions
 * Stores user permissions for documents
 * 
 * Document structure:
 * {
 *   documentId: string,      // Document ID
 *   userId: string,          // User ID
 *   accessLevel: string,     // Access level: view/comment/edit/owner
 *   grantedBy: string,       // User ID who granted permission
 *   grantedAt: timestamp,    // When permission was granted
 * }
 */ 