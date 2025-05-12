// HistoryView.swift - Dedicated view for showing change history
import SwiftUI

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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .bold()
                    }
                }
            }
            .onAppear {
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
        // Fetch history
        historyRecords = viewModel.fetchHistory(for: itemId)
        isLoading = false
    }
}

// MARK: - Preview
#if DEBUG
struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock view model
        let viewModel = ScheduleViewModel()
        
        // Preview with empty history
        HistoryView(itemId: UUID(), viewModel: viewModel)
    }
}
#endif
