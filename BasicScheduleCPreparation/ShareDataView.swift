// ShareDataView.swift
import SwiftUI
import CloudKit
#if os(iOS)
import UIKit
#endif

struct ShareDataView: View {
    @StateObject private var cloudKitManager = CloudKitManager.shared
    // Use StateObject instead of EnvironmentObject to avoid type issues
    @State private var email = ""
    @State private var isGeneratingCode = false
    @State private var generatedCode: String? = nil
    @State private var errorMessage: String? = nil
    @State private var showSuccessAlert = false
    @State private var showShareSheet = false
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRole: CloudKitManager.UserPermissionRecord.UserRole = .editor
    
    // Create a state object to hold the sharing delegate
    #if os(iOS)
    @StateObject private var sharingDelegate = SharingDelegate()
    #endif
    
    // Helper to check if the current user is admin
    private var isAdmin: Bool {
        // Use reflection to access isAdmin without direct type reference
        let authManager = AuthAccess.getAuthManager()
        if let authObj = authManager as? NSObject {
            let selector = NSSelectorFromString("isAdmin")
            if authObj.responds(to: selector) {
                let result = authObj.perform(selector)
                if let boolValue = result?.takeUnretainedValue() as? Bool {
                    return boolValue
                }
            }
        }
        return false  // Default to false if we can't determine
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Generate Invitation Code") {
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                    
                    // Add role selector
                    Picker("User Role", selection: $selectedRole) {
                        Text("Viewer (Read-only)").tag(CloudKitManager.UserPermissionRecord.UserRole.viewer)
                        Text("Editor (Can modify)").tag(CloudKitManager.UserPermissionRecord.UserRole.editor)
                        
                        // Only show admin option if current user is admin
                        if isAdmin {
                            Text("Administrator (Full control)").tag(CloudKitManager.UserPermissionRecord.UserRole.admin)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Role Permissions:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Group {
                            Text("• Viewer: Can view data but not make changes")
                            Text("• Editor: Can view and edit all data")
                            if isAdmin {
                                Text("• Admin: Can manage users and all data")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                    
                    Button {
                        generateInvitationCode()
                    } label: {
                        if isGeneratingCode {
                            ProgressView()
                        } else {
                            Text("Generate Code")
                        }
                    }
                    .disabled(email.isEmpty || isGeneratingCode)
                }
                
                if let code = generatedCode {
                    Section("Invitation Code") {
                        VStack(alignment: .center, spacing: 12) {
                            Text("Share this code with your recipient:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(code)
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            
                            HStack {
                                Button {
                                    // Copy to clipboard
                                    #if os(iOS)
                                    UIPasteboard.general.string = code
                                    showSuccessAlert = true
                                    #elseif os(macOS)
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(code, forType: .string)
                                    showSuccessAlert = true
                                    #endif
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .buttonStyle(.borderless)
                                
                                #if os(iOS)
                                Button {
                                    showShareSheet = true
                                } label: {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                .buttonStyle(.borderless)
                                #endif
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    
                    #if os(iOS)
                    Section("Share via CloudKit") {
                        Button {
                            setupCloudKitShare()
                        } label: {
                            HStack {
                                Image(systemName: "person.2.badge.gearshape")
                                Text("Share via CloudKit")
                            }
                        }
                        
                        Text("Share your data directly with another iCloud user. They'll receive a notification in iCloud.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    #endif
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.callout)
                    }
                }
                
                Section("Information") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("The invited user will need to enter this code when they first launch the app. They will need to have this app installed and an Apple ID to access your shared data.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if selectedRole == .admin {
                            Text("⚠️ You are granting ADMIN privileges. This user will be able to invite others and manage all users.")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .bold()
                        }
                    }
                }
            }
            .navigationTitle("Share Data")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Invitation code copied to clipboard.")
            }
            #if os(iOS)
            .sheet(isPresented: $showShareSheet) {
                if let code = generatedCode {
                    iOSShareSheet(items: ["Your invitation code for BasicScheduleCPreparation: \(code)"])
                }
            }
            #endif
        }
    }
    
    private func generateInvitationCode() {
        guard !email.isEmpty else { return }
        
        isGeneratingCode = true
        errorMessage = nil
        
        // Pass the selected role to createInvitation
        cloudKitManager.createInvitation(email: email, role: selectedRole) { code, error in
            isGeneratingCode = false
            
            if let error = error {
                errorMessage = error.localizedDescription
            } else if let code = code {
                generatedCode = code
            } else {
                errorMessage = "Failed to generate invitation code."
            }
        }
    }
    
    #if os(iOS)
    private func setupCloudKitShare() {
        cloudKitManager.setupCloudKitSharing { share, error in
            if let error = error {
                errorMessage = "Error setting up CloudKit sharing: \(error.localizedDescription)"
            } else if let share = share {
                // On iOS, present the CloudKit share sheet
                presentShareSheet(with: share)
            }
        }
    }
    
    private func presentShareSheet(with share: CKShare) {
        // Handle UICloudSharingController presentation
        DispatchQueue.main.async {
            let container = CKContainer(identifier: "iCloud.com.matthewstahl.BasicScheduleCPreparation")
            
            // Create and configure the sharing controller
            let sharingController = UICloudSharingController(share: share, container: container)
            
            // Use the StateObject delegate that persists with the view
            sharingController.delegate = sharingDelegate
            
            // Find the current view controller to present from
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                rootViewController.present(sharingController, animated: true)
            }
        }
    }
    #endif
}

#if os(iOS)
// Delegate class for UICloudSharingController as an ObservableObject
class SharingDelegate: NSObject, UICloudSharingControllerDelegate, ObservableObject {
    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        print("Failed to save CloudKit share: \(error)")
    }
    
    func itemTitle(for csc: UICloudSharingController) -> String? {
        return "BasicScheduleCPreparation Shared Data"
    }
}

// Share sheet for iOS - renamed to avoid conflicts
struct iOSShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing to update
    }
}
#endif

#if DEBUG
struct ShareDataView_Previews: PreviewProvider {
    static var previews: some View {
        ShareDataView()
    }
}
#endif
