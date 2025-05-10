// ShareDataView.swift
import SwiftUI

struct ShareDataView: View {
    @State private var email = ""
    @State private var isGeneratingCode = false
    @State private var generatedCode: String? = nil
    @State private var errorMessage: String? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Generate Invitation Code") {
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                    
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
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            HStack {
                                Button {
                                    // Copy to clipboard
                                    #if os(iOS)
                                    UIPasteboard.general.string = code
                                    #elseif os(macOS)
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(code, forType: .string)
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
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Section("Information") {
                    Text("The invited user will need to enter this code when they first launch the app. They will need to have this app installed.")
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
            #if os(iOS)
            .sheet(isPresented: $showShareSheet) {
                if let code = generatedCode {
                    ShareSheet(items: ["Your invitation code for BasicScheduleCPreparation: \(code)"])
                }
            }
            #endif
        }
    }
    
    private func generateInvitationCode() {
        guard !email.isEmpty else { return }
        
        isGeneratingCode = true
        errorMessage = nil
        
        PersistenceController.shared.generateInvitationCode(forEmail: email) { code, error in
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
}

#if os(iOS)
// Share sheet for iOS
struct ShareSheet: UIViewControllerRepresentable {
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
