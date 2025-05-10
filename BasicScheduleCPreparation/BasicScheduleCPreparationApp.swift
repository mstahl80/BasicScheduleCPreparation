// BasicScheduleCPreparationApp.swift
import SwiftUI

@main
struct BasicScheduleCPreparationApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authManager = UserAuthManager.shared
    
    var body: some Scene {
        WindowGroup {
            // Check if we're using a shared or standalone mode
            if authManager.isUsingSharedData {
                // For shared data access, require authentication
                if authManager.isAuthenticated {
                    // Authenticated main app with shared data
                    ScheduleListView()
                        .environment(\.managedObjectContext, persistenceController.sharedContainer.viewContext)
                        .environmentObject(authManager)
                } else {
                    // Login screen for shared data access
                    LoginView()
                        .environmentObject(authManager)
                }
            } else {
                // Standalone mode - go straight to app with local data
                ScheduleListView()
                    .environment(\.managedObjectContext, persistenceController.localContainer.viewContext)
                    .environmentObject(authManager)
            }
        }
    }
}
