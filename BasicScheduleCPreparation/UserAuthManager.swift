// Updated UserAuthManager implementation for better Sign in with Apple handling
import Foundation
import AuthenticationServices
import SwiftUI

class UserAuthManager: NSObject, ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var authError: Error?
    
    static let shared = UserAuthManager()
    
    // User model - Codable for persistence
    struct User: Identifiable, Codable {
        let id: String // Apple ID
        let firstName: String?
        let lastName: String?
        let email: String?
        
        var displayName: String {
            if let firstName = firstName, let lastName = lastName {
                return "\(firstName) \(lastName)"
            } else if let firstName = firstName {
                return firstName
            } else if let lastName = lastName {
                return lastName
            } else {
                return "User-\(id.prefix(6))"
            }
        }
    }
    
    // Store the presentation context provider for later use
    private weak var contextProvider: ASAuthorizationControllerPresentationContextProviding?
    
    private override init() {
        super.init()
        // Check for existing user in UserDefaults
        checkExistingAuth()
    }
    
    private func checkExistingAuth() {
        // Try to load saved credentials
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    // Set context provider for proper presentation
    func setContextProvider(_ provider: ASAuthorizationControllerPresentationContextProviding) {
        self.contextProvider = provider
    }
    
    func signInWithApple() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        
        // Use context provider if available, otherwise use a default
        #if os(iOS)
        if let contextProvider = self.contextProvider {
            controller.presentationContextProvider = contextProvider
        } else {
            // Create a temporary context provider
            let tempProvider = TemporaryPresentationContextProvider()
            controller.presentationContextProvider = tempProvider
        }
        #endif
        
        controller.performRequests()
    }
    
    func signOut() {
        UserDefaults.standard.removeObject(forKey: "currentUser")
        self.currentUser = nil
        self.isAuthenticated = false
        
        // Notify any listeners that the user has changed
        NotificationCenter.default.post(name: Notification.Name("UserDidChange"), object: nil)
    }
}

// Temporary presentation context provider for iOS
#if os(iOS)
class TemporaryPresentationContextProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first ?? UIWindow()
    }
}
#endif

// MARK: - ASAuthorizationControllerDelegate
extension UserAuthManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userId = appleIDCredential.user
            let firstName = appleIDCredential.fullName?.givenName
            let lastName = appleIDCredential.fullName?.familyName
            let email = appleIDCredential.email
            
            print("Successfully authenticated with Apple ID: \(userId)")
            if let email = email {
                print("Email: \(email)")
            }
            
            let user = User(id: userId, firstName: firstName, lastName: lastName, email: email)
            
            // Save user
            if let encoded = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(encoded, forKey: "currentUser")
            }
            
            DispatchQueue.main.async {
                self.currentUser = user
                self.isAuthenticated = true
                
                // Notify any listeners that the user has changed
                NotificationCenter.default.post(name: Notification.Name("UserDidChange"), object: nil)
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Authorization error: \(error.localizedDescription)")
        if let authError = error as? ASAuthorizationError {
            print("ASAuthorizationError code: \(authError.code.rawValue)")
        }
        
        DispatchQueue.main.async {
            self.authError = error
        }
    }
}
