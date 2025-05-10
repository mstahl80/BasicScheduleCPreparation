// BusinessViewModel.swift
import Foundation
import CoreData
import Combine

class BusinessViewModel: ObservableObject {
    @Published var businesses: [Business] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var viewContext: NSManagedObjectContext {
        // Always use the current container's view context
        return PersistenceController.shared.container.viewContext
    }
    
    // Business types
    static let businessTypes = [
        "Sole Proprietorship",
        "LLC",
        "Partnership",
        "S Corporation",
        "C Corporation",
        "Other"
    ]
    
    init() {
        fetchBusinesses()
        setupObservers()
    }
    
    private func setupObservers() {
        // Listen for Core Data remote change notifications
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.fetchBusinesses()
                }
            }
            .store(in: &cancellables)
        
        // Listen for user change notifications
        NotificationCenter.default.publisher(for: Notification.Name("UserDidChange"))
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.fetchBusinesses()
                }
            }
            .store(in: &cancellables)
        
        // Listen for container change notifications
        NotificationCenter.default.publisher(for: Notification.Name("StoreContainerChanged"))
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.fetchBusinesses()
                }
            }
            .store(in: &cancellables)
    }
    
    func fetchBusinesses() {
        isLoading = true
        
        let request = NSFetchRequest<Business>(entityName: "Business")
        let sortDescriptor = NSSortDescriptor(keyPath: \Business.name, ascending: true)
        request.sortDescriptors = [sortDescriptor]
        
        do {
            businesses = try viewContext.fetch(request)
            print("Fetched \(businesses.count) businesses")
            isLoading = false
        } catch {
            errorMessage = "Failed to fetch businesses: \(error.localizedDescription)"
            print("Error fetching businesses: \(error)")
            isLoading = false
        }
    }
    
    // Add a new business - modified to create business directly
    func addBusiness(
        name: String,
        businessType: String? = nil,
        userId: String,
        completion: ((Business) -> Void)? = nil
    ) {
        // Create a new business directly
        let newBusiness = Business(context: viewContext)
        newBusiness.id = UUID()
        newBusiness.name = name
        newBusiness.businessType = businessType
        newBusiness.createdAt = Date()
        newBusiness.createdBy = userId
        newBusiness.isActive = true
        
        // Save the context
        do {
            try viewContext.save()
            fetchBusinesses() // Refresh the list
            completion?(newBusiness)
        } catch {
            errorMessage = "Failed to save new business: \(error.localizedDescription)"
            print("Error saving new business: \(error)")
        }
    }
    
    // Update an existing business
    func updateBusiness(
        _ business: Business,
        name: String,
        businessType: String? = nil
    ) {
        business.name = name
        business.businessType = businessType
        
        // Save the context
        do {
            try viewContext.save()
            fetchBusinesses() // Refresh the list
        } catch {
            errorMessage = "Failed to update business: \(error.localizedDescription)"
            print("Error updating business: \(error)")
        }
    }
    
    // Delete a business
    func deleteBusiness(_ business: Business) {
        viewContext.delete(business)
        
        do {
            try viewContext.save()
            fetchBusinesses() // Refresh the list
        } catch {
            errorMessage = "Failed to delete business: \(error.localizedDescription)"
            print("Error deleting business: \(error)")
        }
    }
    
    // Check if business name exists
    func doesBusinessExist(name: String) -> Bool {
        return businesses.contains { ($0.name ?? "").lowercased() == name.lowercased() }
    }
    
    // Get a business by ID
    func getBusiness(by id: UUID) -> Business? {
        return businesses.first { $0.id == id }
    }
}
