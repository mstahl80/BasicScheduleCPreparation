// CloudKitSharingManager.swift - Fixed version
import CloudKit
import SwiftUI

/// Manages CloudKit sharing functionality
class CloudKitSharingManager: ObservableObject {
    /// Error message if an operation fails
    private(set) var errorMessage: String?
    
    /// Setup CloudKit sharing for data
    /// - Parameter completion: Closure with the created share and optional error
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

    /// Modern CloudKit sharing setup (iOS 15+)
    /// - Parameter completion: Closure with the created share and optional error
    @available(iOS 15.0, macOS 12.0, *)
    func setupModernCloudKitSharing(completion: @escaping (CKShare?, Error?) -> Void) {
        // Create a CKShare directly
        let zoneID = CKRecordZone.ID(zoneName: CloudKitConfiguration.sharedZoneName, ownerName: CKCurrentUserDefaultName)
        let share = CKShare(recordZoneID: zoneID)
        share.publicPermission = .readWrite
        
        // Set up share metadata
        share[CKShare.SystemFieldKey.title] = "Schedule C Shared Data" as CKRecordValue
        
        // Save the share
        CloudKitConfiguration.privateDatabase.save(share) { (savedRecord: CKRecord?, error: Error?) in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(nil, error)
                } else if let savedShare = savedRecord as? CKShare {
                    completion(savedShare, nil)
                } else {
                    let error = NSError(domain: "CloudKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create share"])
                    self.errorMessage = error.localizedDescription
                    completion(nil, error)
                }
            }
        }
    }

    /// Legacy CloudKit sharing setup (pre-iOS 15)
    /// - Parameter completion: Closure with the created share and optional error
    func setupLegacyCloudKitSharing(completion: @escaping (CKShare?, Error?) -> Void) {
        // Create a record to share
        let recordID = CKRecord.ID(recordName: "SharedScheduleCData")
        let record = CKRecord(recordType: CloudKitConfiguration.sharedDataRecordType, recordID: recordID)
        record["title"] = "Schedule C Shared Data" as CKRecordValue
        record["creator"] = self.getCurrentUserName() as CKRecordValue
        
        // Save the record first
        CloudKitConfiguration.privateDatabase.save(record) { (savedRecord: CKRecord?, error: Error?) in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    completion(nil, error)
                }
                return
            }
            
            guard let savedRecord = savedRecord else {
                let error = NSError(domain: "CloudKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to save record"])
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    completion(nil, error)
                }
                return
            }
            
            // Now create a share for the record
            let share = CKShare(rootRecord: savedRecord)
            share.publicPermission = .readWrite
            
            // Save the share
            CloudKitConfiguration.privateDatabase.save(share) { (savedShare: CKRecord?, error: Error?) in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        completion(nil, error)
                    } else if let savedShare = savedShare as? CKShare {
                        completion(savedShare, nil)
                    } else {
                        let error = NSError(domain: "CloudKitManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create share"])
                        self.errorMessage = error.localizedDescription
                        completion(nil, error)
                    }
                }
            }
        }
    }
    
    /// Creates a new shared zone
    /// - Parameter completion: Closure with the created zone and optional error
    func createSharedZone(completion: @escaping (CKRecordZone?, Error?) -> Void) {
        // Create a custom zone for shared data
        let zoneID = CKRecordZone.ID(zoneName: CloudKitConfiguration.sharedZoneName, ownerName: CKCurrentUserDefaultName)
        let zone = CKRecordZone(zoneID: zoneID)
        
        CloudKitConfiguration.privateDatabase.save(zone) { (savedZone, error) in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(nil, error)
                } else {
                    completion(savedZone, nil)
                }
            }
        }
    }
    
    /// Adds a participant to a share
    /// - Parameters:
    ///   - share: The share to modify
    ///   - emailAddress: Email of the participant to add
    ///   - permission: The permission level for the participant
    ///   - completion: Closure with the updated share and optional error
    func addParticipantToShare(share: CKShare, emailAddress: String, permission: CKShare.ParticipantPermission, completion: @escaping (CKShare?, Error?) -> Void) {
        // Create a participant
        let participant = CKShare.Participant(emailAddress: emailAddress, permission: permission)
        
        // Add to the share
        share.addParticipant(participant)
        
        // Save the updated share
        CloudKitConfiguration.privateDatabase.save(share) { (savedRecord, error) in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(nil, error)
                } else if let savedShare = savedRecord as? CKShare {
                    completion(savedShare, nil)
                } else {
                    let error = NSError(domain: "CloudKitManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to save updated share"])
                    self.errorMessage = error.localizedDescription
                    completion(nil, error)
                }
            }
        }
    }
    
    /// Fetches all shares owned by the current user
    /// - Parameter completion: Closure with array of shares and optional error
    func fetchUserShares(completion: @escaping ([CKShare]?, Error?) -> Void) {
        // Fixed line: Use string literal for share record type
        let query = CKQuery(recordType: "cloudkit.share", predicate: NSPredicate(value: true))
        
        if #available(iOS 15.0, macOS 12.0, *) {
            // Use the newer API for iOS 15+
            CloudKitConfiguration.privateDatabase.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CloudKitConfiguration.defaultQueryLimit) { result in
                switch result {
                case .success(let (matchResults, _)):
                    var shares: [CKShare] = []
                    
                    for (_, recordResult) in matchResults {
                        if let record = try? recordResult.get(),
                           let share = record as? CKShare {
                            shares.append(share)
                        }
                    }
                    
                    DispatchQueue.main.async {
                        completion(shares, nil)
                    }
                    
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(nil, error)
                    }
                }
            }
        } else {
            // Fallback for older iOS versions
            CloudKitConfiguration.privateDatabase.perform(query, inZoneWith: nil) { (records, error) in
                var shares: [CKShare] = []
                
                if let records = records {
                    for record in records {
                        if let share = record as? CKShare {
                            shares.append(share)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    completion(error != nil ? nil : shares, error)
                }
            }
        }
    }
    
    /// Removes a participant from a share
    /// - Parameters:
    ///   - share: The share to modify
    ///   - participant: The participant to remove
    ///   - completion: Closure with the updated share and optional error
    func removeParticipantFromShare(share: CKShare, participant: CKShare.Participant, completion: @escaping (CKShare?, Error?) -> Void) {
        // Remove the participant
        share.removeParticipant(participant)
        
        // Save the updated share
        CloudKitConfiguration.privateDatabase.save(share) { (savedRecord, error) in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(nil, error)
                } else if let savedShare = savedRecord as? CKShare {
                    completion(savedShare, nil)
                } else {
                    let error = NSError(domain: "CloudKitManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to save updated share"])
                    self.errorMessage = error.localizedDescription
                    completion(nil, error)
                }
            }
        }
    }
    
    /// Updates a participant's permission in a share
    /// - Parameters:
    ///   - share: The share to modify
    ///   - participant: The participant to update
    ///   - permission: The new permission level
    ///   - completion: Closure with the updated share and optional error
    func updateParticipantPermission(share: CKShare, participant: CKShare.Participant, permission: CKShare.ParticipantPermission, completion: @escaping (CKShare?, Error?) -> Void) {
        // Create a new participant with the updated permission
        if #available(iOS 15.0, macOS 12.0, *) {
            // In iOS 15+, we can directly update the permission
            participant.permission = permission
        } else {
            // For older iOS versions, remove and re-add the participant
            share.removeParticipant(participant)
            
            if let emailAddress = participant.emailAddress {
                let newParticipant = CKShare.Participant(emailAddress: emailAddress, permission: permission)
                share.addParticipant(newParticipant)
            } else if let phoneNumber = participant.phoneNumber {
                let newParticipant = CKShare.Participant(phoneNumber: phoneNumber, permission: permission)
                share.addParticipant(newParticipant)
            } else {
                // Can't recreate the participant without contact info
                let error = NSError(domain: "CloudKitManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Cannot update participant without contact info"])
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    completion(nil, error)
                }
                return
            }
        }
        
        // Save the updated share
        CloudKitConfiguration.privateDatabase.save(share) { (savedRecord, error) in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(nil, error)
                } else if let savedShare = savedRecord as? CKShare {
                    completion(savedShare, nil)
                } else {
                    let error = NSError(domain: "CloudKitManager", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to save updated share"])
                    self.errorMessage = error.localizedDescription
                    completion(nil, error)
                }
            }
        }
    }
    
    /// Delete a share completely
    /// - Parameters:
    ///   - share: The share to delete
    ///   - completion: Closure with success indicator and optional error
    func deleteShare(share: CKShare, completion: @escaping (Bool, Error?) -> Void) {
        CloudKitConfiguration.privateDatabase.delete(withRecordID: share.recordID) { (_, error) in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(false, error)
                } else {
                    completion(true, nil)
                }
            }
        }
    }
    
    /// Accept a share invitation
    /// - Parameters:
    ///   - metadata: The share metadata
    ///   - completion: Closure with success indicator and optional error
    func acceptShareInvitation(metadata: CKShare.Metadata, completion: @escaping (Bool, Error?) -> Void) {
        let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
        
        operation.perShareCompletionBlock = { metadata, share, error in
            if let error = error {
                print("Error accepting share: \(error.localizedDescription)")
            } else {
                print("Share accepted successfully")
            }
        }
        
        operation.acceptSharesCompletionBlock = { error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(false, error)
                } else {
                    completion(true, nil)
                }
            }
        }
        
        // Add the operation to the container
        CloudKitConfiguration.container.add(operation)
    }
    
    /// Fetches root records of accepted shares
    /// - Parameter completion: Closure with array of records and optional error
    func fetchAcceptedShares(completion: @escaping ([(CKRecord, CKShare)]?, Error?) -> Void) {
        let operation = CKFetchRecordsWithSharesOperation.fetchAllRecordsWithShares()
        
        var recordsAndShares: [(CKRecord, CKShare)] = []
        
        operation.perRecordCompletionBlock = { record, share, error in
            if let error = error {
                print("Error fetching record: \(error.localizedDescription)")
            } else if let record = record, let share = share {
                recordsAndShares.append((record, share))
            }
        }
        
        // Fixed - Different handling based on API version
        if #available(iOS 15.0, macOS 12.0, *) {
            // Modern API - completion takes no arguments
            operation.fetchRecordsWithSharesCompletionBlock = {
                DispatchQueue.main.async {
                    completion(recordsAndShares, nil)
                }
            }
            
            // Set error handler separately
            operation.fetchRecordsWithSharesFailureBlock = { error in
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    completion(nil, error)
                }
            }
        } else {
            // Older API - completion takes error parameter
            #if compiler(>=5.7)  // Swift 5.7 or later
            // This is used for modern Xcode builds
            operation.fetchRecordsWithSharesCompletionBlock = { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        completion(nil, error)
                    } else {
                        completion(recordsAndShares, nil)
                    }
                }
            }
            #else
            // This is a fallback for older Xcode versions
            // On older builds we use type erasure to handle the difference
            let completionHandler: (Error?) -> Void = { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        completion(nil, error)
                    } else {
                        completion(recordsAndShares, nil)
                    }
                }
            }
            // Use Objective-C runtime to set the completion block
            let selector = NSSelectorFromString("setFetchRecordsWithSharesCompletionBlock:")
            let nsOperation = operation as AnyObject
            if nsOperation.responds(to: selector) {
                nsOperation.perform(selector, with: completionHandler)
            }
            #endif
        }
        
        CloudKitConfiguration.container.add(operation)
    }
    
    /// Checks for pending share invitations
    /// - Parameter completion: Closure with array of share metadata and optional error
    func checkForPendingShareInvitations(completion: @escaping ([CKShare.Metadata]?, Error?) -> Void) {
        CloudKitConfiguration.container.fetchShareMetadata(withURL: nil) { (metadata, _, error) in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(nil, error)
                } else if let metadata = metadata {
                    completion([metadata], nil)
                } else {
                    completion([], nil)
                }
            }
        }
    }
    
    /// Checks for all pending share invitations (latest API)
    @available(iOS 15.0, macOS 12.0, *)
    func fetchAllPendingShareInvitations(completion: @escaping ([CKShare.Metadata]?, Error?) -> Void) {
        CloudKitConfiguration.container.fetchAllPendingShareMetadata { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let metadatas):
                    completion(metadatas, nil)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    completion(nil, error)
                }
            }
        }
    }
    
    /// Presents the CloudKit sharing UI
    #if os(iOS)
    @available(iOS 13.0, *)
    func presentShareSheet(with share: CKShare, in viewController: UIViewController) {
        let sharingController = UICloudSharingController(share: share, container: CloudKitConfiguration.container)
        
        // Use delegate to handle callbacks
        let delegate = CloudKitSharingDelegate()
        sharingController.delegate = delegate
        
        viewController.present(sharingController, animated: true)
    }
    #endif
    
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

