// UserAuthManager.swift
import Foundation
import AuthenticationServices
import SwiftUI

class UserAuthManager: NSObject, ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isUsingSharedData = false
    @Published var authError: Error?
    @Published var invitationCode: String = ""
    
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
        // Check for existing authentication and mode
        checkExistingAuth()
        checkDataSharingMode()
    }
    
    private func checkExistingAuth() {
        // Try to load saved credentials
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    private func checkDataSharingMode() {
        // Check if user has previously opted into shared data mode
        self.isUsingSharedData = UserDefaults.standard.bool(forKey: "isUsingSharedData")
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
    
    // Toggle between standalone and shared data modes
    func toggleDataSharingMode(useSharedData: Bool) {
        self.isUsingSharedData = useSharedData
        UserDefaults.standard.set(useSharedData, forKey: "isUsingSharedData")
        
        // If turning off shared mode, make sure we're using the local store
        if !useSharedData {
            PersistenceController.shared.switchToLocalStore()
        } else {
            // If turning on shared mode, we need authentication
            // We'll handle the container switch after authentication
            if !isAuthenticated {
                // We'll show the login screen in the app's body
                // The shared container will be activated after successful login
            } else {
                // Already authenticated, switch to shared store
                PersistenceController.shared.switchToSharedStore()
            }
        }
        
        // Notify system of changes
        NotificationCenter.default.post(name: Notification.Name("DataSharingModeChanged"), object: nil)
    }
    
    // Accept an invitation to access shared data
    func acceptInvitation(code: String, completion: @escaping (Bool, String?) -> Void) {
        // Validate invitation code
        PersistenceController.shared.validateInvitationCode(code) { success, message in
            if success {
                // Enable shared data mode
                self.toggleDataSharingMode(useSharedData: true)
                
                // Store the invitation code
                UserDefaults.standard.set(code, forKey: "acceptedInvitationCode")
                
                // If not already authenticated, the UI will show the login screen
                // Otherwise, we're good to go
                if self.isAuthenticated {
                    PersistenceController.shared.switchToSharedStore()
                }
            }
            
            completion(success, message)
        }
    }
    
    // Get the current user ID (or a device ID for standalone mode)
    func getCurrentUserId() -> String {
        if let user = currentUser {
            return user.id
        } else {
            // Use device ID for standalone mode
            #if os(iOS)
            return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            #elseif os(macOS)
            return ProcessInfo.processInfo.globallyUniqueString
            #else
            return UUID().uuidString
            #endif
        }
    }
    
    // Get user display name for history records
    func getCurrentUserDisplayName() -> String {
        if let user = currentUser {
            return user.displayName
        } else {
            // Use device name for standalone mode
            #if os(iOS)
            return UIDevice.current.name
            #elseif os(macOS)
            return Host.current().localizedName ?? "Mac User"
            #else
            return "Unknown User"
            #endif
        }
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
                
                // If using shared data, switch to shared store
                if self.isUsingSharedData {
                    PersistenceController.shared.switchToSharedStore()
                }
                
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
