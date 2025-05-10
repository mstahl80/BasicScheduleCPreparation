// LoginView.swift
import SwiftUI
import AuthenticationServices

struct LoginView: View {
    // Remove EnvironmentObject and use State instead
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var invitationCode = ""
    @State private var isValidatingCode = false
    @State private var showStandaloneConfirmation = false
    
    // Helper to check if user is using shared data
    private var isUsingSharedData: Bool {
        UserDefaults.standard.bool(forKey: "isUsingSharedData")
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // App logo and title
                Text("BasicScheduleCPreparation")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 50)
                
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.blue)
                    .padding()
                
                // Show different content based on whether shared mode is enabled
                if isUsingSharedData {
                    // Shared data mode - show login options
                    sharedDataLoginContent
                } else {
                    // Not in shared mode - show invitation entry
                    invitationContent
                }
                
                Spacer()
            }
            .padding()
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Use Standalone Mode?", isPresented: $showStandaloneConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Continue") {
                    toggleDataSharingMode(useShared: false)
                }
            } message: {
                Text("Your data will be stored locally on this device only and won't be shared with others.")
            }
            .onAppear {
                // Set up the context provider
                #if os(iOS)
                setupContextProvider()
                #endif
            }
        }
    }
    
    // Content to show when in shared data mode
    var sharedDataLoginContent: some View {
        VStack(spacing: 20) {
            Text("Sign in to access shared data")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding()
            
            Text("This data has been shared with you. Sign in with your Apple ID to access it.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            SignInWithAppleButton()
                .padding()
            
            Button("Use Standalone Mode Instead") {
                showStandaloneConfirmation = true
            }
            .padding()
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
    }
    
    // Content to show when entering an invitation code
    var invitationContent: some View {
        VStack(spacing: 20) {
            Text("Track your business expenses and income")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding()
            
            Spacer()
            
            // Section for entering invitation code
            VStack(alignment: .leading, spacing: 10) {
                Text("Have an invitation code?")
                    .font(.headline)
                
                HStack {
                    TextField("Enter Invitation Code", text: $invitationCode)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .disableAutocorrection(true)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .onChange(of: invitationCode) { _, newValue in
                            invitationCode = newValue.uppercased()
                        }
                    
                    Button(action: validateInvitationCode) {
                        if isValidatingCode {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Join")
                                .fontWeight(.bold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(invitationCode.count != 6 || isValidatingCode)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Standalone mode option
            Button {
                toggleDataSharingMode(useShared: false)
            } label: {
                HStack {
                    Image(systemName: "person")
                    Text("Continue in Standalone Mode")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(8)
            }
            .padding(.top)
        }
    }
    
    // Helper methods that don't require UserAuthManager type
    
    // Validate invitation code
    private func validateInvitationCode() {
        isValidatingCode = true
        
        // Check if authenticated using AuthAccess
        let isAuthenticated = isUserAuthenticated()
        if !isAuthenticated {
            // Sign in with Apple
            AuthAccess.signInWithApple()
            isValidatingCode = false
            return
        }
        
        // Accept invitation using CloudKit directly
        let code = invitationCode
        CloudKitManager.shared.acceptInvitation(code: code) { success, message in
            isValidatingCode = false
            
            if success {
                // Mark that we're using shared data
                UserDefaults.standard.set(true, forKey: "isUsingSharedData")
                
                // Switch to shared store
                PersistenceController.shared.switchToSharedStore()
                
                // Refresh user role
                refreshRole()
            } else {
                errorMessage = message ?? "Invalid invitation code. Please try again."
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
    
    // Helper to toggle data sharing mode
    private func toggleDataSharingMode(useShared: Bool) {
        UserDefaults.standard.set(useShared, forKey: "isUsingSharedData")
        
        if !useShared {
            PersistenceController.shared.switchToLocalStore()
        } else {
            PersistenceController.shared.switchToSharedStore()
        }
        
        // Force view update - using modern approach
        #if os(iOS)
        if #available(iOS 15.0, *) {
            // Use scene-based window access
            let activeScene = UIApplication.shared.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .first as? UIWindowScene
            
            activeScene?.keyWindow?.rootViewController?.setNeedsStatusBarAppearanceUpdate()
        } else {
            // Legacy approach
            UIApplication.shared.windows.first?.rootViewController?.setNeedsStatusBarAppearanceUpdate()
        }
        #endif
    }
    
    // Helper to refresh role
    private func refreshRole() {
        // Try to call refreshUserRole on the auth manager
        let authManager = AuthAccess.getAuthManager()
        
        if let authObj = authManager as? NSObject {
            let selector = NSSelectorFromString("refreshUserRole")
            if authObj.responds(to: selector) {
                authObj.perform(selector)
            }
        }
    }
    
    // Setup context provider
    #if os(iOS)
    private func setupContextProvider() {
        let authManager = AuthAccess.getAuthManager()
        
        if let authObj = authManager as? NSObject {
            let contextProvider = ContextProvider()
            let selector = NSSelectorFromString("setContextProvider:")
            if authObj.responds(to: selector) {
                _ = authObj.perform(selector, with: contextProvider)
            }
        }
    }
    #endif
}

#if os(iOS)
// Context provider for Sign in with Apple
class ContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Modern approach to get the window using windowScene
        if #available(iOS 15.0, *) {
            // Get the active window scene
            let activeScene = UIApplication.shared.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .first as? UIWindowScene
            
            // Get window from the active scene
            if let window = activeScene?.keyWindow ?? activeScene?.windows.first {
                return window
            }
        }
        
        // Fallback for older iOS versions
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first ?? UIWindow()
    }
}
#endif

// Preview provider
#if DEBUG
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
#endif
