// SummaryDataUtils.swift
// Data utilities for filtering and processing data in the Summary view
import Foundation

struct SummaryChartData: Identifiable {
    let id = UUID()
    let category: String
    let amount: Decimal
}

class SummaryDataManager {
    // Filter items based on all criteria
    static func filteredItems(
        from items: [Schedule],
        dateRange: (start: Date, end: Date),
        categoryFilter: String? = nil,
        showExpensesAbove: Bool = false,
        minExpenseFilter: Double? = nil
    ) -> [Schedule] {
        return items.filter { item in
            // Date range filter
            let itemDate = item.date ?? Date()
            let inDateRange = (itemDate >= dateRange.start && itemDate <= dateRange.end)
            
            // Category filter
            let matchesCategory = categoryFilter == nil || item.category == categoryFilter
            
            // Amount filter for expenses
            let isIncome = (item.transactionType ?? "") == "income"
            let amount = item.amount?.doubleValue ?? 0
            let passesAmountFilter = !showExpensesAbove || isIncome ||
                                    (minExpenseFilter == nil || amount >= minExpenseFilter!)
            
            return inDateRange && matchesCategory && passesAmountFilter
        }
    }
    
    // Filter items for a specific business
    static func filteredItemsForBusiness(_ businessId: UUID, from items: [Schedule]) -> [Schedule] {
        return items.filter { item in
            // Check if businessId is not nil and convert to UUID for comparison
            if let businessIdObj = item.businessId {
                // Convert NSUUID to string and then to UUID for comparison
                let idString = businessIdObj.uuidString
                return UUID(uuidString: idString) == businessId
            }
            return false
        }
    }
    
    // Calculate income for a business
    static func incomeForBusiness(_ businessId: UUID, from items: [Schedule]) -> Decimal {
        let businessItems = filteredItemsForBusiness(businessId, from: items)
        let incomeItems = businessItems.filter { ($0.transactionType ?? "") == "income" }
        
        return incomeItems.reduce(Decimal(0)) { sum, item in
            sum + (item.amount?.decimalValue ?? Decimal(0))
        }
    }
    
    // Calculate expenses for a business
    static func expensesForBusiness(_ businessId: UUID, from items: [Schedule]) -> Decimal {
        let businessItems = filteredItemsForBusiness(businessId, from: items)
        let expenseItems = businessItems.filter { ($0.transactionType ?? "") == "expense" }
        
        return expenseItems.reduce(Decimal(0)) { sum, item in
            sum + (item.amount?.decimalValue ?? Decimal(0))
        }
    }
    
    // Calculate income by category for a business
    static func incomeByCategory(for businessId: UUID, from items: [Schedule]) -> [SummaryChartData] {
        let businessItems = filteredItemsForBusiness(businessId, from: items)
        let incomeItems = businessItems.filter { ($0.transactionType ?? "") == "income" }
        
        var categoryTotals: [String: Decimal] = [:]
        
        for item in incomeItems {
            guard let category = item.category else { continue }
            let amount = item.amount?.decimalValue ?? Decimal(0)
            categoryTotals[category, default: Decimal(0)] += amount
        }
        
        return categoryTotals.map { category, amount in
            SummaryChartData(category: category, amount: amount)
        }.sorted { $0.amount > $1.amount }
    }
    
    // Calculate expenses by category for a business
    static func expensesByCategory(for businessId: UUID, from items: [Schedule]) -> [SummaryChartData] {
        let businessItems = filteredItemsForBusiness(businessId, from: items)
        let expenseItems = businessItems.filter { ($0.transactionType ?? "") == "expense" }
        
        var categoryTotals: [String: Decimal] = [:]
        
        for item in expenseItems {
            guard let category = item.category else { continue }
            let amount = item.amount?.decimalValue ?? Decimal(0)
            categoryTotals[category, default: Decimal(0)] += amount
        }
        
        return categoryTotals.map { category, amount in
            SummaryChartData(category: category, amount: amount)
        }.sorted { $0.amount > $1.amount }
    }
    
