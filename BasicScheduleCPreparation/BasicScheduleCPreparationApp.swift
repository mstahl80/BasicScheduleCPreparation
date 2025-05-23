// BasicScheduleCPreparationApp.swift - Complete file with standalone mode default
import SwiftUI

@main
struct BasicScheduleCPreparationApp: App {
    let persistenceController = PersistenceController.shared
    
    // Remove StateObject for UserAuthManager
    @State private var databaseReady = false
    @State private var showWelcomeScreen = false
    
    init() {
        // Check if this is first launch by looking for a specific key
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        
        // For first launch, show welcome screen and default to standalone mode
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            showWelcomeScreen = true
            
            // Explicitly set to standalone mode (false = local data)
            UserDefaults.standard.set(false, forKey: "isUsingSharedData")
            UserDefaults.standard.set(true, forKey: "modeWasExplicitlySet")
        }
    }
    
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
                    if showWelcomeScreen {
                        // Show welcome screen for first launch
                        WelcomeView(onComplete: {
                            showWelcomeScreen = false
                        })
                    } else {
                        mainContent
                    }
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
