// UserProfileView.swift
import SwiftUI
import CloudKit

struct UserProfileView: View {
    // Fix the environment object declaration - make sure UserAuthManager is in scope
    @EnvironmentObject var authManager: UserAuthManager
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
                    if authManager.isUsingSharedData {
                        // Only show user details in shared mode with authentication
                        if let user = authManager.currentUser {
                            LabeledContent("Name", value: user.displayName)
                            
                            if let email = user.email {
                                LabeledContent("Email", value: email)
                            }
                            
                            if let role = authManager.userRole {
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
                        Image(systemName: authManager.isUsingSharedData ? "cloud.fill" : "iphone")
                            .foregroundColor(authManager.isUsingSharedData ? .blue : .green)
                        Text(authManager.isUsingSharedData ? "Using Shared Data" : "Using Local Data")
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
                    if authManager.isUsingSharedData {
                        if authManager.isAdmin() {
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
                    if authManager.isAdmin() {
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
                    if !authManager.isAdmin() {
                        Text("Administrators can invite other users and manage access to shared data.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Only show sign out in shared mode with authentication
                if authManager.isUsingSharedData && authManager.isAuthenticated {
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
                        LabeledContent("Data Mode", value: authManager.isUsingSharedData ? "Shared (CloudKit)" : "Standalone (Local)")
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
                    authManager.signOut()
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
                    .environmentObject(authManager)
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
            .environmentObject(UserAuthManager.shared)
    }
}
#endif
