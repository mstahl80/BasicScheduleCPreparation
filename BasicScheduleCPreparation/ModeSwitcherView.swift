// ModeSwitcherView.swift
import SwiftUI

struct ModeSwitcherView: View {
    // Replace EnvironmentObject with State
    @Environment(\.dismiss) private var dismiss
    @State private var showingConfirmation = false
    @State private var wantToUseSharedData = false
    
    // Current state of shared data mode
    private var isUsingSharedData: Bool {
        UserDefaults.standard.bool(forKey: "isUsingSharedData")
    }
    
    // Check if user is admin
    private var isAdmin: Bool {
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
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Data Storage Mode") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Use Shared Data", isOn: $wantToUseSharedData)
                            .onChange(of: wantToUseSharedData) { _, newValue in
                                if newValue != isUsingSharedData {
                                    showingConfirmation = true
                                }
                            }
                        
                        Text(wantToUseSharedData ?
                            "Your data will be stored in iCloud and can be shared with others." :
                            "Your data will be stored only on this device and won't be shared.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Add info about admin setup
                if wantToUseSharedData && !isAdmin {
                    Section("Administrator Setup") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("To invite others, you'll need administrator privileges")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("You can set up as an administrator in your User Profile after enabling shared data.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Current Mode") {
                    HStack {
                        Image(systemName: isUsingSharedData ? "cloud.fill" : "iphone")
                            .foregroundColor(isUsingSharedData ? .blue : .green)
                        
                        VStack(alignment: .leading) {
                            Text(isUsingSharedData ? "Shared Data" : "Standalone (Local)")
                                .font(.headline)
                            
                            Text(isUsingSharedData ?
                                "Your data is synced to iCloud and can be shared." :
                                "Your data is stored only on this device.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !isUsingSharedData {
                    Section("Join Shared Data") {
                        NavigationLink(destination: SimpleInvitationView()) {
                            HStack {
                                Image(systemName: "person.badge.key")
                                Text("Enter Invitation Code")
                            }
                        }
                    }
                }
                
                Section("Information") {
                    Text("Switching to shared mode requires an Apple ID and allows you to share data between your devices and with other users. Your data will be stored in iCloud.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                    
                    Text("Switching to standalone mode keeps all data on this device only, with no sync or sharing capabilities.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            }
            .navigationTitle("Data Mode")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Initialize the toggle with the current value
                wantToUseSharedData = isUsingSharedData
            }
            .alert(wantToUseSharedData ? "Switch to Shared Mode?" : "Switch to Standalone Mode?", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) {
                    // Reset the toggle to the current value
                    wantToUseSharedData = isUsingSharedData
                }
                Button("Switch") {
                    toggleDataSharingMode(useShared: wantToUseSharedData)
                }
            } message: {
                Text(wantToUseSharedData ?
                    "Your data will be synchronized with iCloud. You'll need to sign in with your Apple ID." :
                    "Your data will be stored only on this device. Any shared data will no longer be accessible.")
            }
        }
    }
    
    // Helper to toggle data sharing mode
    private func toggleDataSharingMode(useShared: Bool) {
        // Update UserDefaults
        UserDefaults.standard.set(useShared, forKey: "isUsingSharedData")
        
        if useShared {
            // Check if authenticated
            let isAuthenticated = isUserAuthenticated()
            if !isAuthenticated {
                // Need to sign in
                AuthAccess.signInWithApple()
            }
            
            // Switch to shared store
            PersistenceController.shared.switchToSharedStore()
        } else {
            // Switch to local store
            PersistenceController.shared.switchToLocalStore()
        }
        
        // Force UI update
        wantToUseSharedData = useShared
        
        // Notify about data mode change
        NotificationCenter.default.post(name: Notification.Name("DataSharingModeChanged"), object: nil)
    }
    
    // Helper to check if user is authenticated
    private func isUserAuthenticated() -> Bool {
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
}

// Simplified invitation view that doesn't depend on UserAuthManager
struct SimpleInvitationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var invitationCode = ""
    @State private var isValidating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Code entry
                VStack(alignment: .leading, spacing: 10) {
                    Text("Invitation Code")
                        .font(.headline)
                    
                    HStack {
                        TextField("Enter 6-character code", text: $invitationCode)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.characters)
                            .disableAutocorrection(true)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .onChange(of: invitationCode) { _, newValue in
                                invitationCode = newValue.uppercased()
                            }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Submit button
                Button {
                    validateInvitationCode()
                } label: {
                    if isValidating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Join Shared Data")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .disabled(invitationCode.count != 6 || isValidating)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 60)
            .navigationTitle("Join Shared Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func validateInvitationCode() {
        isValidating = true
        
        // Check if authenticated
        let isAuthenticated = isUserAuthenticated()
        if !isAuthenticated {
            // Sign in with Apple
            AuthAccess.signInWithApple()
            isValidating = false
            return
        }
        
        // Accept invitation using CloudKit directly
        CloudKitManager.shared.acceptInvitation(code: invitationCode) { success, message in
            isValidating = false
            
            if success {
                // Mark that we're using shared data
                UserDefaults.standard.set(true, forKey: "isUsingSharedData")
                
                // Switch to shared store
                PersistenceController.shared.switchToSharedStore()
                
                // Successfully joined, dismiss the sheet
                dismiss()
            } else {
                errorMessage = message ?? "Invalid invitation code"
                showingError = true
            }
        }
    }
    
    // Helper to check if user is authenticated
    private func isUserAuthenticated() -> Bool {
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
}

// Preview provider
#if DEBUG
struct ModeSwitcherView_Previews: PreviewProvider {
    static var previews: some View {
        ModeSwitcherView()
    }
}
#endif
