// AdminView.swift - Fixed version
import SwiftUI
import CloudKit

struct AdminView: View {
    // Remove EnvironmentObject and use direct access
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cloudKitManager = CloudKitManager.shared
    
    @State private var showingConfirmation = false
    @State private var actionType: ActionType = .none
    @State private var selectedInvitation: CloudKitTypes.InvitationRecord?
    @State private var selectedPermission: CloudKitTypes.UserPermissionRecord?
    @State private var newRoleForPermission: CloudKitTypes.UserPermissionRecord.UserRole = .editor
    
    enum ActionType {
        case none
        case deleteInvitation
        case revokeAccess
        case changeRole
    }
    
    var body: some View {
        NavigationStack {
            List {
                if cloudKitManager.isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    }
                } else {
                    // Pending invitations
                    Section {
                        ForEach(cloudKitManager.invitations.filter { $0.status == .pending }) { invitation in
                            InvitationRow(invitation: invitation) {
                                selectedInvitation = invitation
                                actionType = .deleteInvitation
                                showingConfirmation = true
                            }
                        }
                        
                        if cloudKitManager.invitations.filter({ $0.status == .pending }).isEmpty {
                            Text("No pending invitations")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    } header: {
                        Text("Pending Invitations")
                    } footer: {
                        Text("These invitations are waiting to be accepted. You can delete them if they're no longer needed.")
                    }
                    
                    // Users with access
                    Section {
                        ForEach(cloudKitManager.permissions) { permission in
                            UserPermissionRow(permission: permission) {
                                selectedPermission = permission
                                actionType = .revokeAccess
                                showingConfirmation = true
                            } onRoleChange: { newRole in
                                selectedPermission = permission
                                newRoleForPermission = newRole
                                actionType = .changeRole
                                showingConfirmation = true
                            }
                        }
                        
                        if cloudKitManager.permissions.isEmpty {
                            Text("No users have been added yet")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    } header: {
                        Text("Users with Access")
                    } footer: {
                        Text("These users have access to your shared data. You can change their permissions or revoke access completely.")
                    }
                    
                    // Accepted invitations
                    Section {
                        ForEach(cloudKitManager.invitations.filter { $0.status == .accepted }) { invitation in
                            AcceptedInvitationRow(invitation: invitation)
                        }
                        
                        if cloudKitManager.invitations.filter({ $0.status == .accepted }).isEmpty {
                            Text("No accepted invitations")
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    } header: {
                        Text("Accepted Invitations")
                    }
                    
                    // Create New Invitation
                    Section {
                        NavigationLink(destination: ShareDataView()) {
                            Label("Create New Invitation", systemImage: "person.badge.plus")
                        }
                    }
                }
            }
            .navigationTitle("Manage Access")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        cloudKitManager.fetchInvitations()
                        cloudKitManager.fetchUserPermissions()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
            .refreshable {
                cloudKitManager.fetchInvitations()
                cloudKitManager.fetchUserPermissions()
            }
            .alert(confirmationTitle, isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) {
                    resetSelection()
                }
                
                Button(confirmationButtonText, role: confirmationButtonRole) {
                    performConfirmedAction()
                }
            } message: {
                Text(confirmationMessage)
            }
            .onAppear {
                cloudKitManager.fetchInvitations()
                cloudKitManager.fetchUserPermissions()
            }
        }
    }
    
    // MARK: - Alert Configuration
    
    private var confirmationTitle: String {
        switch actionType {
        case .deleteInvitation:
            return "Delete Invitation?"
        case .revokeAccess:
            return "Revoke Access?"
        case .changeRole:
            return "Change User Role?"
        case .none:
            return ""
        }
    }
    
    private var confirmationMessage: String {
        switch actionType {
        case .deleteInvitation:
            return "This will delete the invitation sent to \(selectedInvitation?.email ?? "this user"). They will no longer be able to use this code."
        case .revokeAccess:
            return "This will remove \(selectedPermission?.userName ?? "this user")'s access to your shared data. They will need a new invitation to regain access."
        case .changeRole:
            let roleName = newRoleForPermission == .admin ? "Administrator" : (newRoleForPermission == .editor ? "Editor" : "Viewer")
            return "Change \(selectedPermission?.userName ?? "this user")'s role to \(roleName)?"
        case .none:
            return ""
        }
    }
    
