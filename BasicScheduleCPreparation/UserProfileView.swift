// UserProfileView.swift
import SwiftUI
import CloudKit

struct UserProfileView: View {
    // Use StateObject instead of EnvironmentObject to avoid type issues
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingSignOutConfirmation = false
    @State private var showingResetConfirmation = false
    @State private var showingSuccess = false
    @State private var successMessage = ""
    @State private var showingAdminSetup = false
    
    var body: some View {
        NavigationStack {
            List {
                // User Information Section
                Section("Account Information") {
                    if isUsingSharedData() {
                        // Only show user details in shared mode with authentication
                        if isAuthenticated() {
                            LabeledContent("Name", value: getCurrentUserDisplayName())
                            
                            if let email = getUserEmail() {
                                LabeledContent("Email", value: email)
                            }
                            
                            if let role = getUserRole() {
                                LabeledContent("Role", value: roleText(for: role))
                            }
                        }
                    } else {
                        // In standalone mode, show device info
                        #if os(iOS)
                        LabeledContent("Device", value: UIDevice.current.name)
                        #elseif os(macOS)
                        LabeledContent("Device", value: Host.current().localizedName ?? "Mac")
                        #endif
                    }
                    
                    // Show current data mode
                    HStack {
                        Image(systemName: isUsingSharedData() ? "cloud.fill" : "iphone")
                            .foregroundColor(isUsingSharedData() ? .blue : .green)
                        Text(isUsingSharedData() ? "Using Shared Data" : "Using Local Data")
                    }
                }
                
                // Data Mode Section
                Section("Data Management") {
                    NavigationLink(destination: ModeSwitcherView()) {
                        HStack {
                            Image(systemName: "arrow.triangle.swap")
                            Text("Change Data Mode")
                        }
                    }
                    
                    // Only show share option in shared mode
                    if isUsingSharedData() {
                        if isAdmin() {
                            NavigationLink(destination: ShareDataView()) {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                    Text("Invite Others")
                                }
                            }
                        }
                    }
                }
                
                // Admin Section
                Section("Admin Management") {
                    if isAdmin() {
                        NavigationLink(destination: AdminView()) {
                            HStack {
                                Image(systemName: "person.2.badge.key.fill")
                                Text("Manage Access")
                            }
                        }
                        .foregroundColor(.blue)
                    } else {
                        Button {
                            showingAdminSetup = true
                        } label: {
                            HStack {
                                Image(systemName: "key.fill")
                                Text("Set Up as Administrator")
                            }
                        }
                        .foregroundColor(.blue)
                    }
                    
                    // Show explanation text
                    if !isAdmin() {
                        Text("Administrators can invite other users and manage access to shared data.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Only show sign out in shared mode with authentication
                if isUsingSharedData() && isAuthenticated() {
                    Section {
                        Button(role: .destructive) {
                            showingSignOutConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                        }
                    }
                }
                
                // Troubleshooting Section
                Section("Troubleshooting") {
                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                            Text("Reset Database")
                        }
                    }
                    
                    Button {
                        clearAppCache()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear App Cache")
                        }
                    }
                    
                    // App information
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("App Version", value: getAppVersion())
                        LabeledContent("Build Number", value: getBuildNumber())
                        LabeledContent("Data Mode", value: isUsingSharedData() ? "Shared (CloudKit)" : "Standalone (Local)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                // App Credits
                Section("About") {
                    LabeledContent("Developer", value: "Matthew Stahl")
                    LabeledContent("Copyright", value: "© 2025 Matthew Stahl")
                    Text("BasicScheduleCPreparation is designed to help freelancers and small business owners track income and expenses for tax purposes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("User Profile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Sign Out?", isPresented: $showingSignOutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("Are you sure you want to sign out? You'll need to sign in again to access your shared data.")
            }
            .alert("Reset Database?", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    resetCoreDataStores()
                }
            } message: {
                Text("This will delete all data and reset the app. This action cannot be undone.")
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(successMessage)
            }
            .sheet(isPresented: $showingAdminSetup) {
                AdminSetupView()
            }
        }
    }
    
    // Helper methods
    
    private func roleText(for role: CloudKitManager.UserPermissionRecord.UserRole) -> String {
        switch role {
        case .admin:
            return "Administrator"
        case .editor:
            return "Editor"
        case .viewer:
            return "Viewer"
        }
    }
    
    private func getAppVersion() -> String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private func getBuildNumber() -> String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    // Helper to check if using shared data
    private func isUsingSharedData() -> Bool {
        return UserDefaults.standard.bool(forKey: "isUsingSharedData")
    }
    
    // Helper to check if authenticated
    private func isAuthenticated() -> Bool {
        return UserDefaults.standard.bool(forKey: "isAuthenticated")
    }
    
    // Helper to check if admin
    private func isAdmin() -> Bool {
        // Use reflection to access isAdmin without direct type reference
        let authManager = AuthAccess.getAuthManager()
        if let authObj = authManager as? NSObject {
            let selector = NSSelectorFromString("isAdmin")
            if authObj.responds(to: selector) {
                let result = authObj.perform(selector)
                if let boolValue = result?.takeUnretainedValue() as? Bool {
                    return boolValue
                }
            }
        }
        return false  // Default to false if we can't determine
    }
    
    // Helper to get current user name
    private func getCurrentUserDisplayName() -> String {
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
        
        // Default device name if not found
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
    
    // Helper to get user role
    private func getUserRole() -> CloudKitManager.UserPermissionRecord.UserRole? {
        let authManager = AuthAccess.getAuthManager()
        if let authObj = authManager as? NSObject {
            // Use value(forKey:) without conditional binding for non-optional selector
            if let roleValue = authObj.value(forKey: "userRole") as? Int {
                if roleValue >= 0 && roleValue < 3 {
                    let roleStrings = ["admin", "editor", "viewer"]
                    if let role = CloudKitManager.UserPermissionRecord.UserRole(rawValue: roleStrings[roleValue]) {
                        return role
                    }
                }
            } else if let roleString = authObj.value(forKey: "userRole") as? String,
                      let role = CloudKitManager.UserPermissionRecord.UserRole(rawValue: roleString) {
                return role
            }
        }
        
        // Try to get from CloudKit directly
        return cloudKitManager.permissions.first(where: { isCurrentUser(userId: $0.userId) })?.role
    }
    
    // Helper to check if user ID matches current user
    private func isCurrentUser(userId: String) -> Bool {
        // Implementation would need user ID which we can't easily get here
        // This is a placeholder that would always return false
        return false
    }
    
    // Helper to sign out
    private func signOut() {
        let authManager = AuthAccess.getAuthManager()
        if let authObj = authManager as? NSObject {
            let selector = NSSelectorFromString("signOut")
            if authObj.responds(to: selector) {
                authObj.perform(selector)
            }
        }
    }
    
    private func clearAppCache() {
        // Clear UserDefaults (except critical settings)
        let defaults = UserDefaults.standard
        
        // Save critical values
        let isUsingSharedData = defaults.bool(forKey: "isUsingSharedData")
        let currentUserData = defaults.data(forKey: "currentUser")
        let acceptedInvitationCode = defaults.string(forKey: "acceptedInvitationCode")
        
        // Clear all UserDefaults
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }
        
        // Restore critical values
        defaults.set(isUsingSharedData, forKey: "isUsingSharedData")
        if let userData = currentUserData {
            defaults.set(userData, forKey: "currentUser")
        }
        if let code = acceptedInvitationCode {
            defaults.set(code, forKey: "acceptedInvitationCode")
        }
        
        // Clear any temporary files
        let fileManager = FileManager.default
        let tempDirectoryURL = fileManager.temporaryDirectory
        
        do {
            let tempFiles = try fileManager.contentsOfDirectory(at: tempDirectoryURL, includingPropertiesForKeys: nil)
            for file in tempFiles {
                try fileManager.removeItem(at: file)
            }
            
            // Also clear the caches directory
            if let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
                let cacheFiles = try fileManager.contentsOfDirectory(at: cachesURL, includingPropertiesForKeys: nil)
                for file in cacheFiles {
                    try fileManager.removeItem(at: file)
                }
            }
            
            // Show success message
            successMessage = "Cache cleared successfully"
            showingSuccess = true
        } catch {
            print("Failed to clear cache: \(error)")
            successMessage = "Error clearing cache: \(error.localizedDescription)"
            showingSuccess = true
        }
    }
    
    private func resetCoreDataStores() {
        // Get URLs for the Core Data stores
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Better naming to match PersistenceController URLs
        let localStoreURL = documentsURL.appendingPathComponent("BasicScheduleCPreparation_local.sqlite")
        let sharedStoreURL = documentsURL.appendingPathComponent("BasicScheduleCPreparation_shared.sqlite")
        
        // Also handle the default name that might be used
        let defaultStoreURL = documentsURL.appendingPathComponent("BasicScheduleCPreparation.sqlite")
        
        var success = true
        var errorMessages: [String] = []
        
        // Try to delete the local store
        if fileManager.fileExists(atPath: localStoreURL.path) {
            do {
                try fileManager.removeItem(at: localStoreURL)
                print("Successfully deleted local store")
            } catch {
                success = false
                errorMessages.append("Failed to delete local store: \(error.localizedDescription)")
                print("Failed to delete local store: \(error)")
            }
        }
        
        // Try to delete the shared store
        if fileManager.fileExists(atPath: sharedStoreURL.path) {
            do {
                try fileManager.removeItem(at: sharedStoreURL)
                print("Successfully deleted shared store")
            } catch {
                success = false
                errorMessages.append("Failed to delete shared store: \(error.localizedDescription)")
                print("Failed to delete shared store: \(error)")
            }
        }
        
        // Try to delete the default store if it exists
        if fileManager.fileExists(atPath: defaultStoreURL.path) {
            do {
                try fileManager.removeItem(at: defaultStoreURL)
                print("Successfully deleted default store")
            } catch {
                success = false
                errorMessages.append("Failed to delete default store: \(error.localizedDescription)")
                print("Failed to delete default store: \(error)")
            }
        }
        
        // Delete related files (shm, wal, etc.)
        let suffixes = ["-shm", "-wal"]
        for suffix in suffixes {
            let localSuffixURL = documentsURL.appendingPathComponent("BasicScheduleCPreparation_local.sqlite\(suffix)")
            let sharedSuffixURL = documentsURL.appendingPathComponent("BasicScheduleCPreparation_shared.sqlite\(suffix)")
            let defaultSuffixURL = documentsURL.appendingPathComponent("BasicScheduleCPreparation.sqlite\(suffix)")
            
            try? fileManager.removeItem(at: localSuffixURL)
            try? fileManager.removeItem(at: sharedSuffixURL)
            try? fileManager.removeItem(at: defaultSuffixURL)
        }
        
        if success {
            successMessage = "Database reset successfully. The app will now restart."
            showingSuccess = true
            
            // Allow the success message to be shown before restarting
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // In a real app, prompt the user to restart manually
                // For development, we can force an exit
                exit(0)
            }
        } else {
            successMessage = "Database reset had errors: \(errorMessages.joined(separator: ", "))"
            showingSuccess = true
        }
    }
}

#if DEBUG
struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        UserProfileView()
    }
}
#endif
