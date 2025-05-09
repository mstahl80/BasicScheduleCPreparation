// SummaryView.swift - Fixed for all errors
import SwiftUI
import Charts

struct SummaryView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @State private var selectedYear: Int
    @State private var availableYears: [Int] = []
    @State private var selectedMonth: Int? = nil
    @State private var dateRange: DateRange = .yearToDate
    @State private var startDate: Date = Date().startOfYear()
    @State private var endDate: Date = Date()
    @State private var showingCustomDatePicker = false
    @State private var minExpenseFilter: Double? = nil
    @State private var showExpensesAbove: Bool = false
    @State private var categoryFilter: String? = nil
    
    init(viewModel: ScheduleViewModel) {
        self.viewModel = viewModel
        
        // Initialize with current year
        let currentYear = Calendar.current.component(.year, from: Date())
        _selectedYear = State(initialValue: currentYear)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Filtering Options
                filterSection
                
                // Income chart
                incomeChartSection
                
                // Expense chart
                expenseChartSection
                
                // Summary statistics
                summaryStatisticsSection
            }
            .padding(.vertical)
        }
        .navigationTitle("Financial Summary")
        .onAppear {
            updateAvailableYears()
            viewModel.fetchScheduleItems()
        }
        // Updated onChange for newer SwiftUI versions
        .onChange(of: selectedYear) { _, _ in
            updateDateRange()
        }
        .onChange(of: selectedMonth) { _, _ in
            updateDateRange()
        }
        .onChange(of: dateRange) { _, newValue in
            if newValue == .custom {
                showingCustomDatePicker = true
            } else {
                updateDateRange()
            }
        }
        .sheet(isPresented: $showingCustomDatePicker) {
            customDatePickerView
        }
    }
    
    // Filter section
    var filterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclosureGroup("Filtering Options") {
                VStack(alignment: .leading, spacing: 15) {
                    // Date range picker
                    Picker("Date Range", selection: $dateRange) {
                        Text("Year to Date").tag(DateRange.yearToDate)
                        Text("All Year").tag(DateRange.fullYear)
                        Text("Quarter").tag(DateRange.quarter)
                        Text("Month").tag(DateRange.month)
                        Text("Custom").tag(DateRange.custom)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    // Year picker
                    HStack {
                        Text("Year:")
                        Picker("Year", selection: $selectedYear) {
                            ForEach(availableYears, id: \.self) { year in
                                Text("\(year)").tag(year)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    // Month picker (only shown if month or quarter is selected)
                    if dateRange == .month || dateRange == .quarter {
                        HStack {
                            Text(dateRange == .month ? "Month:" : "Quarter:")
                            Picker(dateRange == .month ? "Month" : "Quarter", selection: $selectedMonth) {
                                if dateRange == .month {
                                    ForEach(1...12, id: \.self) { month in
                                        Text(monthName(month)).tag(month as Int?)
                                    }
                                } else {
                                    ForEach(1...4, id: \.self) { quarter in
                                        Text("Q\(quarter)").tag(quarter as Int?)
                                    }
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                    
                    // Date range display
                    Text("Showing data from \(startDate.formatted(date: .abbreviated, time: .omitted)) to \(endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    // Category filter
                    HStack {
                        Text("Category:")
                        Picker("Category", selection: $categoryFilter) {
                            Text("All Categories").tag(nil as String?)
                            ForEach(ScheduleViewModel.categories, id: \.self) { category in
                                Text(category).tag(category as String?)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    // Expense amount filter
                    Toggle("Show expenses above:", isOn: $showExpensesAbove)
                    
                    if showExpensesAbove {
                        HStack {
                            Text("$")
                            TextField("Minimum Amount", value: $minExpenseFilter, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                // Fix: Use proper keyboardType with UIKit import
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                        }
                    }
                }
                .padding(.top, 5)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
    
    // Income chart section
    var incomeChartSection: some View {
        VStack(alignment: .leading) {
            Text("Income by Category")
                .font(.headline)
                .padding(.bottom, 5)
            
            if filteredIncomeData.isEmpty {
                Text("No income data for selected period")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(filteredIncomeData) { item in
                    BarMark(
                        x: .value("Amount", item.amount),
                        y: .value("Category", item.category)
                    )
                    .foregroundStyle(.green)
                }
                .frame(height: CGFloat(max(200, filteredIncomeData.count * 40)))
                .chartXAxisLabel("Amount ($)")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // Expense chart section
    var expenseChartSection: some View {
        VStack(alignment: .leading) {
            Text("Expenses by Category")
                .font(.headline)
                .padding(.bottom, 5)
            
            if filteredExpenseData.isEmpty {
                Text("No expense data for selected period")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(filteredExpenseData) { item in
                    BarMark(
                        x: .value("Amount", item.amount),
                        y: .value("Category", item.category)
                    )
                    .foregroundStyle(.red)
                }
                .frame(height: CGFloat(max(200, filteredExpenseData.count * 40)))
                .chartXAxisLabel("Amount ($)")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // Summary statistics section
    var summaryStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Summary Statistics")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Income:")
                    Text("Total Expenses:")
                    Text("Net Profit:")
                    Text("Number of Transactions:")
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("$\(totalIncome, specifier: "%.2f")")
                        .foregroundColor(.green)
                    Text("$\(totalExpenses, specifier: "%.2f")")
                        .foregroundColor(.red)
                    Text("$\(totalIncome - totalExpenses, specifier: "%.2f")")
                        .foregroundColor(totalIncome - totalExpenses >= 0 ? .green : .red)
                    Text("\(filteredItems.count)")
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // Custom date picker view
    var customDatePickerView: some View {
        NavigationStack {
            Form {
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
            }
            .navigationTitle("Select Date Range")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        // Revert to previous date range
                        updateDateRange()
                        showingCustomDatePicker = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        showingCustomDatePicker = false
                    }
                }
            }
        }
    }
    
    // Data structure for chart
    struct ChartData: Identifiable {
        let id = UUID()
        let category: String
        let amount: Double
    }
    
    // Filtered items based on all criteria
    var filteredItems: [Schedule] {
        viewModel.scheduleItems.filter { item in
            // Date range filter
            let itemDate = item.wrappedDate
            let inDateRange = (itemDate >= startDate && itemDate <= endDate)
            
            // Category filter
            let matchesCategory = categoryFilter == nil || item.wrappedCategory == categoryFilter
            
            // Amount filter for expenses
            let isIncome = item.wrappedCategory == "Gross receipts or sales"
            let amount = item.amount?.doubleValue ?? 0
            let passesAmountFilter = !showExpensesAbove || isIncome ||
                                    (minExpenseFilter == nil || amount >= minExpenseFilter!)
            
            return inDateRange && matchesCategory && passesAmountFilter
        }
    }
    
    // Calculate income data
    var filteredIncomeData: [ChartData] {
        let incomeCategory = "Gross receipts or sales"
        
        // Filter for income items
        let incomeItems = filteredItems.filter { item in
            return item.wrappedCategory == incomeCategory
        }
        
        // Just one category for income
        let totalAmount = incomeItems.reduce(0.0) { sum, item in
            sum + (item.amount?.doubleValue ?? 0)
        }
        
        return [ChartData(category: incomeCategory, amount: totalAmount)]
    }
    
    // Calculate expense data
    var filteredExpenseData: [ChartData] {
        let incomeCategory = "Gross receipts or sales"
        
        // Filter for expense items
        let expenseItems = filteredItems.filter { item in
            return item.wrappedCategory != incomeCategory
        }
        
        // Group by category and sum amounts
        var categoryAmounts: [String: Double] = [:]
        
        for item in expenseItems {
            let category = item.wrappedCategory
            let amount = item.amount?.doubleValue ?? 0
            categoryAmounts[category, default: 0] += amount
        }
        
        // Convert to chart data format, sorting by amount descending
        return categoryAmounts.map { category, amount in
            ChartData(category: category, amount: amount)
        }.sorted { $0.amount > $1.amount }
    }
    
    // Calculate totals
    var totalIncome: Double {
        filteredIncomeData.reduce(0) { $0 + $1.amount }
    }
    
    var totalExpenses: Double {
        filteredExpenseData.reduce(0) { $0 + $1.amount }
    }
    
    // Update available years based on data
    private func updateAvailableYears() {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        // Get all years from items
        let years = Set(viewModel.scheduleItems.map { item in
            calendar.component(.year, from: item.wrappedDate)
        })
        
        if years.isEmpty {
            // If no data, just use current year
            availableYears = [currentYear]
            selectedYear = currentYear
        } else {
            availableYears = Array(years).sorted()
            
            // Set selected year to current year if available, otherwise to the most recent year
            if years.contains(currentYear) {
                selectedYear = currentYear
            } else if let maxYear = years.max() {
                selectedYear = maxYear
            } else {
                // This should never happen if years is not empty, but added as a fallback
                selectedYear = currentYear
            }
        }
        
        updateDateRange()
    }
    
    // Update date range based on selected filters
    private func updateDateRange() {
        let calendar = Calendar.current
        switch dateRange {
        case .yearToDate:
            let currentYear = calendar.component(.year, from: Date())
            if selectedYear == currentYear {
                startDate = Date().startOfYear()
                endDate = Date()
            } else {
                startDate = Date.from(year: selectedYear, month: 1, day: 1)
                endDate = Date.from(year: selectedYear, month: 12, day: 31)
            }
            
        case .fullYear:
            startDate = Date.from(year: selectedYear, month: 1, day: 1)
            endDate = Date.from(year: selectedYear, month: 12, day: 31)
            
        case .quarter:
            let quarter = selectedMonth ?? 1
            let startMonth = (quarter - 1) * 3 + 1
            let endMonth = startMonth + 2
            
            startDate = Date.from(year: selectedYear, month: startMonth, day: 1)
            
            let endDay: Int
            if endMonth == 2 {
                endDay = Date.from(year: selectedYear, month: endMonth, day: 1).lastDayOfMonth()
            } else if [4, 6, 9, 11].contains(endMonth) {
                endDay = 30
            } else {
                endDay = 31
            }
            
            endDate = Date.from(year: selectedYear, month: endMonth, day: endDay)
            
        case .month:
            let month = selectedMonth ?? 1
            startDate = Date.from(year: selectedYear, month: month, day: 1)
            
            let endDay: Int
            if month == 2 {
                endDay = startDate.lastDayOfMonth()
            } else if [4, 6, 9, 11].contains(month) {
                endDay = 30
            } else {
                endDay = 31
            }
            
            endDate = Date.from(year: selectedYear, month: month, day: endDay)
            
        case .custom:
            // Custom dates are set directly by the user, no need to update
            break
        }
    }
    
    // Helper to get month name
    private func monthName(_ month: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.year = 2000 // Arbitrary year
        dateComponents.month = month
        dateComponents.day = 1
        
        if let date = calendar.date(from: dateComponents) {
            return dateFormatter.string(from: date)
        }
        
        return "Unknown"
    }
    
    // Date range options
    enum DateRange {
        case yearToDate
        case fullYear
        case quarter
        case month
        case custom
    }
}

// MARK: - Date Extensions

extension Date {
    func startOfYear() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year], from: self)
        components.month = 1
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        return calendar.date(from: components) ?? self
    }
    
    func lastDayOfMonth() -> Int {
        let calendar = Calendar.current
        if let lastDay = calendar.range(of: .day, in: .month, for: self)?.count {
            return lastDay
        }
        return 28 // Fallback for February in case of errors
    }
    
    static func from(year: Int, month: Int, day: Int) -> Date {
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        
        return Calendar.current.date(from: dateComponents) ?? Date()
    }
}
