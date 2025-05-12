// AdminSetupView.swift - Simplified for user profile flow
import SwiftUI
import CloudKit

struct AdminSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cloudKitManager = CloudKitManager.shared
    
    // State for the setup process
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var setupComplete = false
    @State private var showingSuccess = false
    
    // State for determining setup approach
    @State private var adminExists = false
    @State private var isOwner = false
    @State private var isFirstUser = false
    @State private var showDebugInfo = false
    @State private var debugInfo = ""
    
    // For admin confirmation
    @State private var confirmAdminSetup = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {
                // Modified header for user profile flow
                Text("Administrator Setup")
                    .font(.title)
                    .bold()
                
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.blue)
                    .padding()
                
                // Add explanatory text for user profile context
                Text("You're currently using shared data mode. Would you like to set yourself up as an administrator?")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .foregroundColor(.secondary)
                
                if isProcessing {
                    ProgressView("Checking system status...")
                        .padding()
                } else {
                    // Main content based on current state
                    setupContentView
                }
                
                Spacer()
                
                // Admin capabilities card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Administrator Capabilities:")
                        .font(.subheadline)
                        .bold()
                    
                    capabilityRow(icon: "person.badge.plus", text: "Invite others to join")
                    capabilityRow(icon: "person.2.badge.gearshape", text: "Manage user permissions")
                    capabilityRow(icon: "person.crop.circle.badge.xmark", text: "Revoke access when needed")
                    capabilityRow(icon: "lock.shield", text: "Full control over shared data")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
                
                if showDebugInfo {
                    // Debug info section
                    debugInfoView
                }
            }
            .padding(.top, 20)
            .navigationTitle("Become Administrator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showDebugInfo.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Admin Setup Complete", isPresented: $showingSuccess) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("You now have administrator privileges and can invite others to join.")
            }
            .alert("Confirm Administrator Setup", isPresented: $confirmAdminSetup) {
                Button("Cancel", role: .cancel) { }
                Button("Make Me Admin", role: .none) {
                    setupAsAdmin()
                }
            } message: {
                Text("Are you sure you want to become an administrator? As an admin, you'll have full control over user access and permissions.")
            }
            .onAppear {
                checkSetupConditions()
            }
        }
    }
    
    // MARK: - Dynamic Content Based on State
    // Simplified for user profile context
    private var setupContentView: some View {
        VStack(spacing: 15) {
            if adminExists {
                // Admin already exists
                VStack(spacing: 10) {
                    warningCard(
                        title: "Administrator Already Exists",
                        message: "This system already has an administrator. Only existing administrators can grant admin privileges to other users.",
                        iconName: "exclamationmark.triangle"
                    )
                    
                    Text("Contact the system administrator if you need admin access.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                // Simplified to a single option for user profile flow
                infoCard(
                    title: "Become Administrator",
                    message: "As administrator, you'll be able to invite others and manage access to shared data.",
                    iconName: "person.badge.key"
                )
                
                Button {
                    confirmAdminSetup = true
                } label: {
                    Text("Set Up as Administrator")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Helper Views
    private func capabilityRow(icon: String, text: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
    }
    
    private func warningCard(title: String, message: String, iconName: String) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.orange)
                    .font(.title2)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func successCard(title: String, message: String, iconName: String) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.green)
                    .font(.title2)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.green)
            }
            
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func infoCard(title: String, message: String, iconName: String) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var debugInfoView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Debug Information")
                .font(.caption)
                .fontWeight(.bold)
            
            ScrollView {
                Text(debugInfo)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(height: 100)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Setup Logic
    
    // Check conditions to determine the appropriate setup approach
    private func checkSetupConditions() {
        isProcessing = true
        debugInfo = "Checking setup conditions...\n"
        
        // First ensure we're using shared storage
        if !isUsingSharedData() {
            debugInfo += "Enabling shared data mode...\n"
            toggleDataSharingMode(useShared: true)
            debugInfo += "✓ Shared data mode enabled\n"
        } else {
            debugInfo += "✓ Already using shared data mode\n"
        }
        
        // Check if authenticated
        if !isAuthenticated() {
            debugInfo += "❌ Error: User is not authenticated. Please sign in first.\n"
            isProcessing = false
            errorMessage = "You must sign in with your Apple ID before becoming an administrator."
            showError = true
            return
        }
        
        debugInfo += "✓ User is authenticated\n"
        
        // Check if an admin already exists
        cloudKitManager.checkIfAdminExists { exists in
            debugInfo += exists ? "An admin already exists in the system\n" : "No existing admin found\n"
            
            // Set the admin exists flag
            adminExists = exists
            
            if !exists {
                // Check if this user is the owner/creator of the CloudKit container
                checkIfUserIsOwner { isOwner in
                    self.isOwner = isOwner
                    debugInfo += isOwner ? "✓ User is the container owner\n" : "User is not the container owner\n"
                    
                    // Check if this is the first user
                    checkIfFirstUser { isFirst in
                        self.isFirstUser = isFirst
                        debugInfo += isFirst ? "✓ User is the first user\n" : "User is not the first user\n"
                        
                        // Setup is complete
                        isProcessing = false
                    }
                }
            } else {
                // Admin exists, no need for further checks
                isProcessing = false
            }
        }
    }
    
    // Set up the user as an admin
    private func setupAsAdmin() {
        isProcessing = true
        debugInfo += "Starting admin setup process...\n"
        
        // Create the admin permission record
        createAdminPermissionDirectly { success, message in
            if success {
                debugInfo += "✓ Successfully created admin permission record\n"
                
                // Refresh user role in the auth manager
                debugInfo += "Refreshing user role...\n"
                refreshUserRole()
                
                // Double-check the role updated successfully
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    checkIfUserIsAdmin { isAdmin in
                        isProcessing = false
                        
                        if isAdmin {
                            debugInfo += "✓ User role confirmed as admin\n"
                            showingSuccess = true
                        } else {
                            debugInfo += "❌ User role NOT updated to admin. Something went wrong.\n"
                            errorMessage = "Failed to update role to administrator. Please try again or contact support."
                            showError = true
                        }
                    }
                }
            } else {
                isProcessing = false
                debugInfo += "❌ Error creating admin permission: \(message ?? "Unknown error")\n"
                errorMessage = message ?? "Failed to set up admin account. Please try again."
                showError = true
            }
        }
    }
    
    // MARK: - Helper Functions
    
    // Create an admin permission record directly using CloudKit
    private func createAdminPermissionDirectly(completion: @escaping (Bool, String?) -> Void) {
        // Get current user ID
        let userId = getCurrentUserId()
        debugInfo += "Current user ID: \(userId)\n"
        
        // Create a permission record directly
        let permissionRecord = CKRecord(recordType: "UserPermission")
        permissionRecord["userId"] = userId
        permissionRecord["userName"] = getCurrentUserName()
        permissionRecord["role"] = "admin"
        permissionRecord["addedDate"] = Date()
        
        // Get the email if available
        if let email = getUserEmail() {
            permissionRecord["email"] = email
        }
        
        // Save the record to CloudKit
        let container = CKContainer(identifier: "iCloud.com.matthewstahl.BasicScheduleCPreparation")
        container.privateCloudDatabase.save(permissionRecord) { (record, error) in
            DispatchQueue.main.async {
                if let error = error {
                    debugInfo += "CloudKit error: \(error.localizedDescription)\n"
                    completion(false, "CloudKit error: \(error.localizedDescription)")
                } else {
                    completion(true, nil)
                }
            }
        }
    }
    
    // Check if the user is the owner of the CloudKit container
    private func checkIfUserIsOwner(completion: @escaping (Bool) -> Void) {
        let container = CKContainer(identifier: "iCloud.com.matthewstahl.BasicScheduleCPreparation")
        
        container.fetchUserRecordID { (recordID, error) in
            if let error = error {
                debugInfo += "Error fetching user record ID: \(error.localizedDescription)\n"
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            // Check container status - if there are no zones, this user is likely the creator
            container.privateCloudDatabase.fetchAllRecordZones { (zones, error) in
                DispatchQueue.main.async {
                    if let error = error {
                        debugInfo += "Error fetching zones: \(error.localizedDescription)\n"
                        completion(false)
                        return
                    }
                    
                    // If this is a new container or only has the default zone, this is likely the owner
                    let isNewContainer = zones?.count ?? 0 <= 1
                    completion(isNewContainer)
                }
            }
        }
    }
    
    // Check if this is the first user in the system
    private func checkIfFirstUser(completion: @escaping (Bool) -> Void) {
        let container = CKContainer(identifier: "iCloud.com.matthewstahl.BasicScheduleCPreparation")
        
        // Check if there are any user permission records
        let query = CKQuery(recordType: "UserPermission", predicate: NSPredicate(value: true))
        
        container.privateCloudDatabase.perform(query, inZoneWith: nil) { (records, error) in
            DispatchQueue.main.async {
                if let error = error {
                    debugInfo += "Error checking for users: \(error.localizedDescription)\n"
                    completion(false)
                    return
                }
                
                // If there are no user records, this is the first user
                let isFirstUser = records?.isEmpty ?? true
                completion(isFirstUser)
            }
        }
    }
    
    // Helper to check if shared data is enabled
    private func isUsingSharedData() -> Bool {
        return UserDefaults.standard.bool(forKey: "isUsingSharedData")
    }
    
    // Helper to check if user is authenticated
    private func isAuthenticated() -> Bool {
        let authManager = AuthAccess.getAuthManager()
        
        if let authObj = authManager as? NSObject {
            let selector = NSSelectorFromString("isAuthenticated")
            if authObj.responds(to: selector) {
                let result = authObj.perform(selector)
                if let boolValue = result?.takeUnretainedValue() as? Bool {
                    return boolValue
                }
            }
        }
        
        // Default to checking UserDefaults
        return UserDefaults.standard.bool(forKey: "isAuthenticated")
    }
    
    // Helper to toggle data sharing mode
    private func toggleDataSharingMode(useShared: Bool) {
        UserDefaults.standard.set(useShared, forKey: "isUsingSharedData")
        
        if useShared {
            PersistenceController.shared.switchToSharedStore()
        } else {
            PersistenceController.shared.switchToLocalStore()
        }
        
        // Notify about the change
        NotificationCenter.default.post(name: Notification.Name("DataSharingModeChanged"), object: nil)
    }
    
    // Helper to get current user ID
    private func getCurrentUserId() -> String {
        let authManager = AuthAccess.getAuthManager()
        
        if let authObj = authManager as? NSObject {
            let selector = NSSelectorFromString("getCurrentUserId")
            if authObj.responds(to: selector) {
                let result = authObj.perform(selector)
                if let userId = result?.takeUnretainedValue() as? String {
                    return userId
                }
            }
        }
        
        // Fallback to device ID
        #if os(iOS)
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #elseif os(macOS)
        return ProcessInfo.processInfo.globallyUniqueString
        #else
        return UUID().uuidString
        #endif
    }
    
    // Helper to get current user name
    private func getCurrentUserName() -> String {
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
    
    // Helper to get user email
    private func getUserEmail() -> String? {
        let authManager = AuthAccess.getAuthManager()
        if let authObj = authManager as? NSObject {
            // Use value(forKey:) to access properties
            if let user = authObj.value(forKey: "currentUser") as? NSObject {
                if let email = user.value(forKey: "email") as? String {
                    return email
                }
            }
        }
        return nil
    }
    
    // Refresh user role
    private func refreshUserRole() {
        let authManager = AuthAccess.getAuthManager()
        
        if let authObj = authManager as? NSObject {
            let selector = NSSelectorFromString("refreshUserRole")
            if authObj.responds(to: selector) {
                authObj.perform(selector)
            }
        }
    }
    
    // Check if user is admin after setting up
    private func checkIfUserIsAdmin(completion: @escaping (Bool) -> Void) {
        let authManager = AuthAccess.getAuthManager()
        
        if let authObj = authManager as? NSObject {
            let selector = NSSelectorFromString("isAdmin")
            if authObj.responds(to: selector) {
                let result = authObj.perform(selector)
                if let isAdmin = result?.takeUnretainedValue() as? Bool {
                    completion(isAdmin)
                    return
                }
            }
        }
        
        // Fallback - check CloudKit directly
        cloudKitManager.isUserAdmin { isAdmin in
            completion(isAdmin)
        }
    }
}
