// UserProfileView.swift
import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject var authManager: UserAuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingSignOutConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // User Information Section
                Section("Account Information") {
                    if authManager.isUsingSharedData {
                        // Only show user details in shared mode with authentication
                        if let user = authManager.currentUser {
                            LabeledContent("Name", value: user.displayName)
                            
                            if let email = user.email {
                                LabeledContent("Email", value: email)
                            }
                        }
                    } else {
                        // In standalone mode, show device info
                        #if os(iOS)
                        LabeledContent("Device", value: UIDevice.current.name)
                        #elseif os(macOS)
                        LabeledContent("Device", value: Host.current().localizedName ?? "Mac")
                        #endif
                    }
                    
                    // Show current data mode
                    HStack {
                        Image(systemName: authManager.isUsingSharedData ? "cloud.fill" : "iphone")
                            .foregroundColor(authManager.isUsingSharedData ? .blue : .green)
                        Text(authManager.isUsingSharedData ? "Using Shared Data" : "Using Local Data")
                    }
                }
                
                // Data Mode Section
                Section("Data Management") {
                    NavigationLink(destination: ModeSwitcherView()) {
                        HStack {
                            Image(systemName: "arrow.triangle.swap")
                            Text("Change Data Mode")
                        }
                    }
                    
                    // Only show share option in shared mode
                    if authManager.isUsingSharedData {
                        NavigationLink(destination: ShareDataView()) {
                            HStack {
                                Image(systemName: "person.2.fill")
                                Text("Invite Others")
                            }
                        }
                    }
                }
                
                // Only show sign out in shared mode with authentication
                if authManager.isUsingSharedData && authManager.isAuthenticated {
                    Section {
                        Button(role: .destructive) {
                            showingSignOutConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                        }
                    }
                }
            }
            .navigationTitle("User Profile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Sign Out?", isPresented: $showingSignOutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out? You'll need to sign in again to access your shared data.")
            }
        }
    }
}

#if DEBUG
struct UserProfileView_Previews: PreviewProvider {
    static var previews: some View {
        UserProfileView()
            .environmentObject(UserAuthManager.shared)
    }
}
#endif
