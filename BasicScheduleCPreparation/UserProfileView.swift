// UserProfileView.swift
import SwiftUI

struct UserProfileView: View {
    @EnvironmentObject var authManager: UserAuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingSignOutConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Account Information") {
                    if let user = authManager.currentUser {
                        LabeledContent("Name", value: user.displayName)
                        
                        if let email = user.email {
                            LabeledContent("Email", value: email)
                        }
                    }
                }
                
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
                Text("Are you sure you want to sign out? You'll need to sign in again to access your data.")
            }
        }
    }
}
