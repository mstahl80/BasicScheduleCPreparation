// HistoryHelper.swift - Updated to use lowercase "scheduleId"
import Foundation
import CoreData

struct ChangeEntry: Identifiable {
    let id = UUID()
    let propertyName: String
    let oldValue: String
    let newValue: String
}

struct HistoryEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let modifiedBy: String
    let changes: [ChangeEntry]
}

class HistoryHelper {
    static func recordChange(
        in context: NSManagedObjectContext,
        scheduleId: UUID,
        fieldName: String,
        oldValue: String,
        newValue: String,
        modifiedBy: String
    ) {
        // Create a new history record
        let entityDescription = NSEntityDescription.entity(forEntityName: "ScheduleHistory", in: context)!
        let historyItem = NSManagedObject(entity: entityDescription, insertInto: context)
        
        // Set values using key-value coding - with correct lowercase "id"
        historyItem.setValue(UUID(), forKey: "id")
        historyItem.setValue(scheduleId, forKey: "scheduleId") // Updated to lowercase "id"
        historyItem.setValue(Date(), forKey: "timestamp")
        historyItem.setValue(fieldName, forKey: "fieldName")
        historyItem.setValue(oldValue, forKey: "oldValue")
        historyItem.setValue(newValue, forKey: "newValue")
        historyItem.setValue(modifiedBy, forKey: "modifiedBy")
        
        // Save the context immediately to ensure the record is stored
        do {
            try context.save()
            print("Successfully recorded change: \(fieldName) - \(oldValue) to \(newValue) for item \(scheduleId)")
        } catch {
            print("Failed to save history record: \(error.localizedDescription)")
        }
    }
    
    static func fetchHistory(for itemId: UUID, in context: NSManagedObjectContext) -> [HistoryEntry] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ScheduleHistory")
        fetchRequest.predicate = NSPredicate(format: "scheduleId == %@", itemId as CVarArg) // Updated to lowercase "id"
        
        do {
            let historyItems = try context.fetch(fetchRequest)
            print("Fetched \(historyItems.count) history items for \(itemId)")
            
            // Debug print to see what's being fetched
            for item in historyItems {
                let field = item.value(forKey: "fieldName") as? String ?? "unknown"
                let old = item.value(forKey: "oldValue") as? String ?? "unknown"
                let new = item.value(forKey: "newValue") as? String ?? "unknown"
                let time = item.value(forKey: "timestamp") as? Date ?? Date()
                let timeStr = time.formatted()
                print("History record from \(timeStr): \(field) changed from '\(old)' to '\(new)'")
            }
            
            let sortedItems = historyItems.sorted {
                let date1 = $0.value(forKey: "timestamp") as? Date ?? Date.distantPast
                let date2 = $1.value(forKey: "timestamp") as? Date ?? Date.distantPast
                return date1 > date2
            }
            
            // Group by timestamp (rounded to seconds) and modifier
            var records: [HistoryEntry] = []
            var currentGroup: [NSManagedObject] = []
            var currentKey: String = ""
            
            for item in sortedItems {
                let timestamp = item.value(forKey: "timestamp") as? Date ?? Date()
                let modifiedBy = item.value(forKey: "modifiedBy") as? String ?? ""
                let timeKey = Int(timestamp.timeIntervalSince1970)
                let newKey = "\(timeKey)|\(modifiedBy)"
                
                if newKey != currentKey && !currentGroup.isEmpty {
                    // Process previous group
                    if let record = createHistoryRecord(from: currentGroup) {
                        records.append(record)
                    }
                    currentGroup = []
                }
                
                currentKey = newKey
                currentGroup.append(item)
            }
            
            // Process the last group
            if !currentGroup.isEmpty {
                if let record = createHistoryRecord(from: currentGroup) {
                    records.append(record)
                }
            }
            
            print("Created \(records.count) grouped history entries")
            return records
        } catch {
            print("Error fetching history: \(error)")
            return []
        }
    }
    
    private static func createHistoryRecord(from items: [NSManagedObject]) -> HistoryEntry? {
        guard let firstItem = items.first else { return nil }
        
        let timestamp = firstItem.value(forKey: "timestamp") as? Date ?? Date()
        let modifiedBy = firstItem.value(forKey: "modifiedBy") as? String ?? ""
        
        let changes = items.map { item -> ChangeEntry in
            return ChangeEntry(
                propertyName: item.value(forKey: "fieldName") as? String ?? "",
                oldValue: item.value(forKey: "oldValue") as? String ?? "",
                newValue: item.value(forKey: "newValue") as? String ?? ""
            )
        }
        
        return HistoryEntry(
            timestamp: timestamp,
            modifiedBy: modifiedBy,
            changes: changes
        )
    }
}
