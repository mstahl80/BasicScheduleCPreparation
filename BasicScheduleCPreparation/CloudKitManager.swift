// CloudKitManager.swift
import CloudKit
import CoreData
import SwiftUI

class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase
    
    // Record types
    private let invitationRecordType = "Invitation"
    private let userPermissionRecordType = "UserPermission"
    
    // Published properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var invitations: [InvitationRecord] = []
    @Published var permissions: [UserPermissionRecord] = []
    
    // Data models for CloudKit records
    struct InvitationRecord: Identifiable {
        let id: CKRecord.ID
        let code: String
        let email: String
        let created: Date
        let creator: String
        let status: InvitationStatus
        let acceptedBy: String?
        let acceptedDate: Date?
        
        enum InvitationStatus: String {
            case pending = "pending"
            case accepted = "accepted"
            case revoked = "revoked"
        }
    }
    
    struct UserPermissionRecord: Identifiable {
        let id: CKRecord.ID
        let userId: String
        let userName: String
        let email: String?
        let role: UserRole
        let invitationCode: String?
        let addedDate: Date
        
        enum UserRole: String {
            case admin = "admin"
            case editor = "editor"
            case viewer = "viewer"
        }
    }
    
    private init() {
        container = CKContainer(identifier: "iCloud.com.matthewstahl.BasicScheduleCPreparation")
        privateDatabase = container.privateCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
        
        // Setup notification subscriptions
        setupSubscriptions()
    }
    
    // MARK: - Subscriptions
    
    private func setupSubscriptions() {
        // Set up a subscription for invitation changes
        let invitationPredicate = NSPredicate(value: true)
        
        // Use the newer subscription initialization with explicit ID
        let invitationSubscriptionID = "invitation-changes-subscription"
        let invitationSubscription = CKQuerySubscription(
            recordType: invitationRecordType,
            predicate: invitationPredicate,
            subscriptionID: invitationSubscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        invitationSubscription.notificationInfo = notificationInfo
        
        privateDatabase.save(invitationSubscription) { (_, error: Error?) in
            if let error = error {
                print("Failed to create invitation subscription: \(error)")
            } else {
                print("Successfully created invitation subscription")
            }
        }
        
        // Set up a subscription for permission changes
        let permissionPredicate = NSPredicate(value: true)
        
        // Use the newer subscription initialization with explicit ID
        let permissionSubscriptionID = "permission-changes-subscription"
        let permissionSubscription = CKQuerySubscription(
            recordType: self.userPermissionRecordType,
            predicate: permissionPredicate,
            subscriptionID: permissionSubscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        permissionSubscription.notificationInfo = notificationInfo
        
        privateDatabase.save(permissionSubscription) { (_, error: Error?) in
            if let error = error {
                print("Failed to create permission subscription: \(error)")
            } else {
                print("Successfully created permission subscription")
            }
        }
    }
    
    // MARK: - User Identity
    
    // Helper to get current user name without UserAuthManager
    private func getCurrentUserName() -> String {
        // Try to get from AuthAccess first
        let authManager = AuthAccess.getAuthManager()
        if let authObj = authManager as? NSObject {
            let selector = NSSelectorFromString("getCurrentUserDisplayName")
            if authObj.responds(to: selector) {
                if let result = authObj.perform(selector)?.takeUnretainedValue() as? String {
                    return result
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
    
    func fetchUserIdentity(completion: @escaping (String, Error?) -> Void) {
        container.fetchUserRecordID { (recordID: CKRecord.ID?, error: Error?) in
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
    
    // MARK: - Invitations
    
    func createInvitation(email: String, role: UserPermissionRecord.UserRole = .editor, completion: @escaping (String?, Error?) -> Void) {
        isLoading = true
        
        // Generate a random 6-character code
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let code = String((0..<6).map { _ in letters.randomElement()! })
        
        // Create a new invitation record
        let record = CKRecord(recordType: invitationRecordType)
        record["code"] = code
        record["email"] = email
        record["created"] = Date()
        record["status"] = "pending"
        record["role"] = role.rawValue as String  // Explicitly cast to String
        
        // Get the current user's name
        let creatorName = getCurrentUserName()
        record["creator"] = creatorName
            
        // Save the record
        self.privateDatabase.save(record) { (_, error: Error?) in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(nil, error)
                } else {
                    // Also create a UserPermission for the creator if they don't have one yet
                    self.ensureCreatorHasAdminPermission(creatorName: creatorName)
                    
                    // Refresh invitations
                    self.fetchInvitations()
                    
                    completion(code, nil)
                }
            }
        }
    }
    
    func fetchInvitations() {
        isLoading = true
        
        let query = CKQuery(recordType: invitationRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "created", ascending: false)]
        
        if #available(iOS 15.0, macOS 12.0, *) {
            // Use the newer API for iOS 15+
            privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100) { [weak self] result in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    switch result {
                    case .success(let (matchResults, _)):
                        var fetchedInvitations: [InvitationRecord] = []
                        
                        for (_, recordResult) in matchResults {
                            guard let record = try? recordResult.get() else { continue }
                            
                            let code = record["code"] as? String ?? ""
                            let email = record["email"] as? String ?? ""
                            let created = record["created"] as? Date ?? Date()
                            let creator = record["creator"] as? String ?? ""
                            let statusString = record["status"] as? String ?? "pending"
                            let status = InvitationRecord.InvitationStatus(rawValue: statusString) ?? .pending
                            let acceptedBy = record["acceptedBy"] as? String
                            let acceptedDate = record["acceptedDate"] as? Date
                            
                            let invitation = InvitationRecord(
                                id: record.recordID,
                                code: code,
                                email: email,
                                created: created,
                                creator: creator,
                                status: status,
                                acceptedBy: acceptedBy,
                                acceptedDate: acceptedDate
                            )
                            
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
            operation.resultsLimit = 100
            
            var fetchedInvitations: [InvitationRecord] = []
            
            operation.recordFetchedBlock = { (record: CKRecord) in
                let code = record["code"] as? String ?? ""
                let email = record["email"] as? String ?? ""
                let created = record["created"] as? Date ?? Date()
                let creator = record["creator"] as? String ?? ""
                let statusString = record["status"] as? String ?? "pending"
                let status = InvitationRecord.InvitationStatus(rawValue: statusString) ?? .pending
                let acceptedBy = record["acceptedBy"] as? String
                let acceptedDate = record["acceptedDate"] as? Date
                
                let invitation = InvitationRecord(
                    id: record.recordID,
                    code: code,
                    email: email,
                    created: created,
                    creator: creator,
                    status: status,
                    acceptedBy: acceptedBy,
                    acceptedDate: acceptedDate
                )
                
                fetchedInvitations.append(invitation)
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
            
            privateDatabase.add(operation)
        }
    }
    
    func deleteInvitation(_ invitation: InvitationRecord, completion: @escaping (Error?) -> Void) {
        privateDatabase.delete(withRecordID: invitation.id) { (_, error: Error?) in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(error)
                } else {
                    // Remove from local array
                    self.invitations.removeAll { $0.id == invitation.id }
                    completion(nil)
                }
            }
        }
    }
    
    func validateInvitation(code: String, completion: @escaping (Bool, String?) -> Void) {
        let predicate = NSPredicate(format: "code == %@ AND status == %@", code, "pending")
        
        if #available(iOS 15.0, macOS 12.0, *) {
            // Use the newer API for iOS 15+
            let query = CKQuery(recordType: invitationRecordType, predicate: predicate)
            
            privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
                switch result {
                case .success(let (matchResults, _)):
                    DispatchQueue.main.async {
                        if let _ = try? matchResults.first?.1.get() {
                            // Invitation exists and is pending
                            completion(true, nil)
                        } else {
                            // Check if it's already accepted
                            let acceptedPredicate = NSPredicate(format: "code == %@ AND status == %@", code, "accepted")
                            let acceptedQuery = CKQuery(recordType: self.invitationRecordType, predicate: acceptedPredicate)
                            
                            self.privateDatabase.fetch(withQuery: acceptedQuery, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
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
            let query = CKQuery(recordType: invitationRecordType, predicate: predicate)
            
            privateDatabase.perform(query, inZoneWith: nil) { (records: [CKRecord]?, error: Error?) in
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
                        let acceptedPredicate = NSPredicate(format: "code == %@ AND status == %@", code, "accepted")
                        let acceptedQuery = CKQuery(recordType: self.invitationRecordType, predicate: acceptedPredicate)
                        
                        self.privateDatabase.perform(acceptedQuery, inZoneWith: nil) { (acceptedRecords: [CKRecord]?, error: Error?) in
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
            }
        }
    }
    
    func acceptInvitation(code: String, completion: @escaping (Bool, String?) -> Void) {
        let predicate = NSPredicate(format: "code == %@ AND status == %@", code, "pending")
        
        if #available(iOS 15.0, macOS 12.0, *) {
            // Use the newer API for iOS 15+
            let query = CKQuery(recordType: invitationRecordType, predicate: predicate)
            
            privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { [weak self] result in
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
                    
                    // Update invitation status
                    let userName = self.getCurrentUserName()
                    
                    record["status"] = "accepted"
                    record["acceptedBy"] = userName
                    record["acceptedDate"] = Date()
                    
                    self.privateDatabase.save(record) { (_, error: Error?) in
                        if let error = error {
                            DispatchQueue.main.async {
                                completion(false, error.localizedDescription)
                            }
                            return
                        }
                        
                        // Create a user permission record
                        self.container.fetchUserRecordID { (recordID: CKRecord.ID?, error: Error?) in
                            guard let recordID = recordID else {
                                DispatchQueue.main.async {
                                    completion(false, "Could not get user ID.")
                                }
                                return
                            }
                            
                            // Get the assigned role from the invitation
                            let roleString = record["role"] as? String ?? "editor"
                            // No need to convert to enum since we're just using the string
                            
                            let permissionRecord = CKRecord(recordType: self.userPermissionRecordType)
                            permissionRecord["userId"] = recordID.recordName
                            permissionRecord["userName"] = userName
                            permissionRecord["email"] = record["email"]
                            permissionRecord["role"] = roleString // Use the role from the invitation
                            permissionRecord["invitationCode"] = code
                            permissionRecord["addedDate"] = Date()
                            
                            self.privateDatabase.save(permissionRecord) { (_, error: Error?) in
                                DispatchQueue.main.async {
                                    if let error = error {
                                        completion(false, error.localizedDescription)
                                    } else {
                                        // Mark that we're using shared data in UserDefaults
                                        UserDefaults.standard.set(true, forKey: "isUsingSharedData")
                                        
                                        // Refresh permissions
                                        self.fetchUserPermissions()
                                        
                                        completion(true, nil)
                                    }
                                }
                            }
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
            let query = CKQuery(recordType: invitationRecordType, predicate: predicate)
            
            privateDatabase.perform(query, inZoneWith: nil) { [weak self] (records: [CKRecord]?, error: Error?) in
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
                
                // Update invitation status
                let userName = self.getCurrentUserName()
                
                record["status"] = "accepted"
                record["acceptedBy"] = userName
                record["acceptedDate"] = Date()
                
                self.privateDatabase.save(record) { (_, error: Error?) in
                    if let error = error {
                        DispatchQueue.main.async {
                            completion(false, error.localizedDescription)
                        }
                        return
                    }
                    
                    // Create a user permission record
                    self.container.fetchUserRecordID { (recordID: CKRecord.ID?, error: Error?) in
                        guard let recordID = recordID else {
                            DispatchQueue.main.async {
                                completion(false, "Could not get user ID.")
                            }
                            return
                        }
                        
                        // Get the assigned role from the invitation
                        let roleString = record["role"] as? String ?? "editor"
                        // No need to convert to enum since we're just using the string
                        
                        let permissionRecord = CKRecord(recordType: self.userPermissionRecordType)
                        permissionRecord["userId"] = recordID.recordName
                        permissionRecord["userName"] = userName
                        permissionRecord["email"] = record["email"]
                        permissionRecord["role"] = roleString  // Use the role from the invitation
                        permissionRecord["invitationCode"] = code
                        permissionRecord["addedDate"] = Date()
                        
                        self.privateDatabase.save(permissionRecord) { (_, error: Error?) in
                            DispatchQueue.main.async {
                                if let error = error {
                                    completion(false, error.localizedDescription)
                                } else {
                                    // Mark that we're using shared data in UserDefaults
                                    UserDefaults.standard.set(true, forKey: "isUsingSharedData")
                                    
                                    // Refresh permissions
                                    self.fetchUserPermissions()
                                    
                                    completion(true, nil)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - User Permissions
    
    private func ensureCreatorHasAdminPermission(creatorName: String) {
        // Check if the current user already has admin permission
        container.fetchUserRecordID { (recordID: CKRecord.ID?, error: Error?) in
            guard let recordID = recordID else { return }
            
            let predicate = NSPredicate(format: "userId == %@", recordID.recordName)
            
            if #available(iOS 15.0, macOS 12.0, *) {
                // Use the newer API for iOS 15+
                let query = CKQuery(recordType: self.userPermissionRecordType, predicate: predicate)
                
                self.privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
                    switch result {
                    case .success(let (matchResults, _)):
                        if matchResults.isEmpty {
                            // Create admin permission for creator
                            let permissionRecord = CKRecord(recordType: self.userPermissionRecordType)
                            permissionRecord["userId"] = recordID.recordName
                            permissionRecord["userName"] = creatorName
                            permissionRecord["role"] = "admin"
                            permissionRecord["addedDate"] = Date()
                            
                            self.privateDatabase.save(permissionRecord) { (_, error: Error?) in
                                // Refresh permissions
                                self.fetchUserPermissions()
                            }
                        }
                    case .failure(let error):
                        print("Error checking user permissions: \(error)")
                    }
                }
            } else {
                // Fallback for older iOS versions
                let query = CKQuery(recordType: self.userPermissionRecordType, predicate: predicate)
                
                self.privateDatabase.perform(query, inZoneWith: nil) { (records: [CKRecord]?, error: Error?) in
                    if records?.isEmpty ?? true {
                        // Create admin permission for creator
                        let permissionRecord = CKRecord(recordType: self.userPermissionRecordType)
                        permissionRecord["userId"] = recordID.recordName
                        permissionRecord["userName"] = creatorName
                        permissionRecord["role"] = "admin"
                        permissionRecord["addedDate"] = Date()
                        
                        self.privateDatabase.save(permissionRecord) { (_, error: Error?) in
                            // Refresh permissions
                            self.fetchUserPermissions()
                        }
                    }
                }
            }
        }
    }
    
    func fetchUserPermissions() {
        let query = CKQuery(recordType: userPermissionRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "addedDate", ascending: false)]
        
        if #available(iOS 15.0, macOS 12.0, *) {
            // Use the newer API for iOS 15+
            privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100) { [weak self] result in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    switch result {
                    case .success(let (matchResults, _)):
                        var fetchedPermissions: [UserPermissionRecord] = []
                        
                        for (_, recordResult) in matchResults {
                            guard let record = try? recordResult.get() else { continue }
                            
                            let userId = record["userId"] as? String ?? ""
                            let userName = record["userName"] as? String ?? ""
                            let email = record["email"] as? String
                            let roleString = record["role"] as? String ?? "viewer"
                            let role = UserPermissionRecord.UserRole(rawValue: roleString) ?? .viewer
                            let invitationCode = record["invitationCode"] as? String
                            let addedDate = record["addedDate"] as? Date ?? Date()
                            
                            let permission = UserPermissionRecord(
                                id: record.recordID,
                                userId: userId,
                                userName: userName,
                                email: email,
                                role: role,
                                invitationCode: invitationCode,
                                addedDate: addedDate
                            )
                            
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
            operation.resultsLimit = 100
            
            var fetchedPermissions: [UserPermissionRecord] = []
            
            operation.recordFetchedBlock = { (record: CKRecord) in
                let userId = record["userId"] as? String ?? ""
                let userName = record["userName"] as? String ?? ""
                let email = record["email"] as? String
                let roleString = record["role"] as? String ?? "viewer"
                let role = UserPermissionRecord.UserRole(rawValue: roleString) ?? .viewer
                let invitationCode = record["invitationCode"] as? String
                let addedDate = record["addedDate"] as? Date ?? Date()
                
                let permission = UserPermissionRecord(
                    id: record.recordID,
                    userId: userId,
                    userName: userName,
                    email: email,
                    role: role,
                    invitationCode: invitationCode,
                    addedDate: addedDate
                )
                
                fetchedPermissions.append(permission)
            }
            
            operation.queryCompletionBlock = { [weak self] (_, error: Error?) in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        print("Error fetching permissions: \(error)")
                    } else {
                        self.permissions = fetchedPermissions
                    }
                }
            }
            
            privateDatabase.add(operation)
        }
    }
    
    func revokeAccess(_ permission: UserPermissionRecord, completion: @escaping (Error?) -> Void) {
        privateDatabase.delete(withRecordID: permission.id) { (_, error: Error?) in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(error)
                } else {
                    // Remove from local array
                    self.permissions.removeAll { $0.id == permission.id }
                    
                    // If there's an invitation code, also mark it as revoked
                    if let code = permission.invitationCode {
                        let predicate = NSPredicate(format: "code == %@", code)
                        
                        if #available(iOS 15.0, macOS 12.0, *) {
                            // Use the newer API for iOS 15+
                            let query = CKQuery(recordType: self.invitationRecordType, predicate: predicate)
                            
                            self.privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
                                switch result {
                                case .success(let (matchResults, _)):
                                    if let _ = matchResults.first?.0,
                                       var record = try? matchResults.first?.1.get() {
                                        record["status"] = "revoked"
                                        self.privateDatabase.save(record) { (_, error: Error?) in
                                            // Update local invitations
                                            self.fetchInvitations()
                                        }
                                    }
                                case .failure(let error):
                                    print("Error fetching invitation to revoke: \(error)")
                                }
                            }
                        } else {
                            // Fallback for older iOS versions
                            let query = CKQuery(recordType: self.invitationRecordType, predicate: predicate)
                            
                            self.privateDatabase.perform(query, inZoneWith: nil) { (records: [CKRecord]?, error: Error?) in
                                if let record = records?.first {
                                    record["status"] = "revoked"
                                    self.privateDatabase.save(record) { (_, error: Error?) in
                                        // Update local invitations
                                        self.fetchInvitations()
                                    }
                                }
                            }
                        }
                    }
                    
                    completion(nil)
                }
            }
        }
    }
    
    func updatePermissionRole(_ permission: UserPermissionRecord, newRole: UserPermissionRecord.UserRole, completion: @escaping (Error?) -> Void) {
        privateDatabase.fetch(withRecordID: permission.id) { (record: CKRecord?, error: Error?) in
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
            
            record["role"] = newRole.rawValue as String // Explicit cast to String
            
            self.privateDatabase.save(record) { (_, error: Error?) in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        completion(error)
                    } else {
                        // Update local permissions
                        if let index = self.permissions.firstIndex(where: { $0.id == permission.id }) {
                            var updatedPermission = self.permissions[index]
                            // Create a new instance with the updated role (since it's a struct)
                            updatedPermission = UserPermissionRecord(
                                id: updatedPermission.id,
                                userId: updatedPermission.userId,
                                userName: updatedPermission.userName,
                                email: updatedPermission.email,
                                role: newRole,
                                invitationCode: updatedPermission.invitationCode,
                                addedDate: updatedPermission.addedDate
                            )
                            self.permissions[index] = updatedPermission
                        }
                        
                        completion(nil)
                    }
                }
            }
        }
    }
    
    // MARK: - Admin Management
    
    func makeCurrentUserAdmin(completion: @escaping (Bool, String?) -> Void) {
        container.fetchUserRecordID { (recordID: CKRecord.ID?, error: Error?) in
            guard let recordID = recordID else {
                DispatchQueue.main.async {
                    completion(false, "Could not get user ID")
                }
                return
            }
            
            let userName = self.getCurrentUserName()
            
            // First check if this user already has a permission record
            let predicate = NSPredicate(format: "userId == %@", recordID.recordName)
            let query = CKQuery(recordType: self.userPermissionRecordType, predicate: predicate)
            
            if #available(iOS 15.0, macOS 12.0, *) {
                self.privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
                    switch result {
                    case .success(let (matchResults, _)):
                        if let _ = matchResults.first?.0,
                           let existingRecord = try? matchResults.first?.1.get() {
                            // Update existing record to admin role
                            existingRecord["role"] = "admin" as String
                            
                            self.privateDatabase.save(existingRecord) { (_, error: Error?) in
                                DispatchQueue.main.async {
                                    if let error = error {
                                        completion(false, error.localizedDescription)
                                    } else {
                                        // Refresh permissions
                                        self.fetchUserPermissions()
                                        completion(true, nil)
                                    }
                                }
                            }
                        } else {
                            // Create new admin permission record
                            let permissionRecord = CKRecord(recordType: self.userPermissionRecordType)
                            permissionRecord["userId"] = recordID.recordName
                            permissionRecord["userName"] = userName
                            permissionRecord["role"] = "admin" as String
                            permissionRecord["addedDate"] = Date()
                            
                            self.privateDatabase.save(permissionRecord) { (_, error: Error?) in
                                DispatchQueue.main.async {
                                    if let error = error {
                                        completion(false, error.localizedDescription)
                                    } else {
                                        // Refresh permissions
                                        self.fetchUserPermissions()
                                        completion(true, nil)
                                    }
                                }
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
                self.privateDatabase.perform(query, inZoneWith: nil) { (records: [CKRecord]?, error: Error?) in
                    if let record = records?.first {
                        // Update existing record to admin role
                        record["role"] = "admin" as String
                        
                        self.privateDatabase.save(record) { (_, error: Error?) in
                            DispatchQueue.main.async {
                                if let error = error {
                                    completion(false, error.localizedDescription)
                                } else {
                                    // Refresh permissions
                                    self.fetchUserPermissions()
                                    completion(true, nil)
                                }
                            }
                        }
                    } else {
                        // Create new admin permission record
                        let permissionRecord = CKRecord(recordType: self.userPermissionRecordType)
                        permissionRecord["userId"] = recordID.recordName
                        permissionRecord["userName"] = userName
                        permissionRecord["role"] = "admin" as String
                        permissionRecord["addedDate"] = Date()
                        
                        self.privateDatabase.save(permissionRecord) { (_, error: Error?) in
                            DispatchQueue.main.async {
                                if let error = error {
                                    completion(false, error.localizedDescription)
                                } else {
                                    // Refresh permissions
                                    self.fetchUserPermissions()
                                    completion(true, nil)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func checkIfAdminExists(completion: @escaping (Bool) -> Void) {
        let query = CKQuery(recordType: userPermissionRecordType, predicate: NSPredicate(format: "role == %@", "admin"))
        
        if #available(iOS 15.0, macOS 12.0, *) {
            privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
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
            privateDatabase.perform(query, inZoneWith: nil) { (records: [CKRecord]?, _) in
                DispatchQueue.main.async {
                    completion(!(records?.isEmpty ?? true))
                }
            }
        }
    }
    
    // MARK: - Data Sharing
    
    func setupCloudKitSharing(completion: @escaping (CKShare?, Error?) -> Void) {
        #if os(iOS)
        if #available(iOS 15.0, macOS 12.0, *) {
            // iOS 15+ implementation using newer APIs
            setupModernCloudKitSharing(completion: completion)
        } else {
            // Fallback for older iOS versions
            setupLegacyCloudKitSharing(completion: completion)
        }
        #else
        // Non-iOS platforms use the legacy approach
        setupLegacyCloudKitSharing(completion: completion)
        #endif
    }

    // Implementation for iOS 15+ and macOS 12+
    @available(iOS 15.0, macOS 12.0, *)
    private func setupModernCloudKitSharing(completion: @escaping (CKShare?, Error?) -> Void) {
        // Create a CKShare directly
        let share = CKShare(recordZoneID: CKRecordZone.ID(zoneName: "com.matthewstahl.scheduleC", ownerName: CKCurrentUserDefaultName))
        share.publicPermission = .readWrite
        
        // Set up share metadata
        share[CKShare.SystemFieldKey.title] = "Schedule C Shared Data" as CKRecordValue
        
        // Save the share
        container.privateCloudDatabase.save(share) { (savedRecord: CKRecord?, error: Error?) in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                } else if let savedShare = savedRecord as? CKShare {
                    completion(savedShare, nil)
                } else {
                    let error = NSError(domain: "CloudKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create share"])
                    completion(nil, error)
                }
            }
        }
    }

    // Legacy implementation for older iOS versions
    private func setupLegacyCloudKitSharing(completion: @escaping (CKShare?, Error?) -> Void) {
        // Create a record to share
        let recordID = CKRecord.ID(recordName: "SharedScheduleCData")
        let record = CKRecord(recordType: "SharedData", recordID: recordID)
        record["title"] = "Schedule C Shared Data" as CKRecordValue
        record["creator"] = self.getCurrentUserName() as CKRecordValue
        
        // Save the record first
        container.privateCloudDatabase.save(record) { (savedRecord: CKRecord?, error: Error?) in
            if let error = error {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            guard let savedRecord = savedRecord else {
                let error = NSError(domain: "CloudKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to save record"])
                DispatchQueue.main.async {
                    completion(nil, error)
                }
                return
            }
            
            // Now create a share for the record
            let share = CKShare(rootRecord: savedRecord)
            share.publicPermission = .readWrite
            
            // Save the share
            self.container.privateCloudDatabase.save(share) { (savedShare: CKRecord?, error: Error?) in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(nil, error)
                    } else if let savedShare = savedShare as? CKShare {
                        completion(savedShare, nil)
                    } else {
                        let error = NSError(domain: "CloudKitManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create share"])
                        completion(nil, error)
                    }
                }
            }
        }
    }
    
    // MARK: - User Status
    
    func checkUserAccessLevel(completion: @escaping (UserPermissionRecord.UserRole?) -> Void) {
        container.fetchUserRecordID { (recordID: CKRecord.ID?, error: Error?) in
            guard let recordID = recordID else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let predicate = NSPredicate(format: "userId == %@", recordID.recordName)
            
            if #available(iOS 15.0, macOS 12.0, *) {
                // Use the newer API for iOS 15+
                let query = CKQuery(recordType: self.userPermissionRecordType, predicate: predicate)
                
                self.privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 1) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let (matchResults, _)):
                            if let record = try? matchResults.first?.1.get(),
                               let roleString = record["role"] as? String,
                               let role = UserPermissionRecord.UserRole(rawValue: roleString) {
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
                let query = CKQuery(recordType: self.userPermissionRecordType, predicate: predicate)
                
                self.privateDatabase.perform(query, inZoneWith: nil) { (records: [CKRecord]?, error: Error?) in
                    DispatchQueue.main.async {
                        if let record = records?.first,
                           let roleString = record["role"] as? String,
                           let role = UserPermissionRecord.UserRole(rawValue: roleString) {
                            completion(role)
                        } else {
                            completion(nil)
                        }
                    }
                }
            }
        }
    }
    
    func isUserAdmin(completion: @escaping (Bool) -> Void) {
        checkUserAccessLevel { role in
            completion(role == .admin)
        }
    }
}
