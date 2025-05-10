// PersistenceController.swift - Fixed version with recreateStore method
import CoreData
import CloudKit

class PersistenceController {
    static let shared = PersistenceController()
    
    // We'll keep two separate containers - one for local data and one for shared data
    let localContainer: NSPersistentContainer
    let sharedContainer: NSPersistentCloudKitContainer
    
    // Current container in use - either localContainer or sharedContainer
    private(set) var container: NSPersistentContainer
    
    // Container name
    private let containerName = "BasicScheduleCPreparation"
    
    init(inMemory: Bool = false) {
        // Initialize the local container (standard NSPersistentContainer)
        localContainer = NSPersistentContainer(name: containerName)
        
        // Configure local container
        if inMemory {
            localContainer.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Ensure we have a separate file URL for the local store
            let storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("\(containerName)_local.sqlite")
            
            let description = NSPersistentStoreDescription(url: storeURL)
            localContainer.persistentStoreDescriptions = [description]
        }
        
        // Initialize the shared container with CloudKit
        sharedContainer = NSPersistentCloudKitContainer(name: containerName)
        
        // Configure shared container
        if inMemory {
            sharedContainer.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Ensure we have a clear file URL for the shared store
            let storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("\(containerName)_shared.sqlite")
            
            let description = NSPersistentStoreDescription(url: storeURL)
            // Configure for CloudKit
            let containerIdentifier = "iCloud.com.matthewstahl.BasicScheduleCPreparation"
            let options = NSPersistentCloudKitContainerOptions(containerIdentifier: containerIdentifier)
            
            // Set the database scope to private
            options.databaseScope = .private
            
            // Enable sharing capabilities
            #if os(iOS) || os(macOS)
            if #available(iOS 15.0, macOS 12.0, *) {
                // On iOS 15+ / macOS 12+, we can use the new sharing API
                description.cloudKitContainerOptions = options
                
                // Configure sharing
                description.setOption(true as NSNumber, forKey: "NSPersistentStoreRemoteChangeNotificationPostOptionKey")
                description.setOption(true as NSNumber, forKey: "NSPersistentHistoryTrackingKey")
            } else {
                // Older versions use the basic CloudKit options without sharing
                description.cloudKitContainerOptions = options
            }
            #else
            // For other platforms, use basic CloudKit without sharing
            description.cloudKitContainerOptions = options
            #endif
            
            sharedContainer.persistentStoreDescriptions = [description]
        }
        
        // Enable history tracking for all stores
        for description in [localContainer.persistentStoreDescriptions, sharedContainer.persistentStoreDescriptions].flatMap({ $0 }) {
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        // Check if we should start in shared mode
        let isUsingSharedData = UserDefaults.standard.bool(forKey: "isUsingSharedData")
        
        // Set the initial container
        container = isUsingSharedData ? sharedContainer : localContainer
        
        // Load the appropriate containers
        // IMPORTANT: Actually load the stores before trying to use them!
        localContainer.loadPersistentStores { description, error in
            if let error = error as NSError? {
                // Instead of fatalError, log and handle gracefully
                print("Error loading local Core Data store: \(error), \(error.userInfo)")
                // Try to recover by recreating the store
                self.recreateStore(for: self.localContainer, at: description.url)
            }
        }
        
        if isUsingSharedData {
            sharedContainer.loadPersistentStores { description, error in
                if let error = error as NSError? {
                    print("Error loading shared Core Data store: \(error), \(error.userInfo)")
                    // Try to recover by recreating the store
                    self.recreateStore(for: self.sharedContainer, at: description.url)
                }
            }
        }
        
        // Configure containers for automatic merging of changes
        localContainer.viewContext.automaticallyMergesChangesFromParent = true
        localContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        sharedContainer.viewContext.automaticallyMergesChangesFromParent = true
        sharedContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // Helper method to recover from store loading errors
    private func recreateStore(for container: NSPersistentContainer, at url: URL?) {
        guard let url = url else { return }
        
        // Try to delete the existing store
        do {
            try FileManager.default.removeItem(at: url)
            // Try loading it again
            container.loadPersistentStores { description, error in
                if let error = error {
                    print("Failed to recreate store at \(url): \(error.localizedDescription)")
                } else {
                    print("Successfully recreated store at \(url)")
                }
            }
        } catch {
            print("Failed to delete corrupt store at \(url): \(error.localizedDescription)")
        }
    }
    
    // Switch to local data store
    func switchToLocalStore() {
        container = localContainer
        NotificationCenter.default.post(name: Notification.Name("StoreContainerChanged"), object: nil)
    }
    
    // Switch to shared data store, loading it if necessary
    func switchToSharedStore() {
        // Make sure the shared container is loaded
        if sharedContainer.persistentStoreCoordinator.persistentStores.isEmpty {
            sharedContainer.loadPersistentStores { storeDescription, error in
                if let error = error as NSError? {
                    print("Error loading shared store: \(error), \(error.userInfo)")
                    return
                }
                
                self.completeSharedStoreSwitch()
            }
        } else {
            completeSharedStoreSwitch()
        }
    }
    
    private func completeSharedStoreSwitch() {
        container = sharedContainer
        NotificationCenter.default.post(name: Notification.Name("StoreContainerChanged"), object: nil)
    }
    
    // Custom validation for invitation code (implementation without CloudKit)
    func validateInvitationCode(_ code: String, completion: @escaping (Bool, String?) -> Void) {
        // For backward compatibility, use UserDefaults-based validation in addition to CloudKit
        let invitations = UserDefaults.standard.dictionary(forKey: "sharingInvitations") as? [String: [String: Any]] ?? [:]
        
        if let _ = invitations[code] {
            // Invitation exists
            completion(true, nil)
        } else {
            // Check if it's an accepted code (for simulation)
            let acceptedCodes = UserDefaults.standard.array(forKey: "acceptedInvitationCodes") as? [String] ?? []
            if acceptedCodes.contains(code) {
                completion(true, nil)
            } else {
                // Try to validate with CloudKit
                CloudKitManager.shared.validateInvitation(code: code, completion: completion)
            }
        }
    }
    
    // Accept an invitation (implementation without CloudKit)
    func acceptInvitation(_ code: String, completion: @escaping (Bool, String?) -> Void) {
        validateInvitationCode(code) { isValid, message in
            if isValid {
                // Store the accepted code
                var acceptedCodes = UserDefaults.standard.array(forKey: "acceptedInvitationCodes") as? [String] ?? []
                if !acceptedCodes.contains(code) {
                    acceptedCodes.append(code)
                    UserDefaults.standard.set(acceptedCodes, forKey: "acceptedInvitationCodes")
                }
                
                // Mark that we're using shared data
                UserDefaults.standard.set(true, forKey: "isUsingSharedData")
                
                completion(true, nil)
            } else {
                // Try with CloudKit
                CloudKitManager.shared.acceptInvitation(code: code, completion: completion)
            }
        }
    }
    
    // Legacy method for generating invitation code (without CloudKit)
    func generateInvitationCode(forEmail email: String, completion: @escaping (String?, Error?) -> Void) {
        // Generate a random 6-character code (this will fall back to CloudKit implementation)
        CloudKitManager.shared.createInvitation(email: email, completion: completion)
    }
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Core Data save error: \(error.localizedDescription)")
            }
        }
    }
}
