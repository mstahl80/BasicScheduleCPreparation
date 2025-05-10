// BasicScheduleCPreparationApp.swift
import SwiftUI

@main
struct BasicScheduleCPreparationApp: App {
    let persistenceController = PersistenceController.shared
    // Remove StateObject for UserAuthManager
    @State private var databaseReady = false
    
    // Track auth state using UserDefaults
    private var isAuthenticated: Bool {
        UserDefaults.standard.bool(forKey: "isAuthenticated")
    }
    
    private var isUsingSharedData: Bool {
        UserDefaults.standard.bool(forKey: "isUsingSharedData")
    }
    
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
        if isUsingSharedData {
            // For shared data access, require authentication
            if isAuthenticated {
                // Authenticated main app with shared data
                ScheduleListView()
                    .environment(\.managedObjectContext, persistenceController.sharedContainer.viewContext)
            } else {
                // Login screen for shared data access
                LoginView()
            }
        } else {
            // Standalone mode - go straight to app with local data
            ScheduleListView()
                .environment(\.managedObjectContext, persistenceController.localContainer.viewContext)
        }
    }
}
