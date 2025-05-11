// CloudKitConfiguration.swift
import CloudKit

/// Central configuration for CloudKit-related settings and resources
enum CloudKitConfiguration {
    /// The iCloud container identifier
    static let containerIdentifier = "iCloud.com.matthewstahl.BasicScheduleCPreparation"
    
    /// The CloudKit container
    static let container = CKContainer(identifier: containerIdentifier)
    
    /// The private database in the CloudKit container
    static let privateDatabase = container.privateCloudDatabase
    
    /// The shared database in the CloudKit container
    static let sharedDatabase = container.sharedCloudDatabase
    
    /// The public database in the CloudKit container
    static let publicDatabase = container.publicCloudDatabase
    
    // Record type names
    static let invitationRecordType = "Invitation"
    static let userPermissionRecordType = "UserPermission"
    static let sharedDataRecordType = "SharedData"
    
    // Zone names
    static let sharedZoneName = "com.matthewstahl.scheduleC"
    
    /// Default subscription notification configuration
    static func defaultNotificationInfo() -> CKSubscription.NotificationInfo {
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        return notificationInfo
    }
    
    /// Create a subscription ID for a specific record type
    static func subscriptionID(for recordType: String) -> String {
        return "\(recordType)-changes-subscription"
    }
    
    /// Maximum number of records to fetch in a single query
    static let defaultQueryLimit = 100
    
    /// Time to cache query results (in seconds)
    static let queryCacheTime: TimeInterval = 300 // 5 minutes
    
    /// Default error handler that logs errors
    static func logError(_ error: Error?, operation: String) {
        if let error = error {
            print("CloudKit error during \(operation): \(error.localizedDescription)")
            if let ckError = error as? CKError {
                print("CKError code: \(ckError.code.rawValue)")
            }
        }
    }
    
    /// Determine if an error is a network-related issue
    static func isNetworkError(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else {
            return false
        }
        
        switch ckError.code {
        case .networkUnavailable,
             .networkFailure,
             .serviceUnavailable,
             .requestRateLimited,
             .zoneBusy:
            return true
        default:
            return false
        }
    }
    
    /// Determine if an error is a permission issue
    static func isPermissionError(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else {
            return false
        }
        
        return ckError.code == .permissionFailure ||
               ckError.code == .notAuthenticated
    }
}
