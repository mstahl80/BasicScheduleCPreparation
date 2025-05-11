// CloudKitTypes.swift
import CloudKit

/// Contains all shared data types and models used by the CloudKit managers
enum CloudKitTypes {
    /// Represents an invitation record to share data with another user
    struct InvitationRecord: Identifiable {
        let id: CKRecord.ID
        let code: String
        let email: String
        let created: Date
        let creator: String
        let status: InvitationStatus
        let acceptedBy: String?
        let acceptedDate: Date?
        let role: UserPermissionRecord.UserRole
        
        /// Status of an invitation
        enum InvitationStatus: String {
            case pending = "pending"
            case accepted = "accepted"
            case revoked = "revoked"
        }
        
        /// Create an invitation record from a CloudKit record
        static func from(record: CKRecord) -> InvitationRecord? {
            guard
                let code = record["code"] as? String,
                let email = record["email"] as? String,
                let created = record["created"] as? Date,
                let creator = record["creator"] as? String,
                let statusString = record["status"] as? String,
                let status = InvitationStatus(rawValue: statusString)
            else {
                return nil
            }
            
            let acceptedBy = record["acceptedBy"] as? String
            let acceptedDate = record["acceptedDate"] as? Date
            let roleString = record["role"] as? String ?? UserPermissionRecord.UserRole.editor.rawValue
            let role = UserPermissionRecord.UserRole(rawValue: roleString) ?? .editor
            
            return InvitationRecord(
                id: record.recordID,
                code: code,
                email: email,
                created: created,
                creator: creator,
                status: status,
                acceptedBy: acceptedBy,
                acceptedDate: acceptedDate,
                role: role
            )
        }
    }
    
    /// Represents a user's permission level for shared data
    struct UserPermissionRecord: Identifiable {
        let id: CKRecord.ID
        let userId: String
        let userName: String
        let email: String?
        let role: UserRole
        let invitationCode: String?
        let addedDate: Date
        
        /// User permission roles
        enum UserRole: String {
            case admin = "admin"
            case editor = "editor"
            case viewer = "viewer"
            
            /// Display name for the role
            var displayName: String {
                switch self {
                case .admin: return "Administrator"
                case .editor: return "Editor"
                case .viewer: return "Viewer"
                }
            }
            
            /// Description of the role's permissions
            var description: String {
                switch self {
                case .admin: return "Can manage users and all data"
                case .editor: return "Can view and edit all data"
                case .viewer: return "Can view data but not make changes"
                }
            }
        }
        
        /// Create a user permission record from a CloudKit record
        static func from(record: CKRecord) -> UserPermissionRecord? {
            guard
                let userId = record["userId"] as? String,
                let userName = record["userName"] as? String,
                let roleString = record["role"] as? String,
                let role = UserRole(rawValue: roleString),
                let addedDate = record["addedDate"] as? Date
            else {
                return nil
            }
            
            let email = record["email"] as? String
            let invitationCode = record["invitationCode"] as? String
            
            return UserPermissionRecord(
                id: record.recordID,
                userId: userId,
                userName: userName,
                email: email,
                role: role,
                invitationCode: invitationCode,
                addedDate: addedDate
            )
        }
    }
    
    /// Error types specific to CloudKit operations
    enum CloudKitError: Error {
        case recordNotFound
        case userIdentityNotFound
        case notAuthenticated
        case permissionDenied
        case invalidInvitationCode
        case alreadyAccepted
        case networkError
        case unknown(Error)
        
        var localizedDescription: String {
            switch self {
            case .recordNotFound:
                return "Record not found"
            case .userIdentityNotFound:
                return "User identity could not be determined"
            case .notAuthenticated:
                return "You must sign in with your Apple ID first"
            case .permissionDenied:
                return "You don't have permission to perform this action"
            case .invalidInvitationCode:
                return "Invalid invitation code"
            case .alreadyAccepted:
                return "This invitation has already been used"
            case .networkError:
                return "Network error. Please check your connection and try again"
            case .unknown(let error):
                return "An error occurred: \(error.localizedDescription)"
            }
        }
    }
}
