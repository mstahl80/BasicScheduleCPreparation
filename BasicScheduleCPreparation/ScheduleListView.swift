// ScheduleListView.swift
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// Helper function for device IDs
func getPlatformUserIdentifier() -> String {
    #if os(iOS)
    return UIDevice.current.identifierForVendor?.uuidString ?? "unknown-ios-user"
    #elseif os(macOS)
    return ProcessInfo.processInfo.globallyUniqueString
    #else
    return UUID().uuidString
    #endif
}

struct ScheduleListView: View {
    @StateObject private var viewModel = ScheduleViewModel()
    @State private var showingAddSheet = false
    @State private var showingUserProfile = false
    @State private var showingShareData = false
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var showingDeleteConfirm = false
    @State private var itemToDelete: Schedule? = nil
    
    // Helper to check if user is admin
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
    
    // Helper to check if shared data is enabled
    private var isUsingSharedData: Bool {
        return UserDefaults.standard.bool(forKey: "isUsingSharedData")
    }
    
    // Helper to check if authenticated
    private var isAuthenticated: Bool {
        return UserDefaults.standard.bool(forKey: "isAuthenticated")
    }
    
    // Helper to get current user display name
    private func getCurrentUserDisplayName() -> String {
        let authManager = AuthAccess.getAuthManager()
        if let authObj = authManager as? NSObject {
            let selector = NSSelectorFromString("getCurrentUserDisplayName")
            if authObj.responds(to: selector) {
                let result = authObj.perform(selector)
                if let name = result?.takeUnretainedValue() as? String {
                    return name
                }
            }
        }
        
        // Default device name if not found
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac User"
        #else
        return "Unknown User"
        #endif
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // First tab - Summary View
            NavigationStack {
                SummaryView(viewModel: viewModel)
                    .navigationTitle("Financial Summary")
                    .toolbar {
                        userProfileToolbarContent
                    }
            }
            .tabItem {
                Label("Summary", systemImage: "chart.bar")
            }
            .tag(0)
            
            // Second tab - Transaction List
            NavigationStack {
                listContent
                    .navigationTitle("Schedule C Entries")
                    .toolbar {
                        transactionsToolbarContent
                    }
                    .searchable(text: $searchText, prompt: "Search transactions")
                    .refreshable {
                        viewModel.fetchScheduleItems()
                    }
            }
            .tabItem {
                Label("Transactions", systemImage: "list.bullet")
            }
            .tag(1)
        }
        .sheet(isPresented: $showingAddSheet) {
            ScheduleFormView(viewModel: viewModel, userId: getCurrentUserDisplayName(), editingItem: nil)
        }
        .sheet(isPresented: $showingUserProfile) {
            UserProfileView()
        }
        .sheet(isPresented: $showingShareData) {
            ShareDataView()
        }
        .overlay {
            if viewModel.isLoading {
                Color.black.opacity(0.1)
                    .ignoresSafeArea()
                ProgressView()
            }
        }
        .alert("Delete Transaction", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) { itemToDelete = nil }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    viewModel.deleteScheduleItem(item)
                }
                itemToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
        .alert(item: errorBinding) { errorWrapper in
            Alert(
                title: Text("Error"),
                message: Text(errorWrapper.error),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            viewModel.fetchScheduleItems()
        }
    }
    
    // MARK: - View Components
    
    private var listContent: some View {
        List {
            ForEach(filteredItems) { item in
                NavigationLink(destination: ScheduleDetailView(viewModel: viewModel, item: item, userId: getCurrentUserDisplayName())) {
                    ScheduleRowView(item: item)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        itemToDelete = item
                        showingDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
    
    // Fix toolbar content to use ToolbarContentBuilder
    @ToolbarContentBuilder
    private var transactionsToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingAddSheet = true
            } label: {
                Label("Add Entry", systemImage: "plus")
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    showingUserProfile = true
                } label: {
                    Label("User Profile", systemImage: "person.circle")
                }
                
                // Only show share option in shared mode
                if isUsingSharedData && isAdmin {
                    Button {
                        showingShareData = true
                    } label: {
                        Label("Invite Others", systemImage: "person.2.fill")
                    }
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }
    
    // Fix toolbar content for user profile using ToolbarContentBuilder
    @ToolbarContentBuilder
    private var userProfileToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    showingUserProfile = true
                } label: {
                    Label("User Profile", systemImage: "person.circle")
                }
                
                // Only show share option in shared mode
                if isUsingSharedData && isAdmin {
                    Button {
                        showingShareData = true
                    } label: {
                        Label("Invite Others", systemImage: "person.2.fill")
                    }
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }
    
    private var errorBinding: Binding<ErrorWrapper?> {
        Binding(
            get: { viewModel.errorMessage.map { ErrorWrapper(error: $0) } },
            set: { _ in viewModel.errorMessage = nil }
        )
    }
    
    var filteredItems: [Schedule] {
        if searchText.isEmpty {
            return viewModel.scheduleItems
        } else {
            return viewModel.scheduleItems.filter { item in
                item.wrappedStore.localizedCaseInsensitiveContains(searchText) ||
                item.wrappedCategory.localizedCaseInsensitiveContains(searchText) ||
                item.wrappedNotes.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

// MARK: - Row View
struct ScheduleRowView: View {
    let item: Schedule
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.wrappedStore)
                    .font(.headline)
                
                Text(item.wrappedCategory)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(item.amount?.decimalValue ?? Decimal(0), format: .currency(code: "USD"))
                    .font(.headline)
                    .foregroundStyle(item.wrappedCategory == "Gross receipts or sales" ? .green : .primary)
                
                Text(item.wrappedDate, format: .dateTime.day().month().year())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ErrorWrapper: Identifiable {
    let id = UUID()
    let error: String
}

#if DEBUG
struct ScheduleListView_Previews: PreviewProvider {
    static var previews: some View {
        let viewContext = PersistenceController.shared.container.viewContext
        return ScheduleListView()
            .environment(\.managedObjectContext, viewContext)
    }
}
#endif
