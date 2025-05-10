// Updated ScheduleViewModel.swift
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
    
    // Schedule C expense categories from IRS
    static let expenseCategories = [
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
        "Other expenses"
    ]
    
    // Schedule C income categories
    static let incomeCategories = [
        "Gross receipts or sales",
        "Returns and allowances",
        "Other income"
    ]
    
    // Combined categories for backward compatibility
    static var categories: [String] {
        return incomeCategories + expenseCategories
    }
    
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
    
    // Get items for a specific business
    func getItemsForBusiness(businessId: UUID) -> [Schedule] {
        return scheduleItems.filter {
            if let scheduleBusinessId = ($0.businessId as? NSUUID)?.uuidString {
                return UUID(uuidString: scheduleBusinessId) == businessId
            }
            return false
        }
    }
    
    // Get total income for a business
    func getTotalIncomeForBusiness(businessId: UUID) -> Decimal {
        let businessItems = getItemsForBusiness(businessId: businessId)
        let incomeItems = businessItems.filter { ($0.transactionType ?? "") == "income" }
        return incomeItems.reduce(Decimal(0)) { sum, item in
            sum + (item.amount?.decimalValue ?? Decimal(0))
        }
    }
    
    // Get total expenses for a business
    func getTotalExpensesForBusiness(businessId: UUID) -> Decimal {
        let businessItems = getItemsForBusiness(businessId: businessId)
        let expenseItems = businessItems.filter { ($0.transactionType ?? "") == "expense" }
        return expenseItems.reduce(Decimal(0)) { sum, item in
            sum + (item.amount?.decimalValue ?? Decimal(0))
        }
    }
    
    // Get profit for a business
    func getProfitForBusiness(businessId: UUID) -> Decimal {
        let income = getTotalIncomeForBusiness(businessId: businessId)
        let expenses = getTotalExpensesForBusiness(businessId: businessId)
        return income - expenses
    }
    
    // Add a new schedule item
    func addScheduleItem(
        date: Date,
        amount: Decimal,
        store: String,
        category: String,
        notes: String? = nil,
        photoURL: String? = nil,
        businessId: UUID,
        businessName: String,
        transactionType: String,
        userId: String
    ) {
        // Create a new item
        let newItem = Schedule(context: viewContext)
        newItem.id = UUID()
        newItem.date = date
        newItem.amount = NSDecimalNumber(decimal: amount)
        newItem.store = store
        newItem.category = category
        newItem.notes = notes
        newItem.photoURL = photoURL
        newItem.businessId = businessId as NSUUID
        newItem.businessName = businessName
        newItem.transactionType = transactionType
        newItem.createdAt = Date()
        newItem.modifiedAt = Date()
        newItem.createdBy = userId
        newItem.modifiedBy = userId
        
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
        businessId: UUID,
        businessName: String,
        transactionType: String,
        userId: String
    ) {
        // Track changes for history
        let oldDate = item.date ?? Date()
        let oldAmount = item.amount?.decimalValue ?? Decimal(0)
        let oldStore = item.store ?? ""
        let oldCategory = item.category ?? ""
        let oldNotes = item.notes ?? ""
        let oldPhotoURL = item.photoURL ?? ""
        let oldBusinessIdObj = item.businessId as? NSUUID
        let oldBusinessId = oldBusinessIdObj != nil ? UUID(uuidString: oldBusinessIdObj!.uuidString) : nil
        let oldBusinessName = item.businessName ?? ""
        let oldTransactionType = item.transactionType ?? ""
        
        // Update the item
        item.date = date
        item.amount = NSDecimalNumber(decimal: amount)
        item.store = store
        item.category = category
        item.notes = notes
        item.photoURL = photoURL
        item.businessId = businessId as NSUUID
        item.businessName = businessName
        item.transactionType = transactionType
        item.modifiedAt = Date()
        item.modifiedBy = userId
        
        // Record history for each changed field
        if oldDate != date {
            let oldDateString = oldDate.formatted(date: .abbreviated, time: .omitted)
            let newDateString = date.formatted(date: .abbreviated, time: .omitted)
            HistoryHelper.recordChange(
                in: viewContext,
                scheduleId: item.id ?? UUID(),
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
                scheduleId: item.id ?? UUID(),
                fieldName: "Amount",
                oldValue: oldAmountString,
                newValue: newAmountString,
                modifiedBy: userId
            )
        }
        
        if oldStore != store {
            HistoryHelper.recordChange(
                in: viewContext,
                scheduleId: item.id ?? UUID(),
                fieldName: "Store",
                oldValue: oldStore,
                newValue: store,
                modifiedBy: userId
            )
        }
        
        if oldCategory != category {
            HistoryHelper.recordChange(
                in: viewContext,
                scheduleId: item.id ?? UUID(),
                fieldName: "Category",
                oldValue: oldCategory,
                newValue: category,
                modifiedBy: userId
            )
        }
        
        if oldNotes != notes ?? "" {
            HistoryHelper.recordChange(
                in: viewContext,
                scheduleId: item.id ?? UUID(),
                fieldName: "Notes",
                oldValue: oldNotes,
                newValue: notes ?? "",
                modifiedBy: userId
            )
        }
        
        if oldPhotoURL != photoURL ?? "" {
            HistoryHelper.recordChange(
                in: viewContext,
                scheduleId: item.id ?? UUID(),
                fieldName: "Receipt Photo",
                oldValue: oldPhotoURL.isEmpty ? "None" : "Photo",
                newValue: (photoURL ?? "").isEmpty ? "None" : "Photo",
                modifiedBy: userId
            )
        }
        
        if oldBusinessId != businessId {
            HistoryHelper.recordChange(
                in: viewContext,
                scheduleId: item.id ?? UUID(),
                fieldName: "Business",
                oldValue: oldBusinessName,
                newValue: businessName,
                modifiedBy: userId
            )
        }
        
        if oldTransactionType != transactionType {
            HistoryHelper.recordChange(
                in: viewContext,
                scheduleId: item.id ?? UUID(),
                fieldName: "Transaction Type",
                oldValue: oldTransactionType.capitalized,
                newValue: transactionType.capitalized,
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
        // Try to access through AuthAccess
        let authManager = AuthAccess.getAuthManager()
        
        if let authObj = authManager as? NSObject {
            let selector = NSSelectorFromString("getCurrentUserDisplayName")
            if authObj.responds(to: selector) {
                let result = authObj.perform(selector)
                if let name = result?.takeUnretainedValue() as? String {
                    return name
                }
            }
        }
        
        // Fallback to device name
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac User"
        #else
        return "Unknown User"
        #endif
    }
    
    // Helper function to get expense totals by category for a business
    func getExpenseTotalsByCategory(for businessId: UUID) -> [(category: String, amount: Decimal)] {
        let businessItems = getItemsForBusiness(businessId: businessId)
        let expenseItems = businessItems.filter { ($0.transactionType ?? "") == "expense" }
        
        var categoryTotals: [String: Decimal] = [:]
        
        for item in expenseItems {
            guard let category = item.category else { continue }
            let amount = item.amount?.decimalValue ?? Decimal(0)
            categoryTotals[category, default: Decimal(0)] += amount
        }
        
        return categoryTotals.map { (category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
    
    // Helper function to get income totals by category for a business
    func getIncomeTotalsByCategory(for businessId: UUID) -> [(category: String, amount: Decimal)] {
        let businessItems = getItemsForBusiness(businessId: businessId)
        let incomeItems = businessItems.filter { ($0.transactionType ?? "") == "income" }
        
        var categoryTotals: [String: Decimal] = [:]
        
        for item in incomeItems {
            guard let category = item.category else { continue }
            let amount = item.amount?.decimalValue ?? Decimal(0)
            categoryTotals[category, default: Decimal(0)] += amount
        }
        
        return categoryTotals.map { (category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
}
