// Updated ScheduleListView.swift
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
    @StateObject private var businessViewModel = BusinessViewModel()
    @State private var showingAddSheet = false
    @State private var showingUserProfile = false
    @State private var showingShareData = false
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var showingDeleteConfirm = false
    @State private var itemToDelete: Schedule? = nil
    
    // Business filter
    @State private var selectedBusinessId: UUID? = nil
    
    // Transaction type filter
    @State private var transactionTypeFilter: String? = nil
    
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
                if businessViewModel.businesses.isEmpty {
                    noBusinessesView
                } else {
                    BusinessSummaryView(
                        viewModel: viewModel,
                        businessViewModel: businessViewModel,
                        selectedBusinessId: $selectedBusinessId
                    )
                    .navigationTitle("Financial Summary")
                    .toolbar {
                        userProfileToolbarContent
                    }
                }
            }
            .tabItem {
                Label("Summary", systemImage: "chart.bar")
            }
            .tag(0)
            
            // Second tab - Transaction List
            NavigationStack {
                VStack(spacing: 0) {
                    // Filter bar
                    filterBar
                    
                    // List content
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredItems.isEmpty {
                        if businessViewModel.businesses.isEmpty {
                            noBusinessesView
                        } else {
                            noTransactionsView
                        }
                    } else {
                        listContent
                    }
                }
                .navigationTitle("Transactions")
                .toolbar {
                    transactionsToolbarContent
                }
                .searchable(text: $searchText, prompt: "Search transactions")
                .refreshable {
                    viewModel.fetchScheduleItems()
                    businessViewModel.fetchBusinesses()
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
            businessViewModel.fetchBusinesses()
        }
    }
    
    // MARK: - View Components
    
    private var filterBar: some View {
        VStack(spacing: 0) {
            HStack {
                // Business Picker
                Picker("Business", selection: $selectedBusinessId) {
                    Text("All Businesses").tag(nil as UUID?)
                    
                    ForEach(businessViewModel.businesses, id: \.id) { business in
                        Text(business.name ?? "").tag(business.id as UUID?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Spacer()
                
                // Transaction Type Picker
                Picker("Type", selection: $transactionTypeFilter) {
                    Text("All").tag(nil as String?)
                    Text("Income").tag("income")
                    Text("Expense").tag("expense")
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(maxWidth: 200)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
            
            Divider()
        }
    }
    
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
    
    private var noBusinessesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("No Businesses Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Start by adding a business to track your income and expenses.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Button {
                showingAddSheet = true
            } label: {
                Label("Add Business", systemImage: "plus.circle.fill")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 10)
        }
        .padding()
    }
    
    private var noTransactionsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("No Transactions")
                .font(.title2)
                .fontWeight(.bold)
            
            if let selectedBusinessId = selectedBusinessId {
                // Show message for specific business
                if let business = businessViewModel.businesses.first(where: { $0.id == selectedBusinessId }) {
                    Text("No transactions found for \(business.name ?? "this business")")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                }
            } else if transactionTypeFilter != nil {
                // Show message for transaction type filter
                Text("No \(transactionTypeFilter ?? "") transactions found")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
            } else {
                // General message
                Text("Start by adding income or expense transactions")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
            }
            
            Button {
                showingAddSheet = true
            } label: {
                Label("Add Transaction", systemImage: "plus.circle.fill")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 10)
        }
        .padding()
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
        var items = viewModel.scheduleItems
        
        // Apply business filter
        if let businessId = selectedBusinessId {
            items = items.filter {
                if let businessIdObj = $0.businessId as? NSUUID {
                    return UUID(uuidString: businessIdObj.uuidString) == businessId
                }
                return false
            }
        }
        
        // Apply transaction type filter
        if let typeFilter = transactionTypeFilter {
            items = items.filter { ($0.transactionType ?? "") == typeFilter }
        }
        
        // Apply search text filter
        if !searchText.isEmpty {
            items = items.filter { item in
                let storeMatch = (item.store ?? "").localizedCaseInsensitiveContains(searchText)
                let categoryMatch = (item.category ?? "").localizedCaseInsensitiveContains(searchText)
                let notesMatch = (item.notes ?? "").localizedCaseInsensitiveContains(searchText)
                let businessMatch = (item.businessName ?? "").localizedCaseInsensitiveContains(searchText)
                
                return storeMatch || categoryMatch || notesMatch || businessMatch
            }
        }
        
        return items
    }
}

// MARK: - Row View
struct ScheduleRowView: View {
    let item: Schedule
    
    var body: some View {
        HStack {
            // Transaction type indicator
            ZStack {
                Circle()
                    .fill(item.transactionType == "income" ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: item.transactionType == "income" ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                    .foregroundColor(item.transactionType == "income" ? .green : .red)
                    .font(.system(size: 18))
            }
            .padding(.trailing, 8)
            
            VStack(alignment: .leading) {
                Text(item.store ?? "")
                    .font(.headline)
                
                HStack {
                    Text(item.category ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // Business pill
                    if let businessName = item.businessName, !businessName.isEmpty {
                        Text(businessName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(10)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(item.amount?.decimalValue ?? Decimal(0), format: .currency(code: "USD"))
                    .font(.headline)
                    .foregroundStyle(item.transactionType == "income" ? .green : .primary)
                
                Text(item.date ?? Date(), format: .dateTime.day().month().year())
                    .font(.caption)
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
