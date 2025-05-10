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
    private var viewContext: NSManagedObjectContext {
        // Always use the current container's view context
        return PersistenceController.shared.container.viewContext
    }
    
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
        
        // Listen for container change notifications
        NotificationCenter.default.publisher(for: Notification.Name("StoreContainerChanged"))
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
    
    // Add a new schedule item
    func addScheduleItem(
        date: Date,
        amount: Decimal,
        store: String,
        category: String,
        notes: String? = nil,
        photoURL: String? = nil,
        userId: String
    ) {
        // Create a new item using the helper method
        _ = Schedule.createNewEntry(
            in: viewContext,
            date: date,
            amount: amount,
            store: store,
            category: category,
            notes: notes,
            photoURL: photoURL,
            createdBy: userId
        )
        
        // Save the context
        do {
            try viewContext.save()
            fetchScheduleItems() // Refresh the list
        } catch {
            errorMessage = "Failed to save new item: \(error.localizedDescription)"
            print("Error saving new item: \(error)")
        }
    }
    
    // Update an existing schedule item
    func updateScheduleItem(
        _ item: Schedule,
        date: Date,
        amount: Decimal,
        store: String,
        category: String,
        notes: String? = nil,
        photoURL: String? = nil,
        userId: String
    ) {
        // Track changes for history
        let oldDate = item.wrappedDate
        let oldAmount = item.amount?.decimalValue ?? Decimal(0)
        let oldStore = item.wrappedStore
        let oldCategory = item.wrappedCategory
        let oldNotes = item.wrappedNotes
        let oldPhotoURL = item.wrappedPhotoURL
        
        // Update the item using the helper method
        item.update(
            date: date,
            amount: amount,
            store: store,
            category: category,
            notes: notes,
            photoURL: photoURL,
            modifiedBy: userId
        )
        
        // Record history for each changed field
        if oldDate != date {
            let oldDateString = oldDate.formatted(date: .abbreviated, time: .omitted)
            let newDateString = date.formatted(date: .abbreviated, time: .omitted)
            HistoryHelper.recordChange(
                in: viewContext,
                scheduleId: item.wrappedId,
                fieldName: "Date",
                oldValue: oldDateString,
                newValue: newDateString,
                modifiedBy: userId
            )
        }
        
        if oldAmount != amount {
            let oldAmountString = oldAmount.formatted(.currency(code: "USD"))
            let newAmountString = amount.formatted(.currency(code: "USD"))
            HistoryHelper.recordChange(
                in: viewContext,
                scheduleId: item.wrappedId,
                fieldName: "Amount",
                oldValue: oldAmountString,
                newValue: newAmountString,
                modifiedBy: userId
            )
        }
        
        if oldStore != store {
            HistoryHelper.recordChange(
                in: viewContext,
                scheduleId: item.wrappedId,
                fieldName: "Store",
                oldValue: oldStore,
                newValue: store,
                modifiedBy: userId
            )
        }
        
        if oldCategory != category {
            HistoryHelper.recordChange(
                in: viewContext,
                scheduleId: item.wrappedId,
                fieldName: "Category",
                oldValue: oldCategory,
                newValue: category,
                modifiedBy: userId
            )
        }
        
        if oldNotes != notes ?? "" {
            HistoryHelper.recordChange(
                in: viewContext,
                scheduleId: item.wrappedId,
                fieldName: "Notes",
                oldValue: oldNotes,
                newValue: notes ?? "",
                modifiedBy: userId
            )
        }
        
        if oldPhotoURL != photoURL ?? "" {
            HistoryHelper.recordChange(
                in: viewContext,
                scheduleId: item.wrappedId,
                fieldName: "Receipt Photo",
                oldValue: oldPhotoURL.isEmpty ? "None" : "Photo",
                newValue: (photoURL ?? "").isEmpty ? "None" : "Photo",
                modifiedBy: userId
            )
        }
        
        // Save the context
        do {
            try viewContext.save()
            fetchScheduleItems() // Refresh the list
        } catch {
            errorMessage = "Failed to update item: \(error.localizedDescription)"
            print("Error updating item: \(error)")
        }
    }
    
    // Delete a schedule item
    func deleteScheduleItem(_ item: Schedule) {
        viewContext.delete(item)
        
        do {
            try viewContext.save()
            fetchScheduleItems() // Refresh the list
        } catch {
            errorMessage = "Failed to delete item: \(error.localizedDescription)"
            print("Error deleting item: \(error)")
        }
    }
    
    // Fetch history for an item
    func fetchHistory(for itemId: UUID) -> [HistoryEntry] {
        return HistoryHelper.fetchHistory(for: itemId, in: viewContext)
    }
    
    // Get current user name
    func getCurrentUserName() -> String {
        return UserAuthManager.shared.getCurrentUserDisplayName()
    }
}
