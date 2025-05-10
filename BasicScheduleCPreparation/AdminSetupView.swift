// AdminSetupView.swift
import SwiftUI

struct AdminSetupView: View {
    // Remove EnvironmentObject and use State instead
    @Environment(\.dismiss) private var dismiss
    @State private var adminCode = ""
    @State private var isProcessing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var setupComplete = false
    @State private var showingSuccess = false
    
    // This should be a code only the intended admin knows
    private let ADMIN_SETUP_CODE = "ADMIN-5791"
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {
                Text("Administrator Setup")
                    .font(.title)
                    .bold()
                
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 70))
                    .foregroundColor(.blue)
                    .padding()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Enter the administrator verification code")
                        .font(.headline)
                    
                    Text("This code is required to set up an administrator account.")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        
                    SecureField("Admin Code", text: $adminCode)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(.top, 5)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Button {
                    verifyAndSetupAdmin()
                } label: {
                    if isProcessing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Verify and Setup")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .disabled(adminCode.isEmpty || isProcessing)
                .padding(.horizontal)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Administrator Capabilities:")
                        .font(.subheadline)
                        .bold()
                    
                    HStack(alignment: .top) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Invite others to join")
                            .font(.caption)
                    }
                    
                    HStack(alignment: .top) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Manage user permissions")
                            .font(.caption)
                    }
                    
                    HStack(alignment: .top) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Revoke access when needed")
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
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
        }
    }
    
    private func verifyAndSetupAdmin() {
        isProcessing = true
        
        if adminCode.trimmingCharacters(in: .whitespacesAndNewlines) == ADMIN_SETUP_CODE {
            // First ensure we're using shared storage
            if !isUsingSharedData() {
                toggleDataSharingMode(useShared: true)
            }
            
            // Then make user admin
            makeCurrentUserAdmin { success, error in
                isProcessing = false
                
                if success {
                    // Update the user role
                    refreshUserRole()
                    showingSuccess = true
                } else {
                    errorMessage = error ?? "Failed to set up admin account"
                    showError = true
                }
            }
        } else {
            isProcessing = false
            errorMessage = "Invalid admin code"
            showError = true
        }
    }
    
    // Helper to check if shared data is enabled
    private func isUsingSharedData() -> Bool {
        return UserDefaults.standard.bool(forKey: "isUsingSharedData")
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
    
    // Make current user admin
    private func makeCurrentUserAdmin(completion: @escaping (Bool, String?) -> Void) {
        CloudKitManager.shared.makeCurrentUserAdmin(completion: completion)
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
}

#if DEBUG
struct AdminSetupView_Previews: PreviewProvider {
    static var previews: some View {
        AdminSetupView()
    }
}
#endif
