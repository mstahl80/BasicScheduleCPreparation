// CloudKitPermissionManager.swift
import CloudKit
import Combine
import SwiftUI

/// Manages user permissions and access management for CloudKit
class CloudKitPermissionManager: ObservableObject {
    /// Published array of user permission records for SwiftUI binding
    @Published var permissions: [CloudKitTypes.UserPermissionRecord] = []
    
    /// Loading state indicator
    @Published var isLoading = false
    
    /// Error message if an operation fails
    @Published var errorMessage: String?
    
    /// Fetches all user permissions from CloudKit
    func fetchUserPermissions() {
        isLoading = true
        
        let query = CKQuery(recordType: CloudKitConfiguration.userPermissionRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "addedDate", ascending: false)]
        
        if #available(iOS 15.0, macOS 12.0, *) {
            // Use the newer API for iOS 15+
            CloudKitConfiguration.privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CloudKitConfiguration.defaultQueryLimit) { [weak self] result in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    switch result {
                    case .success(let (matchResults, _)):
                        var fetchedPermissions: [CloudKitTypes.UserPermissionRecord] = []
                        
                        for (_, recordResult) in matchResults {
                            guard let record = try? recordResult.get(),
                                  let permission = CloudKitTypes.UserPermissionRecord.from(record: record) else {
                                continue
                            }
                            
                            fetchedPermissions.append(permission)
                        }
                        
                        self.permissions = fetchedPermissions
                        
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                        print("Error fetching permissions: \(error)")
                    }
                }
            }
        } else {
            // Fallback for older iOS versions
            let operation = CKQueryOperation(query: query)
            operation.resultsLimit = CloudKitConfiguration.defaultQueryLimit
            
            var fetchedPermissions: [CloudKitTypes.UserPermissionRecord] = []
            
            operation.recordFetchedBlock = { (record: CKRecord) in
                if let permission = CloudKitTypes.UserPermissionRecord.from(record: record) {
                    fetchedPermissions.append(permission)
                }
            }
            
            operation.queryCompletionBlock = { [weak self] (_, error: Error?) in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        print("Error fetching permissions: \(error)")
                    } else {
                        self.permissions = fetchedPermissions
                    }
                }
            }
            
            CloudKitConfiguration.privateDatabase.add(operation)
        }
    }
    
    /// Revokes a user's access to shared data
    /// - Parameters:
    ///   - permission: The permission record to revoke
    ///   - completion: Closure called when the operation completes
    func revokeAccess(_ permission: CloudKitTypes.UserPermissionRecord, completion: @escaping (Error?) -> Void) {
        CloudKitConfiguration.privateDatabase.delete(withRecordID: permission.id) { [weak self] (_, error: Error?) in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(error)
                } else {
                    // Remove from local array
                    self?.permissions.removeAll { $0.id == permission.id }
                    
                    // If there's an invitation code, also mark it as revoked
                    if let code = permission.invitationCode {
                        self?.markInvitationAsRevoked(code: code)
                    }
                    
                    completion(nil)
                }
            }
        }
    }
    
    /// Update a user's permission role
    /// - Parameters:
    ///   - permission: The permission record to update
    ///   - newRole: The new role to assign
    ///   - completion: Closure called when the operation completes
    func updatePermissionRole(_ permission: CloudKitTypes.UserPermissionRecord, newRole: CloudKitTypes.UserPermissionRecord.UserRole, completion: @escaping (Error?) -> Void) {
        CloudKitConfiguration.privateDatabase.fetch(withRecordID: permission.id) { [weak self] (record: CKRecord?, error: Error?) in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    completion(error)
                }
                return
            }
            
            guard let record = record else {
                DispatchQueue.main.async {
                    let error = NSError(domain: "CloudKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Record not found"])
                    self.errorMessage = error.localizedDescription
                    completion(error)
                }
                return
            }
            
            record["role"] = newRole.rawValue
            
            CloudKitConfiguration.privateDatabase.save(record) { (_, error: Error?) in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        completion(error)
                    } else {
                        // Update local permissions
                        if let index = self.permissions.firstIndex(where: { $0.id == permission.id }) {
                            // Create a copy with the updated role
                            let updatedPermission = CloudKitTypes.UserPermissionRecord(
                                id: self.permissions[index].id,
                                userId: self.permissions[index].userId,
                                userName: self.permissions[index].userName,
                                email: self.permissions[index].email,
                                role: newRole,
                                invitationCode: self.permissions[index].invitationCode,
                                addedDate: self.permissions[index].addedDate
                            )
                            
                            // Update the array
                            self.permissions[index] = updatedPermission
                        }
                        
                        completion(nil)
                    }
                }
            }
        }
    }
    
    /// Checks if the current user is an admin
    /// - Parameter completion: Closure with result
    func isUserAdmin(completion: @escaping (Bool) -> Void) {
        checkUserAccessLevel { role in
            completion(role == .admin)
        }
    }
    
    /// Checks if any admin exists in the system
    /// - Parameter completion: Closure with result
    func checkIfAdminExists(completion: @escaping (Bool) -> Void) {
        let query = CKQuery(recordType: CloudKitConfiguration.userPermissionRecordType, predicate: NSPredicate(format: "role == %@", "admin"))
        
        if #available(iOS 15.0, macOS 12.0, *) {
            CloudKitConfiguration.privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
                switch result {
                case .success(let (matchResults, _)):
                    DispatchQueue.main.async {
                        completion(!matchResults.isEmpty)
                    }
                case .failure(_):
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            }
        } else {
            CloudKitConfiguration.privateDatabase.perform(query, inZoneWith: nil) { (records: [CKRecord]?, _) in
                DispatchQueue.main.async {
                    completion(!(records?.isEmpty ?? true))
                }
            }
        }
    }
    
    /// Checks the current user's access level
    /// - Parameter completion: Closure with the user's role or nil if none found
    func checkUserAccessLevel(completion: @escaping (CloudKitTypes.UserPermissionRecord.UserRole?) -> Void) {
        CloudKitConfiguration.container.fetchUserRecordID { (recordID: CKRecord.ID?, error: Error?) in
            guard let recordID = recordID else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let predicate = NSPredicate(format: "userId == %@", recordID.recordName)
            
            if #available(iOS 15.0, macOS 12.0, *) {
                // Use the newer API for iOS 15+
                let query = CKQuery(recordType: CloudKitConfiguration.userPermissionRecordType, predicate: predicate)
                
                CloudKitConfiguration.privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let (matchResults, _)):
                            if let record = try? matchResults.first?.1.get(),
                               let roleString = record["role"] as? String,
                               let role = CloudKitTypes.UserPermissionRecord.UserRole(rawValue: roleString) {
                                completion(role)
                            } else {
                                completion(nil)
                            }
                        case .failure(_):
                            completion(nil)
                        }
                    }
                }
            } else {
                // Fallback for older iOS versions
                let query = CKQuery(recordType: CloudKitConfiguration.userPermissionRecordType, predicate: predicate)
                
                CloudKitConfiguration.privateDatabase.perform(query, inZoneWith: nil) { (records: [CKRecord]?, error: Error?) in
                    DispatchQueue.main.async {
                        if let record = records?.first,
                           let roleString = record["role"] as? String,
                           let role = CloudKitTypes.UserPermissionRecord.UserRole(rawValue: roleString) {
                            completion(role)
                        } else {
                            completion(nil)
                        }
                    }
                }
            }
        }
    }
    
    /// Makes the current user an administrator
    /// - Parameter completion: Closure with result and optional error message
    func makeCurrentUserAdmin(completion: @escaping (Bool, String?) -> Void) {
        CloudKitConfiguration.container.fetchUserRecordID { [weak self] (recordID: CKRecord.ID?, error: Error?) in
            guard let self = self else { return }
            
            guard let recordID = recordID else {
                DispatchQueue.main.async {
                    completion(false, "Could not get user ID")
                }
                return
            }
            
            let userName = self.getCurrentUserName()
            
            // First check if this user already has a permission record
            let predicate = NSPredicate(format: "userId == %@", recordID.recordName)
            let query = CKQuery(recordType: CloudKitConfiguration.userPermissionRecordType, predicate: predicate)
            
            if #available(iOS 15.0, macOS 12.0, *) {
                CloudKitConfiguration.privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { [weak self] result in
                    guard let self = self else { return }
                    
                    switch result {
                    case .success(let (matchResults, _)):
                        if let _ = matchResults.first?.0,
                           let existingRecord = try? matchResults.first?.1.get() {
                            // Update existing record to admin role
                            self.updateExistingUserToAdmin(record: existingRecord, completion: completion)
                        } else {
                            // Create new admin permission record
                            self.createNewAdminUser(recordID: recordID, userName: userName, completion: completion)
                        }
                    case .failure(let error):
                        DispatchQueue.main.async {
                            completion(false, error.localizedDescription)
                        }
                    }
                }
            } else {
                // Fallback for older iOS versions
                CloudKitConfiguration.privateDatabase.perform(query, inZoneWith: nil) { [weak self] (records: [CKRecord]?, error: Error?) in
                    guard let self = self else { return }
                    
                    if let record = records?.first {
                        // Update existing record to admin role
                        self.updateExistingUserToAdmin(record: record, completion: completion)
                    } else {
                        // Create new admin permission record
                        self.createNewAdminUser(recordID: recordID, userName: userName, completion: completion)
                    }
                }
            }
        }
    }
    
    /// Helper to update an existing user record to admin role
    private func updateExistingUserToAdmin(record: CKRecord, completion: @escaping (Bool, String?) -> Void) {
        record["role"] = CloudKitTypes.UserPermissionRecord.UserRole.admin.rawValue
        
        CloudKitConfiguration.privateDatabase.save(record) { [weak self] (_, error: Error?) in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error.localizedDescription)
                } else {
                    // Refresh permissions
                    self?.fetchUserPermissions()
                    completion(true, nil)
                }
            }
        }
    }
    
    /// Helper to create a new admin user record
    private func createNewAdminUser(recordID: CKRecord.ID, userName: String, completion: @escaping (Bool, String?) -> Void) {
        let permissionRecord = CKRecord(recordType: CloudKitConfiguration.userPermissionRecordType)
        permissionRecord["userId"] = recordID.recordName
        permissionRecord["userName"] = userName
        permissionRecord["role"] = CloudKitTypes.UserPermissionRecord.UserRole.admin.rawValue
        permissionRecord["addedDate"] = Date()
        
        CloudKitConfiguration.privateDatabase.save(permissionRecord) { [weak self] (_, error: Error?) in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error.localizedDescription)
                } else {
                    // Refresh permissions
                    self?.fetchUserPermissions()
                    completion(true, nil)
                }
            }
        }
    }
    
    /// Helper to mark an invitation as revoked
    private func markInvitationAsRevoked(code: String) {
        let predicate = NSPredicate(format: "code == %@", code)
        
        if #available(iOS 15.0, macOS 12.0, *) {
            // Use the newer API for iOS 15+
            let query = CKQuery(recordType: CloudKitConfiguration.invitationRecordType, predicate: predicate)
            
            CloudKitConfiguration.privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
                switch result {
                case .success(let (matchResults, _)):
                    if let _ = matchResults.first?.0,
                       var record = try? matchResults.first?.1.get() {
                        record["status"] = "revoked"
                        CloudKitConfiguration.privateDatabase.save(record) { (_, _) in
                            // No additional handling needed
                        }
                    }
                case .failure(let error):
                    print("Error fetching invitation to revoke: \(error)")
                }
            }
        } else {
            // Fallback for older iOS versions
            let query = CKQuery(recordType: CloudKitConfiguration.invitationRecordType, predicate: predicate)
            
            CloudKitConfiguration.privateDatabase.perform(query, inZoneWith: nil) { (records: [CKRecord]?, error: Error?) in
                if let record = records?.first {
                    record["status"] = "revoked"
                    CloudKitConfiguration.privateDatabase.save(record) { (_, _) in
                        // No additional handling needed
                    }
                }
            }
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
}
