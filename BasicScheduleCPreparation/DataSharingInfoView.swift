// DataSharingInfoView.swift - Complete file with standalone mode default support
import SwiftUI

struct DataSharingInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showEnableSharedDataConfirmation = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title and intro
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Data Sharing with CloudKit")
                            .font(.title)
                            .bold()
                        
                        Text("BasicScheduleCPreparation can work in standalone mode or with data sharing enabled.")
                            .font(.headline)
                    }
                    .padding(.bottom)
                    
                    // Standalone mode section
                    sectionCard(
                        title: "Standalone Mode",
                        icon: "iphone",
                        iconColor: .green,
                        content: standaloneContent
                    )
                    
                    // Shared mode section
                    sectionCard(
                        title: "Shared Data Mode",
                        icon: "cloud.fill",
                        iconColor: .blue,
                        content: sharedContent
                    )
                    
                    // Authentication flow section
                    sectionCard(
                        title: "Apple ID Authentication",
                        icon: "person.fill.badge.plus",
                        iconColor: .blue,
                        content: authenticationContent
                    )
                    
                    // Admin access section
                    sectionCard(
                        title: "Administrator Access",
                        icon: "key.fill",
                        iconColor: .purple,
                        content: adminContent
                    )
                    
                    // How to enable section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("How to Enable Data Sharing")
                            .font(.headline)
                        
                        Text("You can enable data sharing at any time from your User Profile:")
                            .font(.subheadline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("1")
                                    .font(.caption)
                                    .padding(5)
                                    .background(Circle().fill(Color.blue))
                                    .foregroundColor(.white)
                                
                                Text("Go to User Profile")
                                    .font(.subheadline)
                            }
                            
                            HStack {
                                Text("2")
                                    .font(.caption)
                                    .padding(5)
                                    .background(Circle().fill(Color.blue))
                                    .foregroundColor(.white)
                                
                                Text("Tap \"Enable Data Sharing\"")
                                    .font(.subheadline)
                            }
                            
                            HStack {
                                Text("3")
                                    .font(.caption)
                                    .padding(5)
                                    .background(Circle().fill(Color.blue))
                                    .foregroundColor(.white)
                                
                                Text("Sign in with your Apple ID")
                                    .font(.subheadline)
                            }
                            
                            HStack {
                                Text("4")
                                    .font(.caption)
                                    .padding(5)
                                    .background(Circle().fill(Color.blue))
                                    .foregroundColor(.white)
                                
                                Text("Set up as administrator (optional)")
                                    .font(.subheadline)
                            }
                        }
                        .padding(.leading, 5)
                        
                        Button {
                            showEnableSharedDataConfirmation = true
                        } label: {
                            Text("Enable Data Sharing Now")
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.top)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Data Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Enable Data Sharing?", isPresented: $showEnableSharedDataConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Enable") {
                    // Mark that we're explicitly setting the mode
                    UserDefaults.standard.set(true, forKey: "modeWasExplicitlySet")
                    
                    // Enable shared mode
                    toggleDataSharingMode(useShared: true)
                    
                    // Return to the User Profile
                    dismiss()
                }
            } message: {
                Text("Data sharing allows you to synchronize your data across devices and share with others. You'll need to sign in with your Apple ID. Would you like to enable this feature?")
            }
        }
    }
    
    // MARK: - Content Sections
    
    private var standaloneContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This is the default mode when you first install the app.")
                .font(.subheadline)
            
            bulletPoint("Your data stays on this device only")
            bulletPoint("No Apple ID or sign-in required")
            bulletPoint("Faster initial setup")
            bulletPoint("Perfect for individual use")
            bulletPoint("Data is not backed up to iCloud")
            
            Text("In standalone mode, you cannot share data with others or sync across devices.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 5)
        }
    }
    
    private var sharedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Optional mode that enables data sharing and collaboration.")
                .font(.subheadline)
            
            bulletPoint("Synchronize data across all your Apple devices")
            bulletPoint("Share data with team members or colleagues")
            bulletPoint("Data is backed up to iCloud")
            bulletPoint("Control who has access to your data")
            bulletPoint("Requires Apple ID authentication")
            
            Text("Shared mode uses Apple's CloudKit service to securely store and manage your data.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 5)
        }
    }
    
    private var authenticationContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("When using shared data mode, all users authenticate with their Apple ID.")
                .font(.subheadline)
            
            bulletPoint("Secure authentication through Apple")
            bulletPoint("No additional passwords to remember")
            bulletPoint("Privacy-focused approach")
            bulletPoint("Sign in once, automatic thereafter")
            
            Text("Your Apple ID is only used for authentication and is not shared with other users.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 5)
        }
    }
    
    private var adminContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Administrator access provides additional control over shared data.")
                .font(.subheadline)
            
            bulletPoint("The first user to set up shared data becomes the admin")
            bulletPoint("Administrators can invite other users")
            bulletPoint("Control permission levels for each user")
            bulletPoint("Assign Editor or Viewer roles to others")
            bulletPoint("Revoke access when needed")
            
            Text("You can set up administrator access after enabling shared data mode.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 5)
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionCard(title: String, icon: String, iconColor: Color, content: some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.headline)
            }
            
            content
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top) {
            Text("•")
                .foregroundColor(.secondary)
            
            Text(text)
                .font(.subheadline)
        }
    }
    
    // MARK: - Helper Methods
    
    private func toggleDataSharingMode(useShared: Bool) {
        UserDefaults.standard.set(useShared, forKey: "isUsingSharedData")
        
        // Mark that mode was explicitly set by user
        UserDefaults.standard.set(true, forKey: "modeWasExplicitlySet")
        
        if useShared {
            PersistenceController.shared.switchToSharedStore()
        } else {
            PersistenceController.shared.switchToLocalStore()
        }
        
        // Notify about the change
        NotificationCenter.default.post(name: Notification.Name("DataSharingModeChanged"), object: nil)
    }
}

#if DEBUG
struct DataSharingInfoView_Previews: PreviewProvider {
    static var previews: some View {
        DataSharingInfoView()
    }
}
#endif
