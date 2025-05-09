// ShareDataView.swift
import SwiftUI
import CloudKit

struct ShareDataView: View {
    @State private var email = ""
    @State private var isSharing = false
    @State private var sharingResult: (success: Bool, error: Error?)? = nil
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Invite User") {
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                    
                    Button {
                        shareData()
                    } label: {
                        if isSharing {
                            ProgressView()
                        } else {
                            Text("Send Invitation")
                        }
                    }
                    .disabled(email.isEmpty || isSharing)
                }
                
                if let result = sharingResult {
                    Section {
                        if result.success {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Invitation sent successfully!")
                            }
                        } else {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text("Failed to send invitation: \(result.error?.localizedDescription ?? "Unknown error")")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                Section("Information") {
                    Text("The invited user will receive an email with instructions on how to access the shared data. They will need to have this app installed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
        }
    }
    
    private func shareData() {
        isSharing = true
        
        PersistenceController.shared.shareWithUser(email: email) { success, error in
            isSharing = false
            sharingResult = (success, error)
        }
    }
}