    // Calculate total income for all businesses
    static func totalIncomeForAllBusinesses(businesses: [Business], from items: [Schedule]) -> Decimal {
        businesses.compactMap { $0.id }.reduce(Decimal(0)) { sum, businessId in
            sum + incomeForBusiness(businessId, from: items)
        }
    }
    
    // Calculate total expenses for all businesses
    static func totalExpensesForAllBusinesses(businesses: [Business], from items: [Schedule]) -> Decimal {
        businesses.compactMap { $0.id }.reduce(Decimal(0)) { sum, businessId in
            sum + expensesForBusiness(businessId, from: items)
        }
    }
    
    // Get expense categories by transaction type and frequency
    static func getTopCategories(
        for transactionType: String,
        from items: [Schedule],
        businessId: UUID? = nil,
        limit: Int = 5
    ) -> [SummaryChartData] {
        // Filter by transaction type
        let filteredItems = items.filter { ($0.transactionType ?? "") == transactionType }
        
        // Filter by business if needed
        let businessItems: [Schedule]
        if let businessId = businessId {
            businessItems = filteredItems.filter { item in
                // Check if businessId is not nil
                if let businessIdObj = item.businessId {
                    // Convert to string and then to UUID for comparison
                    let idString = businessIdObj.uuidString
                    return UUID(uuidString: idString) == businessId
                }
                return false
            }
        } else {
            businessItems = filteredItems
        }
        
        // Group by category
        var categoryTotals: [String: Decimal] = [:]
        
        for item in businessItems {
            guard let category = item.category else { continue }
            let amount = item.amount?.decimalValue ?? Decimal(0)
            categoryTotals[category, default: Decimal(0)] += amount
        }
        
        // Convert to array and sort
        let chartData = categoryTotals.map { category, amount in
            SummaryChartData(category: category, amount: amount)
        }.sorted { $0.amount > $1.amount }
        
        // Return top categories
        if limit > 0 && chartData.count > limit {
            return Array(chartData.prefix(limit))
        } else {
            return chartData
        }
    }
    
    // Calculate monthly totals for a business
    static func monthlyTotals(
        for businessId: UUID,
        transactionType: String,
        year: Int,
        from items: [Schedule]
    ) -> [(month: Int, amount: Decimal)] {
        let calendar = Calendar.current
        
        // Filter items by business
        let businessItems = filteredItemsForBusiness(businessId, from: items)
        
        // Filter by transaction type and year
        let filteredItems = businessItems.filter { item in
            guard let date = item.date else { return false }
            let itemYear = calendar.component(.year, from: date)
            return (item.transactionType ?? "") == transactionType && itemYear == year
        }
        
        // Group by month
        var monthlyTotals: [Int: Decimal] = [:]
        
        for item in filteredItems {
            guard let date = item.date else { continue }
            let month = calendar.component(.month, from: date)
            let amount = item.amount?.decimalValue ?? Decimal(0)
            monthlyTotals[month, default: Decimal(0)] += amount
        }
        
        // Convert to array and sort by month
        return monthlyTotals.map { month, amount in
            (month: month, amount: amount)
        }.sorted { $0.month < $1.month }
    }
    
    // Get quarterly data for a business
    static func quarterlyTotals(
        for businessId: UUID,
        transactionType: String,
        year: Int,
        from items: [Schedule]
    ) -> [(quarter: Int, amount: Decimal)] {
        let monthlyData = monthlyTotals(
            for: businessId,
            transactionType: transactionType,
            year: year,
            from: items
        )
        
        // Group by quarter
        var quarterlyTotals: [Int: Decimal] = [:]
        
        for (month, amount) in monthlyData {
            let quarter = (month - 1) / 3 + 1
            quarterlyTotals[quarter, default: Decimal(0)] += amount
        }
        
        // Convert to array and sort by quarter
        return quarterlyTotals.map { quarter, amount in
            (quarter: quarter, amount: amount)
        }.sorted { $0.quarter < $1.quarter }
    }
}
