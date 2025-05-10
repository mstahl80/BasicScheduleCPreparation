// BasicScheduleCPreparationApp.swift
import SwiftUI

@main
struct BasicScheduleCPreparationApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authManager = UserAuthManager.shared
    @State private var databaseReady = false
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main app content
                if databaseReady {
                    mainContent
                } else {
                    // Loading screen while database initializes
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Initializing database...")
                            .padding()
                    }
                }
            }
            .onAppear {
                // Give Core Data a moment to initialize
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    databaseReady = true
                }
            }
        }
    }
    
    // Main content based on auth state and data sharing mode
    @ViewBuilder
    var mainContent: some View {
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
