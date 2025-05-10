// ScheduleViewModel.swift - Updated to handle container changes
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
    
    func getCurrentUserName() -> String {
        return UserAuthManager.shared.getCurrentUserDisplayName()
    }
    
    // Rest of the methods remain the same, using the dynamic viewContext property
    // ...
}
