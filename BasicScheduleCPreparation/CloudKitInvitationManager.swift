// CloudKitInvitationManager.swift
import CloudKit
import Combine
import SwiftUI

/// Manages all invitation-related operations in CloudKit
class CloudKitInvitationManager: ObservableObject {
    /// Published array of invitation records for SwiftUI binding
    @Published var invitations: [CloudKitTypes.InvitationRecord] = []
    
    /// Loading state indicator
    @Published var isLoading = false
    
    /// Error message if an operation fails
    @Published var errorMessage: String?
    
    /// Creates a new invitation with a unique code
    /// - Parameters:
    ///   - email: The email address of the person being invited
    ///   - role: The role to assign to the invited user
    ///   - completion: Closure called when operation completes
    func createInvitation(email: String, role: CloudKitTypes.UserPermissionRecord.UserRole = .editor, completion: @escaping (String?, Error?) -> Void) {
        isLoading = true
        
        // Generate a random 6-character code
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let code = String((0..<6).map { _ in letters.randomElement()! })
        
        // Create a new invitation record
        let record = CKRecord(recordType: CloudKitConfiguration.invitationRecordType)
        record["code"] = code
        record["email"] = email
        record["created"] = Date()
        record["status"] = "pending"
        record["role"] = role.rawValue
        
        // Get the current user's name
        let creatorName = getCurrentUserName()
        record["creator"] = creatorName
            
        // Save the record
        CloudKitConfiguration.privateDatabase.save(record) { [weak self] (savedRecord, error) in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(nil, error)
                } else {
                    // Also create a UserPermission for the creator if they don't have one yet
                    self?.ensureCreatorHasAdminPermission(creatorName: creatorName)
                    
                    // Refresh invitations
                    self?.fetchInvitations()
                    
                    completion(code, nil)
                }
            }
        }
    }
    
    /// Fetches all invitations from CloudKit
    func fetchInvitations() {
        isLoading = true
        
        let query = CKQuery(recordType: CloudKitConfiguration.invitationRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "created", ascending: false)]
        
        if #available(iOS 15.0, macOS 12.0, *) {
            // Use the newer API for iOS 15+
            CloudKitConfiguration.privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CloudKitConfiguration.defaultQueryLimit) { [weak self] result in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    switch result {
                    case .success(let (matchResults, _)):
                        var fetchedInvitations: [CloudKitTypes.InvitationRecord] = []
                        
                        for (_, recordResult) in matchResults {
                            guard let record = try? recordResult.get(),
                                  let invitation = CloudKitTypes.InvitationRecord.from(record: record) else {
                                continue
                            }
                            
                            fetchedInvitations.append(invitation)
                        }
                        
                        self.invitations = fetchedInvitations
                    
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                        print("Error fetching invitations: \(error)")
                    }
                }
            }
        } else {
            // Fallback for older iOS versions
            let operation = CKQueryOperation(query: query)
            operation.resultsLimit = CloudKitConfiguration.defaultQueryLimit
            
            var fetchedInvitations: [CloudKitTypes.InvitationRecord] = []
            
            operation.recordFetchedBlock = { (record: CKRecord) in
                if let invitation = CloudKitTypes.InvitationRecord.from(record: record) {
                    fetchedInvitations.append(invitation)
                }
            }
            
            operation.queryCompletionBlock = { [weak self] (_, error: Error?) in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        print("Error fetching invitations: \(error)")
                    } else {
                        self.invitations = fetchedInvitations
                    }
                }
            }
            
            CloudKitConfiguration.privateDatabase.add(operation)
        }
    }
    
    /// Deletes an invitation from CloudKit
    /// - Parameters:
    ///   - invitation: The invitation to delete
    ///   - completion: Closure called when operation completes
    func deleteInvitation(_ invitation: CloudKitTypes.InvitationRecord, completion: @escaping (Error?) -> Void) {
        CloudKitConfiguration.privateDatabase.delete(withRecordID: invitation.id) { [weak self] (_, error: Error?) in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(error)
                } else {
                    // Remove from local array
                    self?.invitations.removeAll { $0.id == invitation.id }
                    completion(nil)
                }
            }
        }
    }
    
    /// Validates an invitation code
    /// - Parameters:
    ///   - code: The code to validate
    ///   - completion: Closure with validation result and optional error message
    func validateInvitation(code: String, completion: @escaping (Bool, String?) -> Void) {
        let predicate = NSPredicate(format: "code == %@ AND status == %@", code, "pending")
        
        if #available(iOS 15.0, macOS 12.0, *) {
            // Use the newer API for iOS 15+
            let query = CKQuery(recordType: CloudKitConfiguration.invitationRecordType, predicate: predicate)
            
            CloudKitConfiguration.privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let (matchResults, _)):
                    DispatchQueue.main.async {
                        if let _ = try? matchResults.first?.1.get() {
                            // Invitation exists and is pending
                            completion(true, nil)
                        } else {
                            // Check if it's already accepted
                            self.checkIfInvitationAccepted(code: code, completion: completion)
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(false, error.localizedDescription)
                    }
                }
            }
        } else {
            // Fallback for older iOS versions
            let query = CKQuery(recordType: CloudKitConfiguration.invitationRecordType, predicate: predicate)
            
            CloudKitConfiguration.privateDatabase.perform(query, inZoneWith: nil) { [weak self] (records: [CKRecord]?, error: Error?) in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    if let error = error {
                        completion(false, error.localizedDescription)
                        return
                    }
                    
                    if let _ = records?.first {
                        // Invitation exists and is pending
                        completion(true, nil)
                    } else {
                        // Check if it's already accepted
                        self.checkIfInvitationAccepted(code: code, completion: completion)
                    }
                }
            }
        }
    }
    
    /// Helper to check if an invitation has been accepted
    private func checkIfInvitationAccepted(code: String, completion: @escaping (Bool, String?) -> Void) {
        let acceptedPredicate = NSPredicate(format: "code == %@ AND status == %@", code, "accepted")
        let acceptedQuery = CKQuery(recordType: CloudKitConfiguration.invitationRecordType, predicate: acceptedPredicate)
        
        if #available(iOS 15.0, macOS 12.0, *) {
            CloudKitConfiguration.privateDatabase.fetch(withQuery: acceptedQuery, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
                switch result {
                case .success(let (matchResults, _)):
                    DispatchQueue.main.async {
                        if let _ = try? matchResults.first?.1.get() {
                            completion(false, "This invitation has already been used.")
                        } else {
                            completion(false, "Invalid invitation code.")
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(false, error.localizedDescription)
                    }
                }
            }
        } else {
            CloudKitConfiguration.privateDatabase.perform(acceptedQuery, inZoneWith: nil) { (acceptedRecords: [CKRecord]?, error: Error?) in
                DispatchQueue.main.async {
                    if let _ = acceptedRecords?.first {
                        completion(false, "This invitation has already been used.")
                    } else {
                        completion(false, "Invalid invitation code.")
                    }
                }
            }
        }
    }
    
    /// Accepts an invitation to gain access to shared data
    /// - Parameters:
    ///   - code: The invitation code to accept
    ///   - completion: Closure with result and optional error message
    func acceptInvitation(code: String, completion: @escaping (Bool, String?) -> Void) {
        let predicate = NSPredicate(format: "code == %@ AND status == %@", code, "pending")
        
        if #available(iOS 15.0, macOS 12.0, *) {
            // Use the newer API for iOS 15+
            let query = CKQuery(recordType: CloudKitConfiguration.invitationRecordType, predicate: predicate)
            
            CloudKitConfiguration.privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let (matchResults, _)):
                    guard let _ = matchResults.first?.0,
                          let record = try? matchResults.first?.1.get() else {
                        DispatchQueue.main.async {
                            completion(false, "Invalid invitation code or already used.")
                        }
                        return
                    }
                    
                    self.processInvitationAcceptance(record: record, code: code, completion: completion)
                    
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(false, error.localizedDescription)
                    }
                }
            }
        } else {
            // Fallback for older iOS versions
            let query = CKQuery(recordType: CloudKitConfiguration.invitationRecordType, predicate: predicate)
            
            CloudKitConfiguration.privateDatabase.perform(query, inZoneWith: nil) { [weak self] (records: [CKRecord]?, error: Error?) in
                guard let self = self else { return }
                
                if let error = error {
                    DispatchQueue.main.async {
                        completion(false, error.localizedDescription)
                    }
                    return
                }
                
                guard let record = records?.first else {
                    DispatchQueue.main.async {
                        completion(false, "Invalid invitation code or already used.")
                    }
                    return
                }
                
                self.processInvitationAcceptance(record: record, code: code, completion: completion)
            }
        }
    }
    
    /// Helper to process the acceptance of an invitation
    private func processInvitationAcceptance(record: CKRecord, code: String, completion: @escaping (Bool, String?) -> Void) {
        // Update invitation status
        let userName = getCurrentUserName()
        
        record["status"] = "accepted"
        record["acceptedBy"] = userName
        record["acceptedDate"] = Date()
        
        CloudKitConfiguration.privateDatabase.save(record) { [weak self] (_, error: Error?) in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, error.localizedDescription)
                }
                return
            }
            
            // Create a user permission record
            CloudKitConfiguration.container.fetchUserRecordID { (recordID: CKRecord.ID?, error: Error?) in
                guard let recordID = recordID else {
                    DispatchQueue.main.async {
                        completion(false, "Could not get user ID.")
                    }
                    return
                }
                
                // Get the assigned role from the invitation
                let roleString = record["role"] as? String ?? CloudKitTypes.UserPermissionRecord.UserRole.editor.rawValue
                
                let permissionRecord = CKRecord(recordType: CloudKitConfiguration.userPermissionRecordType)
                permissionRecord["userId"] = recordID.recordName
                permissionRecord["userName"] = userName
                permissionRecord["email"] = record["email"]
                permissionRecord["role"] = roleString // Use the role from the invitation
                permissionRecord["invitationCode"] = code
                permissionRecord["addedDate"] = Date()
                
                CloudKitConfiguration.privateDatabase.save(permissionRecord) { (_, error: Error?) in
                    DispatchQueue.main.async {
                        if let error = error {
                            completion(false, error.localizedDescription)
                        } else {
                            // Mark that we're using shared data in UserDefaults
                            UserDefaults.standard.set(true, forKey: "isUsingSharedData")
                            
                            // Notify of changes
                            self.notifyDataSharingChanged()
                            
                            completion(true, nil)
                        }
                    }
                }
            }
        }
    }
    
    /// Helper method to ensure the creator has admin permission
    private func ensureCreatorHasAdminPermission(creatorName: String) {
        // Check if the current user already has admin permission
        CloudKitConfiguration.container.fetchUserRecordID { [weak self] (recordID: CKRecord.ID?, error: Error?) in
            guard let self = self else { return }
            guard let recordID = recordID else { return }
            
            let predicate = NSPredicate(format: "userId == %@", recordID.recordName)
            
            if #available(iOS 15.0, macOS 12.0, *) {
                // Use the newer API for iOS 15+
                let query = CKQuery(recordType: CloudKitConfiguration.userPermissionRecordType, predicate: predicate)
                
                CloudKitConfiguration.privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
                    switch result {
                    case .success(let (matchResults, _)):
                        if matchResults.isEmpty {
                            // Create admin permission for creator
                            self.createAdminPermissionForCreator(recordID: recordID, creatorName: creatorName)
                        }
                    case .failure(let error):
                        print("Error checking user permissions: \(error)")
                    }
                }
            } else {
                // Fallback for older iOS versions
                let query = CKQuery(recordType: CloudKitConfiguration.userPermissionRecordType, predicate: predicate)
                
                CloudKitConfiguration.privateDatabase.perform(query, inZoneWith: nil) { [weak self] (records: [CKRecord]?, error: Error?) in
                    guard let self = self else { return }
                    
                    if records?.isEmpty ?? true {
                        // Create admin permission for creator
                        self.createAdminPermissionForCreator(recordID: recordID, creatorName: creatorName)
                    }
                }
            }
        }
    }
    
    /// Creates an admin permission record for the creator
    private func createAdminPermissionForCreator(recordID: CKRecord.ID, creatorName: String) {
        let permissionRecord = CKRecord(recordType: CloudKitConfiguration.userPermissionRecordType)
        permissionRecord["userId"] = recordID.recordName
        permissionRecord["userName"] = creatorName
        permissionRecord["role"] = CloudKitTypes.UserPermissionRecord.UserRole.admin.rawValue
        permissionRecord["addedDate"] = Date()
        
        CloudKitConfiguration.privateDatabase.save(permissionRecord) { (_, _) in
            // No additional action needed
        }
    }
    
    /// Helper to get current user name
    private func getCurrentUserName() -> String {
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
    
    /// Notifies the system that data sharing mode has changed
    private func notifyDataSharingChanged() {
        NotificationCenter.default.post(name: Notification.Name("DataSharingModeChanged"), object: nil)
    }
}
