// LoginView.swift
import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: UserAuthManager
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var invitationCode = ""
    @State private var isValidatingCode = false
    @State private var showStandaloneConfirmation = false
    
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
                if authManager.isUsingSharedData {
                    // Shared data mode - show login options
                    sharedDataLoginContent
                } else {
                    // Not in shared mode - show invitation entry
                    invitationContent
                }
                
                Spacer()
            }
            .padding()
            .onReceive(authManager.$authError.compactMap { $0 }) { error in
                errorMessage = error.localizedDescription
                showingError = true
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Use Standalone Mode?", isPresented: $showStandaloneConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Continue") {
                    authManager.toggleDataSharingMode(useSharedData: false)
                }
            } message: {
                Text("Your data will be stored locally on this device only and won't be shared with others.")
            }
            .onAppear {
                // Set up the context provider
                #if os(iOS)
                authManager.setContextProvider(ContextProvider())
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
                authManager.toggleDataSharingMode(useSharedData: false)
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
    
    // Validate invitation code
    private func validateInvitationCode() {
        isValidatingCode = true
        
        authManager.acceptInvitation(code: invitationCode) { success, message in
            isValidatingCode = false
            
            if !success {
                errorMessage = message ?? "Invalid invitation code. Please try again."
                showingError = true
            }
            // If successful, the authManager would have already updated isUsingSharedData
            // which will trigger the UI to update accordingly
        }
    }
}

#if os(iOS)
// Context provider for Sign in with Apple
class ContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first ?? UIWindow()
    }
}
#endif
