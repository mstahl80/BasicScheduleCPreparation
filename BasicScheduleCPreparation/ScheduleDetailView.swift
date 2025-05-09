// ScheduleDetailView.swift
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
            Section("Transaction Details") {
                LabeledContent("Date", value: item.wrappedDate, format: .dateTime.day().month().year())
                LabeledContent("Store", value: item.wrappedStore)
                LabeledContent("Amount", value: item.amount?.decimalValue ?? Decimal(0), format: .currency(code: "USD"))
                LabeledContent("Category", value: item.wrappedCategory)
            }
            
            if !item.wrappedNotes.isEmpty {
                Section("Notes") {
                    Text(item.wrappedNotes)
                }
            }
            
            if !item.wrappedPhotoURL.isEmpty, let url = URL(string: item.wrappedPhotoURL) {
                Section("Receipt") {
                    receiptImage(for: url)
                }
            }
            
            Section("Record Information") {
                LabeledContent("Created", value: item.wrappedCreatedAt, format: .dateTime)
                LabeledContent("Created By", value: item.wrappedCreatedBy)
                LabeledContent("Last Modified", value: item.wrappedModifiedAt, format: .dateTime)
                LabeledContent("Modified By", value: item.wrappedModifiedBy)
            }
            
            Section {
                Button {
                    print("View Change History button tapped")
                    showingHistory = true
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("View Change History")
                    }
                }
            }
        }
        .navigationTitle("Transaction Details")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
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
            HistoryView(itemId: item.wrappedId, viewModel: viewModel)
        }
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

// HistoryView implementation - Updated to fix issues
struct HistoryView: View {
    let itemId: UUID
    @ObservedObject var viewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var historyRecords: [HistoryEntry] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if historyRecords.isEmpty {
                    emptyHistoryView
                } else {
                    historyListView
                }
            }
            .navigationTitle("Change History")
            .toolbar {
                // Fixed Done button placement
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        print("Done button tapped")
                        dismiss()
                    } label: {
                        Text("Done")
                            .bold()
                    }
                }
            }
            .onAppear {
                print("HistoryView appeared for item \(itemId)")
                loadHistory()
            }
        }
    }
    
    private var emptyHistoryView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No change history available")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Changes to this entry will be tracked and shown here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var historyListView: some View {
        List {
            ForEach(historyRecords) { record in
                Section {
                    historyRecordView(for: record)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private func historyRecordView(for record: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with timestamp and user
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.headline)
                    
                    Text("Modified by: \(record.modifiedBy)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // Changes
            ForEach(record.changes) { change in
                VStack(alignment: .leading, spacing: 6) {
                    Text(change.propertyName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Previous:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(change.oldValue)
                                .font(.callout)
                                .foregroundColor(.primary)
                                .padding(6)
                                .background(Color(.systemGray6))
                                .cornerRadius(4)
                        }
                        
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Changed to:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(change.newValue)
                                .font(.callout)
                                .foregroundColor(.primary)
                                .padding(6)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding(.vertical, 4)
                
                if change.id != record.changes.last?.id {
                    Divider()
                        .padding(.vertical, 4)
                }
            }
        }
        .padding(.vertical, 6)
    }
    
    private func loadHistory() {
        isLoading = true
        // Fetch history without delay
        historyRecords = viewModel.fetchHistory(for: itemId)
        isLoading = false
        
        print("Loaded \(historyRecords.count) history records")
        
        // Debug history records
        for record in historyRecords {
            print("Record from \(record.timestamp) by \(record.modifiedBy) with \(record.changes.count) changes")
            for change in record.changes {
                print("  - \(change.propertyName): '\(change.oldValue)' -> '\(change.newValue)'")
            }
        }
    }
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