#if os(iOS)
/// Delegate class for UICloudSharingController
@available(iOS 13.0, *)
class CloudKitSharingDelegate: NSObject, UICloudSharingControllerDelegate, ObservableObject {
    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        print("Failed to save CloudKit share: \(error)")
    }
    
    func itemTitle(for csc: UICloudSharingController) -> String? {
        return "BasicScheduleCPreparation Shared Data"
    }
    
    func cloudSharingControllerDidCancel(_ csc: UICloudSharingController) {
        print("User cancelled sharing")
    }
    
    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        print("Successfully saved share")
    }
    
    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        print("Stopped sharing")
    }
}
#endif

/// Helper struct for CloudKit sharing in SwiftUI
#if os(iOS)
@available(iOS 13.0, *)
struct CloudKitShareButton: View {
    let share: CKShare
    
    @State private var sharingDelegate = CloudKitSharingDelegate()
    @State private var showShareSheet = false
    
    var body: some View {
        Button(action: {
            showShareSheet = true
        }) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        .background(
            EmptyView().sheet(isPresented: $showShareSheet) {
                CloudKitShareSheet(share: share, delegate: sharingDelegate)
            }
        )
    }
}

/// Wrapper view for UICloudSharingController in SwiftUI
@available(iOS 13.0, *)
struct CloudKitShareSheet: UIViewControllerRepresentable {
    let share: CKShare
    let delegate: UICloudSharingControllerDelegate
    
    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: CloudKitConfiguration.container)
        controller.delegate = delegate
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {
        // No updates needed
    }
}
#endif
