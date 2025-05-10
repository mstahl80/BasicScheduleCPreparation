// PersistenceController.swift
import CoreData
import CloudKit

class PersistenceController {
    static let shared = PersistenceController()
    
    // We'll keep two separate containers - one for local data and one for shared data
    let localContainer: NSPersistentContainer
    let sharedContainer: NSPersistentCloudKitContainer
    
    // Current container in use - either localContainer or sharedContainer
    private(set) var container: NSPersistentContainer
    
    // Local container name
    private let localContainerName = "BasicScheduleCPreparationLocal"
    // Shared container name
    private let sharedContainerName = "BasicScheduleCPreparation"
    
    init(inMemory: Bool = false) {
        // Initialize the local container (standard NSPersistentContainer)
        localContainer = NSPersistentContainer(name: localContainerName)
        
        // Configure local container
        if inMemory {
            localContainer.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Ensure we have a separate file URL for the local store
            let storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("\(localContainerName).sqlite")
            
            let description = NSPersistentStoreDescription(url: storeURL)
            localContainer.persistentStoreDescriptions = [description]
        }
        
        // Initialize the shared container with CloudKit
        sharedContainer = NSPersistentCloudKitContainer(name: sharedContainerName)
        
        // Configure shared container
        if inMemory {
            sharedContainer.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Enable history tracking for all stores
        for description in [localContainer.persistentStoreDescriptions, sharedContainer.persistentStoreDescriptions].flatMap({ $0 }) {
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        // Configure CloudKit integration for the shared container
        if let cloudKitOptions = sharedContainer.persistentStoreDescriptions.first?.cloudKitContainerOptions {
            cloudKitOptions.databaseScope = .private
        }
        
        // Check if we should start in shared mode
        let isUsingSharedData = UserDefaults.standard.bool(forKey: "isUsingSharedData")
        
        // Set the initial container
        container = isUsingSharedData ? sharedContainer : localContainer
        
        // Load appropriate container
        loadInitialContainer(isUsingSharedData: isUsingSharedData)
    }
    
    private func loadInitialContainer(isUsingSharedData: Bool) {
        // We'll always load the local container
        localContainer.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Error loading local store: \(error), \(error.userInfo)")
            }
        }
        
        // For shared mode, also load the shared container
        if isUsingSharedData {
            sharedContainer.loadPersistentStores { storeDescription, error in
                if let error = error as NSError? {
                    fatalError("Error loading shared store: \(error), \(error.userInfo)")
                }
            }
        }
        
        // Configure containers
        localContainer.viewContext.automaticallyMergesChangesFromParent = true
        localContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        sharedContainer.viewContext.automaticallyMergesChangesFromParent = true
        sharedContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
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
    
    // Generate an invitation code for sharing
    func generateInvitationCode(forEmail email: String, completion: @escaping (String?, Error?) -> Void) {
        // Generate a random 6-character code
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let code = String((0..<6).map { _ in letters.randomElement()! })
        
        // Save the invitation in UserDefaults with the email and creation date
        var invitations = UserDefaults.standard.dictionary(forKey: "sharingInvitations") as? [String: [String: Any]] ?? [:]
        
        invitations[code] = [
            "email": email,
            "created": Date(),
            "creator": UserAuthManager.shared.getCurrentUserDisplayName()
        ]
        
        UserDefaults.standard.set(invitations, forKey: "sharingInvitations")
        
        // In a real app, you would also store this in CloudKit for shared access
        // For now, we're simulating with UserDefaults
        
        completion(code, nil)
    }
    
    // Validate an invitation code
    func validateInvitationCode(_ code: String, completion: @escaping (Bool, String?) -> Void) {
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
                completion(false, "Invalid invitation code.")
            }
        }
    }
    
    // Accept an invitation
    func acceptInvitation(_ code: String, completion: @escaping (Bool, String?) -> Void) {
        validateInvitationCode(code) { isValid, errorMessage in
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
                completion(false, errorMessage)
            }
        }
    }
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}