    private var confirmationButtonText: String {
        switch actionType {
        case .deleteInvitation:
            return "Delete"
        case .revokeAccess:
            return "Revoke"
        case .changeRole:
            return "Change"
        case .none:
            return ""
        }
    }
    
    private var confirmationButtonRole: ButtonRole? {
        switch actionType {
        case .deleteInvitation, .revokeAccess:
            return .destructive
        case .changeRole, .none:
            return nil
        }
    }
    
    // MARK: - Actions
        
    private func performConfirmedAction() {
        switch actionType {
        case .deleteInvitation:
            if let invitation = selectedInvitation {
                cloudKitManager.deleteInvitation(invitation) { error in
                    if error == nil {
                        resetSelection()
                    }
                }
            }
        case .revokeAccess:
            if let permission = selectedPermission {
                cloudKitManager.revokeAccess(permission) { error in
                    if error == nil {
                        resetSelection()
                    }
                }
            }
        case .changeRole:
            if let permission = selectedPermission {
                cloudKitManager.updatePermissionRole(permission, newRole: newRoleForPermission) { error in
                    if error == nil {
                        resetSelection()
                    }
                }
            }
        case .none:
            break
        }
    }
    
    private func resetSelection() {
        selectedInvitation = nil
        selectedPermission = nil
        actionType = .none
    }
}

// MARK: - Row Views

struct InvitationRow: View {
    let invitation: CloudKitTypes.InvitationRecord
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(invitation.email)
                    .font(.headline)
                
                Spacer()
                
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
            
            Text("Code: \(invitation.code)")
                .font(.subheadline)
                .foregroundColor(.blue)
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(4)
            
            Text("Created on \(invitation.created.formatted(date: .abbreviated, time: .shortened)) by \(invitation.creator)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct AcceptedInvitationRow: View {
    let invitation: CloudKitTypes.InvitationRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(invitation.email)
                .font(.headline)
            
            HStack {
                Text("Accepted by \(invitation.acceptedBy ?? "Unknown")")
                    .font(.subheadline)
                
                Spacer()
                
                if let date = invitation.acceptedDate {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Code: \(invitation.code)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct UserPermissionRow: View {
    let permission: CloudKitTypes.UserPermissionRecord
    let onRevoke: () -> Void
    let onRoleChange: (CloudKitTypes.UserPermissionRecord.UserRole) -> Void
    
    @State private var showingRoleMenu = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(permission.userName)
                    .font(.headline)
                
                Spacer()
                
                Button {
                    onRevoke()
                } label: {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.red)
                }
            }
            
            if let email = permission.email {
                Text(email)
                    .font(.subheadline)
            }
            
            HStack {
                // Role pill
                Menu {
                    Button("Administrator") {
                        onRoleChange(.admin)
                    }
                    
                    Button("Editor") {
                        onRoleChange(.editor)
                    }
                    
                    Button("Viewer") {
                        onRoleChange(.viewer)
                    }
                } label: {
                    HStack {
                        Text(roleText)
                            .font(.caption)
                            .foregroundColor(roleTextColor)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(roleTextColor)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(roleBgColor)
                    .cornerRadius(12)
                }
                
                Spacer()
                
                Text("Added \(permission.addedDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var roleText: String {
        switch permission.role {
        case .admin:
            return "Administrator"
        case .editor:
            return "Editor"
        case .viewer:
            return "Viewer"
        }
    }
    
    private var roleBgColor: Color {
        switch permission.role {
        case .admin:
            return Color.purple.opacity(0.2)
        case .editor:
            return Color.blue.opacity(0.2)
        case .viewer:
            return Color.gray.opacity(0.2)
        }
    }
    
    private var roleTextColor: Color {
        switch permission.role {
        case .admin:
            return Color.purple
        case .editor:
            return Color.blue
        case .viewer:
            return Color.gray
        }
    }
}

struct AdminView_Previews: PreviewProvider {
    static var previews: some View {
        AdminView()
    }
}
