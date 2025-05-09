// Updated LoginView with proper context provider setup
import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var authManager = UserAuthManager.shared
    @State private var showingError = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("BasicScheduleCPreparation")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 50)
            
            Image(systemName: "doc.text.fill")
                .font(.system(size: 100))
                .foregroundColor(.blue)
                .padding()
            
            Text("Track your business expenses and income")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding()
            
            Text("Sign in with your Apple ID to securely access your data across devices")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer()
            
            SignInWithAppleButton()
                .padding()
                .alert(isPresented: $showingError) {
                    Alert(
                        title: Text("Authentication Error"),
                        message: Text(authManager.authError?.localizedDescription ?? "Unknown error"),
                        dismissButton: .default(Text("OK")) {
                            authManager.authError = nil
                        }
                    )
                }
            
            // Alternative login option
            Button("Skip Sign In (Use Device ID)") {
                loginWithDeviceId()
            }
            .padding()
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
        .onReceive(authManager.$authError.compactMap { $0 }) { _ in
            showingError = true
        }
        .onAppear {
            // Set up the context provider
            #if os(iOS)
            authManager.setContextProvider(ContextProvider())
            #endif
        }
    }
    
    private func loginWithDeviceId() {
        #if os(iOS)
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let deviceName = UIDevice.current.name
        #elseif os(macOS)
        let deviceId = UUID().uuidString
        let deviceName = Host.current().localizedName ?? "Mac User"
        #else
        let deviceId = UUID().uuidString
        let deviceName = "Unknown Device"
        #endif
        
        let user = UserAuthManager.User(
            id: deviceId,
            firstName: deviceName,
            lastName: nil,
            email: nil
        )
        
        // Save user
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "currentUser")
        }
        
        DispatchQueue.main.async {
            authManager.currentUser = user
            authManager.isAuthenticated = true
            
            // Notify any listeners that the user has changed
            NotificationCenter.default.post(name: Notification.Name("UserDidChange"), object: nil)
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
