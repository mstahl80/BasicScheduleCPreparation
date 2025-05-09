// Schedule+Extensions.swift
import Foundation
import CoreData

extension Schedule {
    // Computed properties for easier access
    var wrappedId: UUID {
        id ?? UUID()
    }
    
    var wrappedDate: Date {
        date ?? Date()
    }
    
    var wrappedStore: String {
        store ?? ""
    }
    
    var wrappedCategory: String {
        category ?? ""
    }
    
    var wrappedNotes: String {
        notes ?? ""
    }
    
    var wrappedPhotoURL: String {
        photoURL ?? ""
    }
    
    var wrappedCreatedAt: Date {
        createdAt ?? Date()
    }
    
    var wrappedModifiedAt: Date {
        modifiedAt ?? Date()
    }
    
    var wrappedCreatedBy: String {
        createdBy ?? ""
    }
    
    var wrappedModifiedBy: String {
        modifiedBy ?? ""
    }
    
    // Helper function to create a new Schedule item
    static func createNewEntry(
        in context: NSManagedObjectContext,
        date: Date,
        amount: Decimal,
        store: String,
        category: String,
        notes: String? = nil,
        photoURL: String? = nil,
        createdBy: String
    ) -> Schedule {
        let newItem = Schedule(context: context)
        newItem.id = UUID()
        newItem.date = date
        newItem.amount = NSDecimalNumber(decimal: amount)
        newItem.store = store
        newItem.category = category
        newItem.notes = notes
        newItem.photoURL = photoURL
        newItem.createdAt = Date()
        newItem.modifiedAt = Date()
        newItem.createdBy = createdBy
        newItem.modifiedBy = createdBy
        return newItem
    }
    
    // Helper function to update an existing Schedule item
    func update(
        date: Date? = nil,
        amount: Decimal? = nil,
        store: String? = nil,
        category: String? = nil,
        notes: String? = nil,
        photoURL: String? = nil,
        modifiedBy: String
    ) {
        if let date = date {
            self.date = date
        }
        
        if let amount = amount {
            self.amount = NSDecimalNumber(decimal: amount)
        }
        
        if let store = store {
            self.store = store
        }
        
        if let category = category {
            self.category = category
        }
        
        if let notes = notes {
            self.notes = notes
        }
        
        if let photoURL = photoURL {
            self.photoURL = photoURL
        }
        
        self.modifiedAt = Date()
        self.modifiedBy = modifiedBy
    }
}
