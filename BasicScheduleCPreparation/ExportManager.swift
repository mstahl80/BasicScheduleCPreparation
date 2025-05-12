// ExportManager.swift - Fixed version
import Foundation
import CoreData
import SwiftUI
#if os(iOS)
import UIKit
import MobileCoreServices
#elseif os(macOS)
import AppKit
#endif

/// Manages data export functionality for the app
class ExportManager {
    static let shared = ExportManager()
    
    private init() {}
    
    // MARK: - CSV Export
    
    /// Exports schedule data to CSV format
    /// - Parameters:
    ///   - scheduleItems: Array of Schedule items to export
    ///   - completion: Closure with the CSV data and optional error
    func exportToCSV(scheduleItems: [Schedule], completion: @escaping (Data?, Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Create CSV header
                let csvHeader = "ID,Date,Transaction Type,Amount,Store,Category,Notes,Business Name,Created At,Created By,Modified At,Modified By,Photo URL\n"
                
                // Create CSV rows
                var csvString = csvHeader
                
                for item in scheduleItems {
                    // Format date fields
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    
                    let createdAtFormatter = DateFormatter()
                    createdAtFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    
                    // Format the date fields
                    let dateStr = dateFormatter.string(from: item.date ?? Date())
                    let createdAtStr = createdAtFormatter.string(from: item.createdAt ?? Date())
                    let modifiedAtStr = createdAtFormatter.string(from: item.modifiedAt ?? Date())
                    
                    // Escape fields that might contain commas or quotes
                    let escapedStore = self.escapeCsvField(item.store ?? "")
                    let escapedCategory = self.escapeCsvField(item.category ?? "")
                    let escapedNotes = self.escapeCsvField(item.notes ?? "")
                    let escapedBusinessName = self.escapeCsvField(item.businessName ?? "")
                    let escapedCreatedBy = self.escapeCsvField(item.createdBy ?? "")
                    let escapedModifiedBy = self.escapeCsvField(item.modifiedBy ?? "")
                    let escapedPhotoURL = self.escapeCsvField(item.photoURL ?? "")
                    
                    // Create CSV row
                    let csvRow = "\(item.id?.uuidString ?? ""),\(dateStr),\(item.transactionType ?? ""),\(item.amount?.doubleValue ?? 0.0),\(escapedStore),\(escapedCategory),\(escapedNotes),\(escapedBusinessName),\(createdAtStr),\(escapedCreatedBy),\(modifiedAtStr),\(escapedModifiedBy),\(escapedPhotoURL)\n"
                    
                    csvString.append(csvRow)
                }
                
                // Convert to data
                if let csvData = csvString.data(using: .utf8) {
                    DispatchQueue.main.async {
                        completion(csvData, nil)
                    }
                } else {
                    throw NSError(domain: "ExportManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert CSV to data"])
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }
    
    /// Properly escapes a field for CSV format
    private func escapeCsvField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            // Replace double quotes with two double quotes and wrap in quotes
            let escapedField = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escapedField)\""
        }
        return field
    }
    
    // MARK: - Full Export (Data and Images)
    
    /// Exports all schedule data and associated images to a zip file
    /// - Parameters:
    ///   - scheduleItems: Array of Schedule items to export
    ///   - completion: Closure with the zip file URL and optional error
    func exportFullData(scheduleItems: [Schedule], completion: @escaping (URL?, Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Create a temporary directory to hold our export files
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                
                // Create CSV file
                self.exportToCSV(scheduleItems: scheduleItems) { csvData, error in
                    if let error = error {
                        DispatchQueue.main.async {
                            completion(nil, error)
                        }
                        return
                    }
                    
                    guard let csvData = csvData else {
                        DispatchQueue.main.async {
                            completion(nil, NSError(domain: "ExportManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create CSV data"]))
                        }
                        return
                    }
                    
                    do {
                        // Write CSV to temp directory
                        let csvFile = tempDir.appendingPathComponent("schedule_data.csv")
                        try csvData.write(to: csvFile)
                        
                        // Create images directory
                        let imagesDir = tempDir.appendingPathComponent("receipt_images")
                        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
                        
                        // Copy all receipt images to the images directory
                        var copiedFiles = 0
                        for item in scheduleItems {
                            if let photoURLString = item.photoURL,
                               !photoURLString.isEmpty,
                               let photoURL = URL(string: photoURLString),
                               FileManager.default.fileExists(atPath: photoURL.path) {
                                
                                // Generate a unique filename using the item ID
                                let filename = "\(item.id?.uuidString ?? UUID().uuidString)_receipt.jpg"
                                let destinationURL = imagesDir.appendingPathComponent(filename)
                                
                                // Copy the file
                                try FileManager.default.copyItem(at: photoURL, to: destinationURL)
                                copiedFiles += 1
                            }
                        }
                        
                        // Create a manifest file with export information
                        let date = Date()
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        let formattedDate = dateFormatter.string(from: date)
                        
                        let manifestContent = """
                        Export Date: \(formattedDate)
                        Total Records: \(scheduleItems.count)
                        Images Exported: \(copiedFiles)
                        
                        This export contains:
                        - schedule_data.csv: All transaction records
                        - receipt_images/: Directory containing all receipt images
                        - manifest.txt: This file
                        
                        Generated by BasicScheduleCPreparation
                        """
                        
                        let manifestFile = tempDir.appendingPathComponent("manifest.txt")
                        try manifestContent.write(to: manifestFile, atomically: true, encoding: .utf8)
                        
                        // Create a formatted date string for the zip filename
                        let zipFilename = "schedule_export_\(self.formatDate(date)).zip"
                        let zipFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(zipFilename)
                        
                        try self.createZipFile(at: zipFileURL, contentsOf: tempDir)
                        
                        // Clean up the temporary directory
                        try FileManager.default.removeItem(at: tempDir)
                        
                        DispatchQueue.main.async {
                            completion(zipFileURL, nil)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            completion(nil, error)
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil, error)
                }
            }
        }
    }
    
    /// Creates a zip file from the contents of a directory
    private func createZipFile(at destinationURL: URL, contentsOf directoryURL: URL) throws {
        #if os(iOS) || os(macOS)
        // Import Foundation for Process
        import Foundation
        
        // Use the command line zip tool via Process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", destinationURL.path, "."]
        process.currentDirectoryURL = directoryURL
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw NSError(domain: "ExportManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create zip file: exit code \(process.terminationStatus)"])
        }
        #else
        // On other platforms, you might need a different approach or a third-party library
        throw NSError(domain: "ExportManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Zip creation not supported on this platform"])
        #endif
    }
    
    // Date formatter helper
    private func formatDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        return dateFormatter.string(from: date)
    }
    
    // MARK: - Document Share Methods
    
    /// Presents a share sheet to share a file
    /// - Parameters:
    ///   - fileURL: URL of the file to share
    ///   - presenter: UIViewController to present from (iOS only)
    ///   - completion: Optional completion handler
    #if os(iOS)
    func shareFile(fileURL: URL, presenter: UIViewController, completion: (() -> Void)? = nil) {
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        
        // Configure iPad presentation if needed
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = presenter.view
            popoverController.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        
        // Set completion handler
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            completion?()
        }
        
        presenter.present(activityVC, animated: true)
    }
    #elseif os(macOS)
    func shareFile(fileURL: URL, completion: (() -> Void)? = nil) {
        // On macOS, we can open a save panel to let the user choose where to save the file
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = fileURL.lastPathComponent
        savePanel.canCreateDirectories = true
        
        savePanel.begin { result in
            if result == .OK, let destinationURL = savePanel.url {
                do {
                    // If a file already exists at the destination, remove it first
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    
                    // Copy the file to the chosen location
                    try FileManager.default.copyItem(at: fileURL, to: destinationURL)
                    
                    // Open the file in Finder
                    NSWorkspace.shared.selectFile(destinationURL.path, inFileViewerRootedAtPath: destinationURL.deletingLastPathComponent().path)
                    
                    completion?()
                } catch {
                    // Show an alert with the error
                    let alert = NSAlert(error: error)
                    alert.runModal()
                    completion?()
                }
            } else {
                completion?()
            }
        }
    }
    #endif
}
