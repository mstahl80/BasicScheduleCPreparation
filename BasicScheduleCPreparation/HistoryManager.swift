// HistoryManager.swift
import Foundation
import CoreData

// Models for history records
struct HistoryChange: Identifiable {
    let id = UUID()
    let propertyName: String
    let oldValue: String
    let newValue: String
}

struct HistoryRecord: Identifiable {
    let id = UUID()
    let timestamp: Date
    let modifiedBy: String
    let changes: [HistoryChange]
}

class HistoryManager {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // Record a change in history
    func recordChange(
        scheduleId: UUID,
        fieldName: String,
        oldValue: String,
        newValue: String,
        modifiedBy: String
    ) {
        // Create a new history record using direct managed object creation
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
    }
    
    // Fetch history records for an item
    func fetchHistory(for itemId: UUID) -> [HistoryRecord] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ScheduleHistory")
        fetchRequest.predicate = NSPredicate(format: "scheduleId == %@", itemId as CVarArg)
        
        do {
            let historyItems = try context.fetch(fetchRequest)
            let sortedItems = historyItems.sorted {
                let date1 = $0.value(forKey: "timestamp") as? Date ?? Date.distantPast
                let date2 = $1.value(forKey: "timestamp") as? Date ?? Date.distantPast
                return date1 > date2
            }
            
            // Group by timestamp (rounded to seconds) and modifier
            var records: [HistoryRecord] = []
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
            
            return records
        } catch {
            print("Error fetching history: \(error)")
            return []
        }
    }
    
    // Create a history record from a group of managed objects
    private func createHistoryRecord(from items: [NSManagedObject]) -> HistoryRecord? {
        guard let firstItem = items.first else { return nil }
        
        let timestamp = firstItem.value(forKey: "timestamp") as? Date ?? Date()
        let modifiedBy = firstItem.value(forKey: "modifiedBy") as? String ?? ""
        
        let changes = items.map { item -> HistoryChange in
            // This is the fixed line - don't use named parameters for struct initialization
            return HistoryChange(
                propertyName: item.value(forKey: "fieldName") as? String ?? "",
                oldValue: item.value(forKey: "oldValue") as? String ?? "",
                newValue: item.value(forKey: "newValue") as? String ?? ""
            )
        }
        
        // And here too - fix struct initialization
        return HistoryRecord(
            timestamp: timestamp,
            modifiedBy: modifiedBy,
            changes: changes
        )
    }
}
