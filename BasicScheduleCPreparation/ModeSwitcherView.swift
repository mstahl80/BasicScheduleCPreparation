// ModeSwitcherView.swift - Updated with CloudKit support
import SwiftUI

struct ModeSwitcherView: View {
    @EnvironmentObject var authManager: UserAuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingConfirmation = false
    @State private var wantToUseSharedData = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Data Storage Mode") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Use Shared Data", isOn: $wantToUseSharedData)
                            .onChange(of: wantToUseSharedData) { _, newValue in
                                if newValue != authManager.isUsingSharedData {
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
                
                Section("Current Mode") {
                    HStack {
                        Image(systemName: authManager.isUsingSharedData ? "cloud.fill" : "iphone")
                            .foregroundColor(authManager.isUsingSharedData ? .blue : .green)
                        
                        VStack(alignment: .leading) {
                            Text(authManager.isUsingSharedData ? "Shared Data" : "Standalone (Local)")
                                .font(.headline)
                            
                            Text(authManager.isUsingSharedData ?
                                "Your data is synced to iCloud and can be shared." :
                                "Your data is stored only on this device.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if !authManager.isUsingSharedData {
                    Section("Join Shared Data") {
                        NavigationLink(destination: EnterInvitationView()) {
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
                wantToUseSharedData = authManager.isUsingSharedData
            }
            .alert(wantToUseSharedData ? "Switch to Shared Mode?" : "Switch to Standalone Mode?", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) {
                    // Reset the toggle to the current value
                    wantToUseSharedData = authManager.isUsingSharedData
                }
                Button("Switch") {
                    if wantToUseSharedData {
                        // If user wants shared mode but doesn't have authentication,
                        // this will trigger the login screen
                        authManager.toggleDataSharingMode(useSharedData: true)
                    } else {
                        // Switch to standalone mode
                        authManager.toggleDataSharingMode(useSharedData: false)
                    }
                }
            } message: {
                Text(wantToUseSharedData ?
                    "Your data will be synchronized with iCloud. You'll need to sign in with your Apple ID." :
                    "Your data will be stored only on this device. Any shared data will no longer be accessible.")
            }
        }
    }
}

// View for entering an invitation code
struct EnterInvitationView: View {
    @EnvironmentObject var authManager: UserAuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var invitationCode = ""
    @State private var isValidating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        Form {
            Section("Enter Invitation Code") {
                TextField("Invitation Code", text: $invitationCode)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.characters)
                    .disableAutocorrection(true)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .onChange(of: invitationCode) { _, newValue in
                        invitationCode = newValue.uppercased()
                    }
                
                Button {
                    validateInvitationCode()
                } label: {
                    if isValidating {
                        ProgressView()
                    } else {
                        Text("Join Shared Data")
                    }
                }
                .disabled(invitationCode.count != 6 || isValidating)
            }
            
            Section("Information") {
                Text("Enter the 6-character invitation code that was shared with you to access shared data. You'll need to sign in with your Apple ID after entering a valid code.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Join Shared Data")
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func validateInvitationCode() {
        isValidating = true
        
        // First ensure the user is authenticated
        if !authManager.isAuthenticated {
            authManager.signInWithApple()
            isValidating = false
            return
        }
        
        // Then validate the code
        authManager.acceptInvitation(code: invitationCode) { success, message in
            isValidating = false
            
            if success {
                // Code accepted, navigate back
                dismiss()
            } else {
                errorMessage = message ?? "Invalid invitation code"
                showingError = true
            }
        }
    }
}

#if DEBUG
struct ModeSwitcherView_Previews: PreviewProvider {
    static var previews: some View {
        ModeSwitcherView()
            .environmentObject(UserAuthManager.shared)
    }
}
#endif
