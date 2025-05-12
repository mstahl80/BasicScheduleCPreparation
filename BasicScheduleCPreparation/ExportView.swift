// ExportView.swift
import SwiftUI
import CoreData
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// View for exporting data from the app
struct ExportView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @Environment(\.dismiss) private var dismiss
    
    // State for export options
    @State private var selectedExportType: ExportType = .csv
    @State private var selectedBusinessId: UUID? = nil
    @State private var exportFromDate = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @State private var exportToDate = Date()
    @State private var includeIncomeTransactions = true
    @State private var includeExpenseTransactions = true
    
    // State for export progress
    @State private var isExporting = false
    @State private var exportProgress = 0.0
    @State private var showExportSuccessAlert = false
    @State private var showExportErrorAlert = false
    @State private var exportErrorMessage = ""
    
    // For file sharing
    #if os(iOS)
    @State private var exportFileURL: URL? = nil
    #endif
    
    // Business view model
    @StateObject private var businessViewModel = BusinessViewModel()
    
    // Export types
    enum ExportType: String, CaseIterable, Identifiable {
        case csv = "CSV File"
        case fullExport = "Full Export (Data + Images)"
        
        var id: String { self.rawValue }
        
        var description: String {
            switch self {
            case .csv:
                return "Exports transaction data to a CSV file that can be opened in Excel or other spreadsheet applications."
            case .fullExport:
                return "Exports transaction data and all receipt images to a ZIP file. This includes a CSV file and all images organized by transaction."
            }
        }
        
        var icon: String {
            switch self {
            case .csv:
                return "tablecells"
            case .fullExport:
                return "doc.zipper"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Export Type Selection
                Section("Export Type") {
                    Picker("Export Format", selection: $selectedExportType) {
                        ForEach(ExportType.allCases) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }
                    
                    Text(selectedExportType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Filter Options
                Section("Filter Options") {
                    // Business filter
                    Picker("Business", selection: $selectedBusinessId) {
                        Text("All Businesses").tag(nil as UUID?)
                        
                        ForEach(businessViewModel.businesses) { business in
                            Text(business.name ?? "").tag(business.id as UUID?)
                        }
                    }
                    
                    // Date range
                    DatePicker("From", selection: $exportFromDate, displayedComponents: .date)
                    DatePicker("To", selection: $exportToDate, in: exportFromDate..., displayedComponents: .date)
                    
                    // Transaction types
                    Toggle("Include Income Transactions", isOn: $includeIncomeTransactions)
                    Toggle("Include Expense Transactions", isOn: $includeExpenseTransactions)
                }
                
                // Export Preview
                Section("Export Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Records to Export: \(filteredItems.count)")
                            .font(.headline)
                        
                        if selectedExportType == .fullExport {
                            Text("Receipt Images: \(countReceiptImages())")
                        }
                        
                        Text("Date Range: \(exportFromDate.formatted(date: .abbreviated, time: .omitted)) to \(exportToDate.formatted(date: .abbreviated, time: .omitted))")
                        
                        if !includeIncomeTransactions || !includeExpenseTransactions {
                            Text("Transaction Types: \(transactionTypesText())")
                        }
                        
                        if let businessId = selectedBusinessId,
                           let business = businessViewModel.getBusiness(by: businessId) {
                            Text("Business: \(business.name ?? "Unknown")")
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Export Button
                Section {
                    if isExporting {
                        VStack(spacing: 10) {
                            ProgressView(value: exportProgress, total: 1.0)
                            
                            Text("Exporting data... Please wait")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button {
                            beginExport()
                        } label: {
                            HStack {
                                Spacer()
                                
                                if selectedExportType == .csv {
                                    Label("Export CSV", systemImage: "square.and.arrow.up")
                                } else {
                                    Label("Export All Data", systemImage: "square.and.arrow.up")
                                }
                                
                                Spacer()
                            }
                        }
                        .disabled(!canExport())
                    }
                }
                
                if !canExport() {
                    Section {
                        Text("Please select at least one transaction type (Income or Expense) to export.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Information Section
                Section("Information") {
                    VStack(alignment: .leading, spacing: 10) {
                        infoRow(title: "CSV Export", description: "CSV files can be opened in Excel, Google Sheets, or other spreadsheet applications.")
                        
                        infoRow(title: "Zip Export", description: "ZIP files contain both the CSV data and all receipt images. You'll need to unzip the file to access its contents.")
                        
                        infoRow(title: "Privacy Note", description: "Exported data may contain sensitive financial information. Keep your exports secure.")
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                businessViewModel.fetchBusinesses()
            }
            .alert("Export Successful", isPresented: $showExportSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your data has been exported successfully.")
            }
            .alert("Export Failed", isPresented: $showExportErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(exportErrorMessage)
            }
            #if os(iOS)
            .onChange(of: exportFileURL) { _, newValue in
                if let url = newValue {
                    // Get the active UIViewController to present from
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let rootViewController = windowScene.windows.first?.rootViewController {
                        // Present the share sheet
                        ExportManager.shared.shareFile(fileURL: url, presenter: rootViewController) {
                            // Clean up the file after sharing
                            self.cleanupExportFile()
                        }
                    }
                }
            }
            #endif
        }
    }
    
    // MARK: - Helper Views
    
    private func infoRow(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Determines if export is allowed based on selected options
    private func canExport() -> Bool {
        // Must have at least one transaction type selected
        return includeIncomeTransactions || includeExpenseTransactions
    }
    
    /// Begins the export process based on selected options
    private func beginExport() {
        guard canExport() else { return }
        
        isExporting = true
        exportProgress = 0.1
        
        if selectedExportType == .csv {
            exportToCSV()
        } else {
            exportFullData()
        }
    }
    
    /// Exports data to CSV
    private func exportToCSV() {
        ExportManager.shared.exportToCSV(scheduleItems: filteredItems) { data, error in
            if let error = error {
                self.handleExportError(error)
                return
            }
            
            guard let csvData = data else {
                self.handleExportError(NSError(domain: "ExportView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create CSV data"]))
                return
            }
            
            // Set export progress
            self.exportProgress = 0.7
            
            // Create a temporary file
            let filename = "schedule_export_\(Date().formatWithPattern("yyyyMMdd_HHmmss")).csv"
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            
            do {
                try csvData.write(to: fileURL)
                self.exportProgress = 1.0
                
                // Share the file
                #if os(iOS)
                self.exportFileURL = fileURL
                #elseif os(macOS)
                ExportManager.shared.shareFile(fileURL: fileURL) {
                    // Clean up on completion
                    try? FileManager.default.removeItem(at: fileURL)
                    self.finalizeExport()
                }
                #else
                self.finalizeExport()
                #endif
            } catch {
                self.handleExportError(error)
            }
        }
    }
    
    /// Exports all data including images
    private func exportFullData() {
        ExportManager.shared.exportFullData(scheduleItems: filteredItems) { fileURL, error in
            if let error = error {
                self.handleExportError(error)
                return
            }
            
            guard let url = fileURL else {
                self.handleExportError(NSError(domain: "ExportView", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create export file"]))
                return
            }
            
            self.exportProgress = 1.0
            
            // Share the zip file
            #if os(iOS)
            self.exportFileURL = url
            #elseif os(macOS)
            ExportManager.shared.shareFile(fileURL: url) {
                // Clean up on completion
                try? FileManager.default.removeItem(at: url)
                self.finalizeExport()
            }
            #else
            self.finalizeExport()
            #endif
        }
    }
    
    /// Handles export errors
    private func handleExportError(_ error: Error) {
        isExporting = false
        exportErrorMessage = error.localizedDescription
        showExportErrorAlert = true
    }
    
    /// Finalizes the export process
    private func finalizeExport() {
        DispatchQueue.main.async {
            self.isExporting = false
            self.showExportSuccessAlert = true
        }
    }
    
    /// Cleans up the temporary export file
    private func cleanupExportFile() {
        #if os(iOS)
        if let url = exportFileURL {
            try? FileManager.default.removeItem(at: url)
            exportFileURL = nil
        }
        
        finalizeExport()
        #endif
    }
    
    /// Counts the number of receipt images in the filtered items
    private func countReceiptImages() -> Int {
        return filteredItems.reduce(0) { count, item in
            if let photoURL = item.photoURL, !photoURL.isEmpty {
                return count + 1
            }
            return count
        }
    }
    
    /// Gets text describing the transaction types being exported
    private func transactionTypesText() -> String {
        if includeIncomeTransactions && includeExpenseTransactions {
            return "Income and Expenses"
        } else if includeIncomeTransactions {
            return "Income only"
        } else if includeExpenseTransactions {
            return "Expenses only"
        } else {
            return "None selected"
        }
    }
    
    // MARK: - Computed Properties
    
    /// Gets filtered items based on selected criteria
    private var filteredItems: [Schedule] {
        var items = viewModel.scheduleItems
        
        // Filter by date range
        items = items.filter { item in
            guard let date = item.date else { return false }
            return date >= exportFromDate && date <= exportToDate
        }
        
        // Filter by business if selected
        if let businessId = selectedBusinessId {
            items = items.filter { item in
                if let businessIdObj = item.businessId {
                    let idString = businessIdObj.uuidString
                    return UUID(uuidString: idString) == businessId
                }
                return false
            }
        }
        
        // Filter by transaction type
        items = items.filter { item in
            let transactionType = item.transactionType ?? ""
            
            if transactionType == "income" {
                return includeIncomeTransactions
            } else if transactionType == "expense" {
                return includeExpenseTransactions
            }
            
            return true
        }
        
        return items
    }
}

#if DEBUG
struct ExportView_Previews: PreviewProvider {
    static var previews: some View {
        ExportView(viewModel: ScheduleViewModel())
    }
}
#endif
