// Updated CloudKitManager.swift - Main coordinator
import CloudKit
import Combine
import SwiftUI

/// Main CloudKit manager that coordinates between specialized managers
class CloudKitManager: ObservableObject {
    /// Shared instance (singleton)
    static let shared = CloudKitManager()
    
    // Published properties for SwiftUI binding
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Specialized managers
    let invitationManager: CloudKitInvitationManager
    let permissionManager: CloudKitPermissionManager
    let sharingManager: CloudKitSharingManager
    
    // Private initialization to enforce singleton pattern
    private init() {
        invitationManager = CloudKitInvitationManager()
        permissionManager = CloudKitPermissionManager()
        sharingManager = CloudKitSharingManager()
        
        setupSubscriptions()
    }
    
    /// Sets up CloudKit subscription notifications
    private func setupSubscriptions() {
        // Set up a subscription for invitation changes
        setupSubscription(
            forRecordType: CloudKitConfiguration.invitationRecordType,
            withID: CloudKitConfiguration.subscriptionID(for: CloudKitConfiguration.invitationRecordType)
        )
        
        // Set up a subscription for permission changes
        setupSubscription(
            forRecordType: CloudKitConfiguration.userPermissionRecordType,
            withID: CloudKitConfiguration.subscriptionID(for: CloudKitConfiguration.userPermissionRecordType)
        )
    }
    
    /// Helper to set up a subscription for a specific record type
    private func setupSubscription(forRecordType recordType: String, withID subscriptionID: String) {
        let predicate = NSPredicate(value: true)
        
        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        subscription.notificationInfo = CloudKitConfiguration.defaultNotificationInfo()
        
        CloudKitConfiguration.privateDatabase.save(subscription) { (_, error: Error?) in
            if let error = error {
                print("Failed to create \(recordType) subscription: \(error)")
            } else {
                print("Successfully created \(recordType) subscription")
            }
        }
    }
    
    /// Fetches the current user's identity
    /// - Parameter completion: Closure with user name and optional error
    func fetchUserIdentity(completion: @escaping (String, Error?) -> Void) {
        CloudKitConfiguration.container.fetchUserRecordID { (recordID: CKRecord.ID?, error: Error?) in
            if let error = error {
                completion("Unknown User", error)
                return
            }
            
            guard let _ = recordID else {
                completion("Unknown User", NSError(domain: "CloudKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user record ID"]))
                return
            }
            
            // Get the current user name
            let userName = self.getCurrentUserName()
            completion(userName, nil)
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Helper to get current user name
    func getCurrentUserName() -> String {
        // Try to access through AuthAccess
        let authManager = AuthAccess.getAuthManager()
        
        if let authObj = authManager as? NSObject {
            let selector = NSSelectorFromString("getCurrentUserDisplayName")
            if authObj.responds(to: selector) {
                let result = authObj.perform(selector)
                if let name = result?.takeUnretainedValue() as? String {
                    return name
                }
            }
        }
        
        // Fallback to device name
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac User"
        #else
        return "Unknown User"
        #endif
    }
    
    // MARK: - Forwarding Methods (For Backward Compatibility)
    
    // INVITATION METHODS
    
    /// Convenience for creating an invitation
    func createInvitation(email: String, role: CloudKitTypes.UserPermissionRecord.UserRole = .editor, completion: @escaping (String?, Error?) -> Void) {
        invitationManager.createInvitation(email: email, role: role, completion: completion)
    }
    
    /// Convenience for fetching invitations
    func fetchInvitations() {
        invitationManager.fetchInvitations()
    }
    
    /// Convenience for fetching invitations and binding the result
    var invitations: [CloudKitTypes.InvitationRecord] {
        get { invitationManager.invitations }
    }
    
    /// Convenience for deleting an invitation
    func deleteInvitation(_ invitation: CloudKitTypes.InvitationRecord, completion: @escaping (Error?) -> Void) {
        invitationManager.deleteInvitation(invitation, completion: completion)
    }
    
    /// Convenience for validating an invitation
    func validateInvitation(code: String, completion: @escaping (Bool, String?) -> Void) {
        invitationManager.validateInvitation(code: code, completion: completion)
    }
    
    /// Convenience for accepting an invitation
    func acceptInvitation(code: String, completion: @escaping (Bool, String?) -> Void) {
        invitationManager.acceptInvitation(code: code, completion: completion)
    }
    
    // PERMISSION METHODS
    
    /// Convenience for fetching user permissions
    func fetchUserPermissions() {
        permissionManager.fetchUserPermissions()
    }
    
    /// Convenience for binding user permissions
    var permissions: [CloudKitTypes.UserPermissionRecord] {
        get { permissionManager.permissions }
    }
    
    /// Convenience for revoking access
    func revokeAccess(_ permission: CloudKitTypes.UserPermissionRecord, completion: @escaping (Error?) -> Void) {
        permissionManager.revokeAccess(permission, completion: completion)
    }
    
    /// Convenience for updating a permission role
    func updatePermissionRole(_ permission: CloudKitTypes.UserPermissionRecord, newRole: CloudKitTypes.UserPermissionRecord.UserRole, completion: @escaping (Error?) -> Void) {
        permissionManager.updatePermissionRole(permission, newRole: newRole, completion: completion)
    }
    
    /// Convenience for checking if user is admin
    func isUserAdmin(completion: @escaping (Bool) -> Void) {
        permissionManager.isUserAdmin(completion: completion)
    }
    
    /// Convenience for checking user access level
    func checkUserAccessLevel(completion: @escaping (CloudKitTypes.UserPermissionRecord.UserRole?) -> Void) {
        permissionManager.checkUserAccessLevel(completion: completion)
    }
    
    /// Convenience for making current user admin
    func makeCurrentUserAdmin(completion: @escaping (Bool, String?) -> Void) {
        permissionManager.makeCurrentUserAdmin(completion: completion)
    }
    
    /// Convenience for checking if admin exists
    func checkIfAdminExists(completion: @escaping (Bool) -> Void) {
        permissionManager.checkIfAdminExists(completion: completion)
    }
    
    // SHARING METHODS
    
    /// Convenience for setting up CloudKit sharing
    func setupCloudKitSharing(completion: @escaping (CKShare?, Error?) -> Void) {
        sharingManager.setupCloudKitSharing(completion: completion)
    }
}
