// ScheduleListView.swift - Fixed deletion functionality
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

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
    @State private var showingSummary = false
    @State private var showingUserProfile = false
    @State private var showingShareData = false
    @State private var searchText = ""
    @State private var selectedTab = 0
    @State private var itemToDelete: Schedule? = nil
    
    @EnvironmentObject var authManager: UserAuthManager
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // First tab - Summary View
            NavigationStack {
                SummaryView(viewModel: viewModel)
                    .navigationTitle("Financial Summary")
                    .toolbar {
                        userProfileToolbarItems
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
                        transactionsToolbarItems
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
            ScheduleFormView(viewModel: viewModel, userId: authManager.getCurrentUserDisplayName(), editingItem: nil)
        }
        .sheet(isPresented: $showingUserProfile) {
            UserProfileView()
                .environmentObject(authManager)
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
                NavigationLink(destination: ScheduleDetailView(viewModel: viewModel, item: item, userId: authManager.getCurrentUserDisplayName())) {
                    ScheduleRowView(item: item)
                }
            }
            // Fixed: Use SwiftUI's built-in onDelete handling
            .onDelete { indexSet in
                // Find the items to delete
                let itemsToDelete = indexSet.map { filteredItems[$0] }
                
                // Delete each item
                for item in itemsToDelete {
                    // Important: Access the method correctly
                    withAnimation {
                        viewModel.deleteScheduleItem(item)
                    }
                }
            }
        }
    }
    
    private var transactionsToolbarItems: some ToolbarContent {
        Group {
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
                    if authManager.isUsingSharedData {
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
    }
    
    private var userProfileToolbarItems: some ToolbarContent {
        Group {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingUserProfile = true
                    } label: {
                        Label("User Profile", systemImage: "person.circle")
                    }
                    
                    // Only show share option in shared mode
                    if authManager.isUsingSharedData {
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

// MARK: - Preview
struct ScheduleListView_Previews: PreviewProvider {
    static var previews: some View {
        let viewContext = PersistenceController.shared.container.viewContext
        
        // Create mock auth manager for preview
        let authManager = UserAuthManager.shared
        
        return ScheduleListView()
            .environment(\.managedObjectContext, viewContext)
            .environmentObject(authManager)
    }
}
