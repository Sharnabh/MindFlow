import Foundation
import FirebaseAuth

struct UserProfile: Identifiable, Codable, Equatable {
    let id: String  // Firebase Auth UID
    var displayName: String
    var email: String
    var photoURL: URL?
    var phoneNumber: String?
    let createdAt: Date
    var lastActive: Date
    
    // Additional user metadata
    var preferredTheme: String?
    var settings: [String: String]?
    
    init(from firebaseUser: User) {
        self.id = firebaseUser.uid
        self.displayName = firebaseUser.displayName ?? ""
        self.email = firebaseUser.email ?? ""
        self.photoURL = firebaseUser.photoURL
        self.phoneNumber = firebaseUser.phoneNumber
        
        // If the user was just created, use current date, otherwise use metadata
        if let creationDate = firebaseUser.metadata.creationDate {
            self.createdAt = creationDate
        } else {
            self.createdAt = Date()
        }
        
        if let lastSignInDate = firebaseUser.metadata.lastSignInDate {
            self.lastActive = lastSignInDate
        } else {
            self.lastActive = Date()
        }
        
        self.preferredTheme = nil
        self.settings = nil
    }
    
    init(id: String, displayName: String, email: String, photoURL: URL? = nil, 
         phoneNumber: String? = nil, createdAt: Date = Date(), lastActive: Date = Date(),
         preferredTheme: String? = nil, settings: [String: String]? = nil) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.photoURL = photoURL
        self.phoneNumber = phoneNumber
        self.createdAt = createdAt
        self.lastActive = lastActive
        self.preferredTheme = preferredTheme
        self.settings = settings
    }
    
    static func == (lhs: UserProfile, rhs: UserProfile) -> Bool {
        return lhs.id == rhs.id &&
               lhs.displayName == rhs.displayName &&
               lhs.email == rhs.email &&
               lhs.photoURL == rhs.photoURL &&
               lhs.phoneNumber == rhs.phoneNumber &&
               lhs.createdAt == rhs.createdAt &&
               lhs.lastActive == rhs.lastActive &&
               lhs.preferredTheme == rhs.preferredTheme
    }
    
    // Update the profile with new Firebase user data
    mutating func update(from firebaseUser: User) {
        self.displayName = firebaseUser.displayName ?? self.displayName
        self.email = firebaseUser.email ?? self.email
        self.photoURL = firebaseUser.photoURL ?? self.photoURL
        self.phoneNumber = firebaseUser.phoneNumber ?? self.phoneNumber
        
        if let lastSignInDate = firebaseUser.metadata.lastSignInDate {
            self.lastActive = lastSignInDate
        } else {
            self.lastActive = Date()
        }
    }
}