// ScheduleViewModel.swift
import Foundation
import CoreData
import SwiftUI
import Combine

class ScheduleViewModel: ObservableObject {
    @Published var scheduleItems: [Schedule] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    let viewContext = PersistenceController.shared.container.viewContext
    
    // Schedule C categories from IRS
    static let categories = [
        "Advertising",
        "Car and truck expenses",
        "Commissions and fees",
        "Contract labor",
        "Depletion",
        "Depreciation",
        "Employee benefit programs",
        "Insurance",
        "Interest (Mortgage)",
        "Interest (Other)",
        "Legal and professional services",
        "Office expenses",
        "Pension and profit-sharing plans",
        "Rent or lease (Vehicles, machinery, equipment)",
        "Rent or lease (Other business property)",
        "Repairs and maintenance",
        "Supplies",
        "Taxes and licenses",
        "Travel",
        "Meals",
        "Utilities",
        "Wages",
        "Other expenses",
        "Gross receipts or sales"
    ]
    
    init() {
        fetchScheduleItems()
        setupObservers()
    }
    
    private func setupObservers() {
        // Listen for Core Data remote change notifications
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.fetchScheduleItems()
                }
            }
            .store(in: &cancellables)
            
        // Listen for user change notifications
        NotificationCenter.default.publisher(for: Notification.Name("UserDidChange"))
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.fetchScheduleItems()
                }
            }
            .store(in: &cancellables)
    }
    
    func fetchScheduleItems() {
        isLoading = true
        
        let request = NSFetchRequest<Schedule>(entityName: "Schedule")
        let sortDescriptor = NSSortDescriptor(keyPath: \Schedule.date, ascending: false)
        request.sortDescriptors = [sortDescriptor]
        
        do {
            scheduleItems = try viewContext.fetch(request)
            print("Fetched \(scheduleItems.count) schedule items")
            isLoading = false
        } catch {
            errorMessage = "Failed to fetch items: \(error.localizedDescription)"
            print("Error fetching schedule items: \(error)")
            isLoading = false
        }
    }
    
    func getCurrentUserName() -> String {
        // Get the user's name from Apple ID if available
        if let currentUser = UserAuthManager.shared.currentUser {
            return currentUser.displayName
        } else {
            // Fallback to device identifier
            #if os(iOS)
            return UIDevice.current.name
            #elseif os(macOS)
            return Host.current().localizedName ?? "Mac User"
            #else
            return "Unknown User"
            #endif
        }
    }
    
    func addScheduleItem(date: Date, amount: Decimal, store: String, category: String, notes: String?, photoURL: String?, userId: String? = nil) {
        print("Adding new schedule item: \(store) - \(amount)")
        
        // Use provided userId or get from current authenticated user
        let effectiveUserId = userId ?? getCurrentUserName()
        
        let newItem = Schedule.createNewEntry(
            in: viewContext,
            date: date,
            amount: amount,
            store: store,
            category: category,
            notes: notes,
            photoURL: photoURL,
            createdBy: effectiveUserId
        )
        
        // Record initial creation in history
        HistoryHelper.recordChange(
            in: viewContext,
            scheduleId: newItem.wrappedId,
            fieldName: "Created",
            oldValue: "N/A",
            newValue: "New entry created with amount \(amount.formatted(.currency(code: "USD")))",
            modifiedBy: effectiveUserId
        )
        
        saveContext()
        print("New item created with ID: \(newItem.wrappedId)")
    }
    
    func updateScheduleItem(
        _ item: Schedule,
        date: Date?,
        amount: Decimal?,
        store: String?,
        category: String?,
        notes: String?,
        photoURL: String?,
        userId: String? = nil
    ) {
        print("Updating schedule item \(item.wrappedId)")
        
        // Use provided userId or get from current authenticated user
        let effectiveUserId = userId ?? getCurrentUserName()
        
        var changesRecorded = false
        
        // Record history before updating
        if let date = date, date != item.date {
            print("Date changed from \(item.date?.formatted() ?? "nil") to \(date.formatted())")
            HistoryHelper.recordChange(
                in: viewContext,
                scheduleId: item.wrappedId,
                fieldName: "Date",
                oldValue: item.date?.formatted(date: .numeric, time: .omitted) ?? "None",
                newValue: date.formatted(date: .numeric, time: .omitted),
                modifiedBy: effectiveUserId
            )
            changesRecorded = true
        }
        
        if let amount = amount, amount != item.amount?.decimalValue {
            print("Amount changed from \(item.amount?.stringValue ?? "nil") to \(amount)")
            HistoryHelper.recordChange(
                in: viewContext,
                scheduleId: item.wrappedId,
                fieldName: "Amount",
                oldValue: (item.amount?.decimalValue ?? 0).formatted(.currency(code: "USD")),
                newValue: amount.formatted(.currency(code: "USD")),
                modifiedBy: effectiveUserId
            )
            changesRecorded = true
        }
        
        if let store = store, store != item.store {
            print("Store changed from \(item.store ?? "nil") to \(store)")
            HistoryHelper.recordChange(
                in: viewContext,
                scheduleId: item.wrappedId,
                fieldName: "Store",
                oldValue: item.store ?? "None",
                newValue: store,
                modifiedBy: effectiveUserId
            )
            changesRecorded = true
        }
        
        if let category = category, category != item.category {
            print("Category changed from \(item.category ?? "nil") to \(category)")
            HistoryHelper.recordChange(
                in: viewContext,
                scheduleId: item.wrappedId,
                fieldName: "Category",
                oldValue: item.category ?? "None",
                newValue: category,
                modifiedBy: effectiveUserId
            )
            changesRecorded = true
        }
        
        if notes != item.notes {
            let oldValue = item.notes ?? "None"
            let newValue = notes ?? "None"
            
            if oldValue != newValue {
                print("Notes changed")
                HistoryHelper.recordChange(
                    in: viewContext,
                    scheduleId: item.wrappedId,
                    fieldName: "Notes",
                    oldValue: oldValue,
                    newValue: newValue,
                    modifiedBy: effectiveUserId
                )
                changesRecorded = true
            }
        }
        
        if photoURL != item.photoURL {
            print("Photo URL changed")
            let oldValue = item.photoURL == nil || item.photoURL?.isEmpty == true ? "No receipt" : "Previous receipt"
            let newValue = photoURL == nil || photoURL?.isEmpty == true ? "Receipt removed" : "New receipt"
            
            HistoryHelper.recordChange(
                in: viewContext,
                scheduleId: item.wrappedId,
                fieldName: "Receipt",
                oldValue: oldValue,
                newValue: newValue,
                modifiedBy: effectiveUserId
            )
            changesRecorded = true
        }
        
        if !changesRecorded {
            print("No changes detected for item \(item.wrappedId)")
        }
        
        // Now update the item
        item.update(
            date: date,
            amount: amount,
            store: store,
            category: category,
            notes: notes,
            photoURL: photoURL,
            modifiedBy: effectiveUserId
        )
        
        saveContext()
    }
    
    func deleteScheduleItem(_ item: Schedule) {
        print("Deleting schedule item \(item.wrappedId)")
        
        // Use current authenticated user
        let userName = getCurrentUserName()
        
        // Record deletion in history - not normally visible, but kept for audit purposes
        HistoryHelper.recordChange(
            in: viewContext,
            scheduleId: item.wrappedId,
            fieldName: "Deleted",
            oldValue: "Entry for \(item.wrappedStore) with amount \((item.amount?.decimalValue ?? 0).formatted(.currency(code: "USD")))",
            newValue: "Entry deleted",
            modifiedBy: userName
        )
        
        viewContext.delete(item)
        saveContext()
    }
    
    func saveContext() {
        do {
            if viewContext.hasChanges {
                try viewContext.save()
                print("Context saved successfully")
            } else {
                print("No changes to save in context")
            }
            
            // Only fetch if there were changes to avoid unnecessary refreshes
            fetchScheduleItems()
        } catch {
            errorMessage = "Failed to save context: \(error.localizedDescription)"
            print("Error saving context: \(error)")
        }
    }
    
    // Get history of changes for an item
    func fetchHistory(for itemId: UUID) -> [HistoryEntry] {
        print("Fetching history for item: \(itemId)")
        
        // Count all history records first for debugging
        let countRequest = NSFetchRequest<NSNumber>(entityName: "ScheduleHistory")
        countRequest.resultType = .countResultType
        
        do {
            let count = try viewContext.count(for: countRequest)
            print("Total history records in database: \(count)")
        } catch {
            print("Error counting history records: \(error)")
        }
        
        // Fetch history specific to this item
        let results = HistoryHelper.fetchHistory(for: itemId, in: viewContext)
        print("Found \(results.count) history entries for item \(itemId)")
        
        return results
    }
    
    // Methods for sharing data
    func shareDataWithUser(email: String, completion: @escaping (Bool, Error?) -> Void) {
        PersistenceController.shared.shareWithUser(email: email, completion: completion)
    }
}
