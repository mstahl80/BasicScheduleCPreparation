// Enhanced ScheduleDetailView with spacing between record info and history button
import SwiftUI

struct ScheduleDetailView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    let item: Schedule
    let userId: String
    
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirm = false
    @State private var showingHistory = false
    
    var body: some View {
        List {
            // Business Information
            Section("Business Details") {
                LabeledContent("Business", value: item.businessName ?? "")
                
                if let businessType = businessTypeForItem() {
                    LabeledContent("Business Type", value: businessType)
                }
            }
            
            // Transaction Type
            Section("Transaction Type") {
                HStack {
                    Text((item.transactionType ?? "expense").capitalized)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    transactionTypeIcon
                }
            }
            
            // Transaction Details
            Section("Transaction Details") {
                LabeledContent("Date", value: item.date ?? Date(), format: .dateTime.day().month().year())
                LabeledContent("Payee/Store", value: item.store ?? "")
                
                HStack {
                    Text("Amount")
                    Spacer()
                    Text(item.amount?.decimalValue ?? Decimal(0), format: .currency(code: "USD"))
                        .foregroundColor(item.transactionType == "income" ? .green : .primary)
                }
                
                LabeledContent("Category", value: item.category ?? "")
            }
            
            if !(item.notes?.isEmpty ?? true) {
                Section("Notes") {
                    Text(item.notes ?? "")
                }
            }
            
            if let photoURL = item.photoURL, !photoURL.isEmpty, let url = URL(string: photoURL) {
                Section("Receipt") {
                    receiptImage(for: url)
                }
            }
            
            // Record Information Section
            Section("Record Information") {
                LabeledContent("Created", value: item.createdAt ?? Date(), format: .dateTime)
                LabeledContent("Created By", value: item.createdBy ?? "")
                LabeledContent("Last Modified", value: item.modifiedAt ?? Date(), format: .dateTime)
                LabeledContent("Modified By", value: item.modifiedBy ?? "")
            }
            
            // Separate section for the history button in record info
            Section {
                Button {
                    showingHistory = true
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.blue)
                        Text("View Change History")
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Add a dedicated, prominent section for History
            Section("Change History") {
                Button {
                    showingHistory = true
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3)
                        
                        VStack(alignment: .leading) {
                            Text("View Change History")
                                .font(.headline)
                            
                            Text("See all changes made to this entry")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.blue)
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 6) // Add some vertical padding for prominence
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            
            // Add History button to the toolbar as well
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingHistory = true
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            }
            
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showingDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            ScheduleFormView(viewModel: viewModel, userId: userId, editingItem: item)
        }
        .alert("Delete Transaction", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteScheduleItem(item)
            }
        } message: {
            Text("Are you sure you want to delete this transaction? This action cannot be undone.")
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView(itemId: item.id ?? UUID(), viewModel: viewModel)
        }
    }
    
    // Custom views and helpers
    
    private var navigationTitle: String {
        if item.transactionType == "income" {
            return "Income Details"
        } else {
            return "Expense Details"
        }
    }
    
    private var transactionTypeIcon: some View {
        Group {
            if item.transactionType == "income" {
                Label("Income", systemImage: "arrow.down.circle.fill")
                    .foregroundColor(.green)
            } else {
                Label("Expense", systemImage: "arrow.up.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .font(.subheadline)
    }
    
    private func businessTypeForItem() -> String? {
        // Access business type from the business ID
        guard let businessIdObj = item.businessId,
              let businessId = UUID(uuidString: businessIdObj.uuidString) else {
            return nil
        }
        
        // This would be more efficient with a proper business lookup service
        // For now, just going through the view model
        let businessItems = viewModel.scheduleItems.filter { scheduleItem in
            if let itemBusinessIdObj = scheduleItem.businessId {
                return UUID(uuidString: itemBusinessIdObj.uuidString) == businessId
            }
            return false
        }
        
        if let firstItem = businessItems.first {
            return getBusinessTypeFromName(firstItem.businessName ?? "")
        }
        
        return nil
    }
    
    private func getBusinessTypeFromName(_ name: String) -> String {
        // This is a placeholder. In a real implementation, you would look up
        // the business type from your business entity
        return "Business"
    }
    
    @ViewBuilder
    private func receiptImage(for url: URL) -> some View {
        #if os(iOS) || os(macOS)
        if let imageData = try? Data(contentsOf: url),
           let image = loadImage(from: imageData) {
            Image(uiOrNsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .cornerRadius(10)
        } else {
            Text("Unable to load receipt image")
                .foregroundColor(.secondary)
        }
        #else
        Text("Receipt image available")
            .foregroundColor(.secondary)
        #endif
    }
    
    #if os(iOS)
    private func loadImage(from data: Data) -> UIImage? {
        return UIImage(data: data)
    }
    
    private typealias UIOrNSImage = UIImage
    #elseif os(macOS)
    private func loadImage(from data: Data) -> NSImage? {
        return NSImage(data: data)
    }
    
    private typealias UIOrNSImage = NSImage
    #endif
}

// Extension for cross-platform image support
#if os(iOS)
extension Image {
    init(uiOrNsImage: UIImage) {
        self.init(uiImage: uiOrNsImage)
    }
}
#elseif os(macOS)
extension Image {
    init(uiOrNsImage: NSImage) {
        self.init(nsImage: uiOrNsImage)
    }
}
#endif

// MARK: - Preview
#if DEBUG
struct ScheduleDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let viewContext = PersistenceController.shared.container.viewContext
        let testItem = Schedule(context: viewContext)
        testItem.id = UUID()
        testItem.date = Date()
        testItem.store = "Office Supplies Store"
        testItem.amount = NSDecimalNumber(value: 125.99)
        testItem.category = "Office expenses"
        testItem.notes = "Printer ink and paper"
        testItem.businessId = UUID() as NSUUID
        testItem.businessName = "My Software Company"
        testItem.transactionType = "expense"
        testItem.createdAt = Date().addingTimeInterval(-86400) // Yesterday
        testItem.modifiedAt = Date()
        testItem.createdBy = "John User"
        testItem.modifiedBy = "John User"
        
        return NavigationStack {
            ScheduleDetailView(
                viewModel: ScheduleViewModel(),
                item: testItem,
                userId: "John User"
            )
        }
    }
}
#endif
