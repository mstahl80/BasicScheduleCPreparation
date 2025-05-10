// AuthAccess.swift
import Foundation
import SwiftUI

// This provides global access to the auth manager without requiring the exact type
class AuthAccess {
    // Static property holding the shared auth manager without specifying its type
    static let authManager: Any = {
        // Try to find the class directly in the module
        let moduleClassName = "BasicScheduleCPreparation.UserAuthManager"
        let fallbackClassName = "UserAuthManager"
        
        // Get the class using NSClassFromString - explicitly handle optionals
        if let authManagerClass = NSClassFromString(moduleClassName) {
            return getSharedInstance(from: authManagerClass)
        } else if let authManagerClass = NSClassFromString(fallbackClassName) {
            return getSharedInstance(from: authManagerClass)
        }
        
        // Fallback in case we can't find the class
        print("⚠️ WARNING: Could not find UserAuthManager class")
        return NSObject()
    }()
    
    // Helper function to get shared instance from a class
    private static func getSharedInstance(from classType: AnyClass) -> Any {
        // Try to access the 'shared' property
        if let objectType = classType as? NSObject.Type {
            if let sharedInstance = objectType.value(forKey: "shared") {
                return sharedInstance
            } else {
                // Try to create a new instance if shared is not available
                return objectType.init()
            }
        }
        return NSObject()
    }
    
    // Helper method to get the auth manager instance
    static func getAuthManager() -> Any {
        return authManager
    }
    
    // Helper for sign in with Apple
    static func signInWithApple() {
        let targetObject = authManager as? NSObject
        let selector = NSSelectorFromString("signInWithApple")
        
        if let targetObject = targetObject, targetObject.responds(to: selector) {
            targetObject.perform(selector)
        } else {
            print("Error: Cannot perform signInWithApple")
        }
    }
}
