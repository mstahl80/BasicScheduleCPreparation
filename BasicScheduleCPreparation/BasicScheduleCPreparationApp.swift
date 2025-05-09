// BasicScheduleCPreparationApp.swift
import SwiftUI

@main
struct BasicScheduleCPreparationApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authManager = UserAuthManager.shared
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                // Main app
                ScheduleListView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(authManager)
            } else {
                // Login screen
                LoginView()
            }
        }
    }
}
