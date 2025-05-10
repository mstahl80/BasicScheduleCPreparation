// HistoryHelper.swift - Consolidated history tracking implementation
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
    // Record a change in history
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
        
        // Set values using key-value coding
        historyItem.setValue(UUID(), forKey: "id")
        historyItem.setValue(scheduleId, forKey: "scheduleId")
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
    
    // Fetch history records for an item
    static func fetchHistory(for itemId: UUID, in context: NSManagedObjectContext) -> [HistoryEntry] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ScheduleHistory")
        fetchRequest.predicate = NSPredicate(format: "scheduleId == %@", itemId as CVarArg)
        
        do {
            let historyItems = try context.fetch(fetchRequest)
            print("Fetched \(historyItems.count) history items for \(itemId)")
            
            // Sort by timestamp (newest first)
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
    
    // Create a history record from a group of managed objects
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
