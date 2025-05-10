// Fixed SummaryView.swift - Resolves all compiler errors
import SwiftUI
import Charts


// MARK: - Chart Data Structure
struct ChartData: Identifiable {
    let id = UUID()
    let category: String
    let amount: Double
}

// MARK: - SummaryView
struct SummaryView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @StateObject private var businessViewModel = BusinessViewModel()
    
    enum DateRange {
        case yearToDate
        case fullYear
        case quarter
        case month
        case custom
    }
    
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
    
    // Business selection
    @State private var selectedBusinessId: UUID? = nil
    @State private var showingAddBusinessSheet = false
    
    // Define updateDateRange method BEFORE it's called
    func updateDateRange() {
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
    
    init(viewModel: ScheduleViewModel) {
        self.viewModel = viewModel
        
        // Initialize with current year
        let currentYear = Calendar.current.component(.year, from: Date())
        _selectedYear = State(initialValue: currentYear)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Business selection
                businessSelectorSection
                
                // Filtering Options
                filterSection
                
                if businessViewModel.businesses.isEmpty {
                    noBusinessesView
                } else if let businessId = selectedBusinessId {
                    // Selected business view
                    businessSummaryContent(for: businessId)
                } else {
                    // All businesses overview
                    allBusinessesOverview
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Financial Summary")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddBusinessSheet = true
                } label: {
                    Label("Add Business", systemImage: "plus.circle")
                }
            }
        }
        .onAppear {
            updateAvailableYears()
            viewModel.fetchScheduleItems()
            businessViewModel.fetchBusinesses()
            
            // Auto-select the first business if there's only one
            if businessViewModel.businesses.count == 1,
               let firstBusiness = businessViewModel.businesses.first,
               let firstBusinessId = firstBusiness.id {
                selectedBusinessId = firstBusinessId
            }
        }
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
        .sheet(isPresented: $showingAddBusinessSheet) {
            addBusinessView
        }
    }
    
    // MARK: - View Components
    
    // Business selector section
    private var businessSelectorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select Business")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // All businesses option
                    businessCard(id: nil, name: "All Businesses")
                    
                    // Individual businesses
                    ForEach(businessViewModel.businesses, id: \.id) { business in
                        businessCard(id: business.id, name: business.name ?? "Unknown")
                    }
                    
                    // Add business button
                    Button {
                        showingAddBusinessSheet = true
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                            
                            Text("Add Business")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .frame(width: 120, height: 90)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // Business card for selector
    private func businessCard(id: UUID?, name: String) -> some View {
        Button {
            withAnimation {
                selectedBusinessId = id
            }
        } label: {
            VStack(alignment: .center, spacing: 10) {
                Image(systemName: "building.2")
                    .font(.system(size: 24))
                
                Text(name)
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .frame(width: 120)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(id == selectedBusinessId ? Color.blue.opacity(0.1) : Color(.systemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(id == selectedBusinessId ? Color.blue : Color.clear, lineWidth: 2)
            )
            .foregroundColor(id == selectedBusinessId ? .blue : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // No businesses view
    private var noBusinessesView: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("No Businesses Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Start by adding a business to track your income and expenses.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Button {
                showingAddBusinessSheet = true
            } label: {
                Label("Add Business", systemImage: "plus.circle.fill")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
        .padding()
    }
    
    // Add Business View
    private var addBusinessView: some View {
        let userId = viewModel.getCurrentUserName()
        
        return NavigationStack {
            AddBusinessForm(businessViewModel: businessViewModel, userId: userId) { newBusiness in
                if let businessId = newBusiness.id {
                    selectedBusinessId = businessId
                }
            }
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
                            
                            // FIX: Breaking up complex expressions
                            Group {
                                Text("Income Categories").tag("" as String?)
                                    .disabled(true)
                                    .foregroundColor(.secondary)
                                
                                ForEach(ScheduleViewModel.incomeCategories, id: \.self) { category in
                                    Text(category).tag(category as String?)
                                }
                            }
                            
                            Group {
                                Text("Expense Categories").tag("" as String?)
                                    .disabled(true)
                                    .foregroundColor(.secondary)
                                    
                                ForEach(ScheduleViewModel.expenseCategories, id: \.self) { category in
                                    Text(category).tag(category as String?)
                                }
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
    
    // Content for a specific business
    private func businessSummaryContent(for businessId: UUID) -> some View {
        let businessName = businessViewModel.getBusiness(by: businessId)?.name ?? "Selected Business"
        
        return VStack(alignment: .leading, spacing: 20) {
            // Business overview
            businessOverviewCard(
                name: businessName,
                businessId: businessId
            )
            
            // Income chart
            incomeChartSection(for: businessId)
            
            // Expense chart
            expenseChartSection(for: businessId)
            
            // Summary statistics
            summaryStatisticsSection(for: businessId)
        }
    }
    
    // Business overview card
    private func businessOverviewCard(name: String, businessId: UUID) -> some View {
        let income = filteredIncomeForBusiness(businessId)
        let expenses = filteredExpensesForBusiness(businessId)
        let profit = income - expenses
        
        return VStack(alignment: .leading, spacing: 16) {
            Text(name)
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            HStack(spacing: 20) {
                // Income card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Income")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .center) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.green)
                        
                        Text(income, format: .currency(code: "USD"))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
                
                // Expenses card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Expenses")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .center) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                        
                        Text(expenses, format: .currency(code: "USD"))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                )
            }
            .padding(.horizontal)
            
            // Profit card
            VStack(alignment: .leading, spacing: 8) {
                Text("Net Profit/Loss")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .center) {
                    Image(systemName: profit >= 0 ? "arrow.up.forward.circle.fill" : "arrow.down.forward.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(profit >= 0 ? .green : .red)
                    
                    Text(profit, format: .currency(code: "USD"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(profit >= 0 ? .green : .red)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
            .padding(.horizontal)
        }
    }
    
    // Income chart section
    private func incomeChartSection(for businessId: UUID) -> some View {
        let incomeData = filteredIncomeData(for: businessId)
        
        return VStack(alignment: .leading) {
            Text("Income by Category")
                .font(.headline)
                .padding(.bottom, 5)
                .padding(.horizontal)
            
            if incomeData.isEmpty {
                Text("No income data for selected period")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
            } else {
                Chart {
                    ForEach(incomeData) { item in
                        BarMark(
                            x: .value("Amount", item.amount),
                            y: .value("Category", item.category)
                        )
                        .foregroundStyle(.green)
                    }
                }
                .frame(height: CGFloat(max(200, incomeData.count * 40)))
                .chartXAxisLabel("Amount ($)")
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                )
                .padding(.horizontal)
            }
        }
    }
    
    // Expense chart section
    private func expenseChartSection(for businessId: UUID) -> some View {
        let expenseData = filteredExpenseData(for: businessId)
        
        return VStack(alignment: .leading) {
            Text("Expenses by Category")
                .font(.headline)
                .padding(.bottom, 5)
                .padding(.horizontal)
            
            if expenseData.isEmpty {
                Text("No expense data for selected period")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
            } else {
                Chart {
                    ForEach(expenseData) { item in
                        BarMark(
                            x: .value("Amount", item.amount),
                            y: .value("Category", item.category)
                        )
                        .foregroundStyle(.red)
                    }
                }
                .frame(height: CGFloat(max(200, expenseData.count * 40)))
                .chartXAxisLabel("Amount ($)")
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                )
                .padding(.horizontal)
            }
        }
    }
    
    // Summary statistics section
    private func summaryStatisticsSection(for businessId: UUID) -> some View {
        let income = filteredIncomeForBusiness(businessId)
        let expenses = filteredExpensesForBusiness(businessId)
        let profit = income - expenses
        let businessItems = filteredItemsForBusiness(businessId)
        
        return VStack(alignment: .leading, spacing: 10) {
            Text("Summary Statistics")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Total Income:")
                        Text("Total Expenses:")
                        Text("Net Profit:")
                        Text("Number of Transactions:")
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(income, format: .currency(code: "USD"))
                            .foregroundColor(.green)
                        Text(expenses, format: .currency(code: "USD"))
                            .foregroundColor(.red)
                        Text(profit, format: .currency(code: "USD"))
                            .foregroundColor(profit >= 0 ? .green : .red)
                        Text("\(businessItems.count)")
                    }
                }
                
                // Profit margin
                if income > 0 {
                    let profitMargin = profit / income * 100
                    HStack {
                        Text("Profit Margin:")
                        Spacer()
                        Text(profitMargin, format: .percent.precision(.fractionLength(1)))
                            .foregroundColor(profitMargin >= 0 ? .green : .red)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .padding(.horizontal)
        }
    }
    
    // All businesses overview
    private var allBusinessesOverview: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Businesses cards grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(businessViewModel.businesses, id: \.id) { business in
                    if let businessId = business.id {
                        Button {
                            selectedBusinessId = businessId
                        } label: {
                            businessSummaryCard(
                                name: business.name ?? "Unknown",
                                businessId: businessId
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal)
            
            // Overall summary
            overallSummarySection
        }
    }
    
    // Business summary card for all businesses view
    private func businessSummaryCard(name: String, businessId: UUID) -> some View {
        let income = filteredIncomeForBusiness(businessId)
        let expenses = filteredExpensesForBusiness(businessId)
        let profit = income - expenses
        
        return VStack(alignment: .leading, spacing: 12) {
            Text(name)
                .font(.headline)
                .lineLimit(1)
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Label {
                        Text("Income")
                    } icon: {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.green)
                    }
                    .font(.caption)
                    
                    Label {
                        Text("Expense")
                    } icon: {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.red)
                    }
                    .font(.caption)
                    
                    Label {
                        Text("Profit")
                    } icon: {
                        Image(systemName: profit >= 0 ? "plus.circle.fill" : "minus.circle.fill")
                            .foregroundColor(profit >= 0 ? .green : .red)
                    }
                    .font(.caption)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text(income, format: .currency(code: "USD"))
                        .font(.caption)
                        .foregroundColor(.green)
                        
                    Text(expenses, format: .currency(code: "USD"))
                        .font(.caption)
                        .foregroundColor(.red)
                        
                    Text(profit, format: .currency(code: "USD"))
                        .font(.caption)
                        .foregroundColor(profit >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    // Overall summary for all businesses
    private var overallSummarySection: some View {
        // Calculate totals across all businesses
        let totalIncome = businessViewModel.businesses.compactMap { $0.id }.reduce(Decimal(0)) { sum, businessId in
            sum + filteredIncomeForBusiness(businessId)
        }
        
        let totalExpenses = businessViewModel.businesses.compactMap { $0.id }.reduce(Decimal(0)) { sum, businessId in
            sum + filteredExpensesForBusiness(businessId)
        }
        
        let totalProfit = totalIncome - totalExpenses
        
        return VStack(alignment: .leading, spacing: 10) {
            Text("Overall Summary")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Total Income (All Businesses):")
                        Text("Total Expenses (All Businesses):")
                        Text("Net Profit (All Businesses):")
                        Text("Number of Businesses:")
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text(totalIncome, format: .currency(code: "USD"))
                            .foregroundColor(.green)
                        Text(totalExpenses, format: .currency(code: "USD"))
                            .foregroundColor(.red)
                        Text(totalProfit, format: .currency(code: "USD"))
                            .foregroundColor(totalProfit >= 0 ? .green : .red)
                        Text("\(businessViewModel.businesses.count)")
                    }
                }
                
                // Profit margin
                if totalIncome > 0 {
                    let profitMargin = totalProfit / totalIncome * 100
                    HStack {
                        Text("Overall Profit Margin:")
                        Spacer()
                        Text(profitMargin, format: .percent.precision(.fractionLength(1)))
                            .foregroundColor(profitMargin >= 0 ? .green : .red)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
            )
            .padding(.horizontal)
        }
    }
    
    // Custom date picker view
    private var customDatePickerView: some View {
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
        .presentationDetents([.medium])
    }
    
    // MARK: - Data Helpers
    
    // Filtered items based on all criteria
    var filteredItems: [Schedule] {
        viewModel.scheduleItems.filter { item in
            // Date range filter
            let itemDate = item.date ?? Date()
            let inDateRange = (itemDate >= startDate && itemDate <= endDate)
            
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
    
    // Filtered items for a specific business
    func filteredItemsForBusiness(_ businessId: UUID) -> [Schedule] {
        return filteredItems.filter { item in
            guard let itemBusinessIdObj = item.businessId as? NSUUID else { return false }
            return UUID(uuidString: itemBusinessIdObj.uuidString) == businessId
        }
    }
    
    // Calculate income total for a business
    func filteredIncomeForBusiness(_ businessId:
                                   UUID) -> Decimal {
                                           let businessItems = filteredItemsForBusiness(businessId)
                                           let incomeItems = businessItems.filter { ($0.transactionType ?? "") == "income" }
                                           
                                           return incomeItems.reduce(Decimal(0)) { sum, item in
                                               sum + (item.amount?.decimalValue ?? Decimal(0))
                                           }
                                       }
                                       
                                       // Calculate expenses total for a business
                                       func filteredExpensesForBusiness(_ businessId: UUID) -> Decimal {
                                           let businessItems = filteredItemsForBusiness(businessId)
                                           let expenseItems = businessItems.filter { ($0.transactionType ?? "") == "expense" }
                                           
                                           return expenseItems.reduce(Decimal(0)) { sum, item in
                                               sum + (item.amount?.decimalValue ?? Decimal(0))
                                           }
                                       }
                                       
                                       // Calculate filtered income data for a business
                                       func filteredIncomeData(for businessId: UUID) -> [ChartData] {
                                           let businessItems = filteredItemsForBusiness(businessId)
                                           let incomeItems = businessItems.filter { ($0.transactionType ?? "") == "income" }
                                           
                                           // Group by category and sum amounts
                                           var categoryAmounts: [String: Double] = [:]
                                           
                                           for item in incomeItems {
                                               guard let category = item.category else { continue }
                                               let amount = item.amount?.doubleValue ?? 0
                                               categoryAmounts[category, default: 0] += amount
                                           }
                                           
                                           // Convert to chart data format, sorting by amount descending
                                           return categoryAmounts.map { category, amount in
                                               ChartData(category: category, amount: amount)
                                           }.sorted { $0.amount > $1.amount }
                                       }
                                       
                                       // Calculate filtered expense data for a business
                                       func filteredExpenseData(for businessId: UUID) -> [ChartData] {
                                           let businessItems = filteredItemsForBusiness(businessId)
                                           let expenseItems = businessItems.filter { ($0.transactionType ?? "") == "expense" }
                                           
                                           // Group by category and sum amounts
                                           var categoryAmounts: [String: Double] = [:]
                                           
                                           for item in expenseItems {
                                               guard let category = item.category else { continue }
                                               let amount = item.amount?.doubleValue ?? 0
                                               categoryAmounts[category, default: 0] += amount
                                           }
                                           
                                           // Convert to chart data format, sorting by amount descending
                                           return categoryAmounts.map { category, amount in
                                               ChartData(category: category, amount: amount)
                                           }.sorted { $0.amount > $1.amount }
                                       }
                                       
                                       // Update available years based on data
                                       func updateAvailableYears() {
                                           let calendar = Calendar.current
                                           let currentYear = calendar.component(.year, from: Date())
                                           
                                           // Get all years from items
                                           let years = Set(viewModel.scheduleItems.compactMap { item in
                                               guard let date = item.date else { return nil }
                                               return calendar.component(.year, from: date)
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
                                       
                                       // Helper to get month name
                                       func monthName(_ month: Int) -> String {
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
                                   }

                                   // MARK: - Add Business Form
                                   struct AddBusinessForm: View {
                                       @ObservedObject var businessViewModel: BusinessViewModel
                                       @State private var businessName = ""
                                       @State private var businessType = BusinessViewModel.businessTypes.first ?? ""
                                       @State private var showingError = false
                                       @State private var errorMessage = ""
                                       @Environment(\.dismiss) private var dismiss
                                       @FocusState private var isBusinessNameFocused: Bool
                                       
                                       let userId: String
                                       var onBusinessCreated: ((Business) -> Void)?
                                       
                                       var body: some View {
                                           Form {
                                               Section("Business Information") {
                                                   TextField("Business Name", text: $businessName)
                                                       .focused($isBusinessNameFocused)
                                                   
                                                   Picker("Business Type", selection: $businessType) {
                                                       ForEach(BusinessViewModel.businessTypes, id: \.self) { type in
                                                           Text(type).tag(type)
                                                       }
                                                   }
                                                   .pickerStyle(MenuPickerStyle())
                                               }
                                               
                                               Section {
                                                   Button("Add Business") {
                                                       addBusiness()
                                                   }
                                                   .disabled(businessName.isEmpty)
                                                   .frame(maxWidth: .infinity, alignment: .center)
                                                   .foregroundColor(.blue)
                                               }
                                           }
                                           .navigationTitle("Add Business")
                                           .toolbar {
                                               ToolbarItem(placement: .cancellationAction) {
                                                   Button("Cancel") {
                                                       dismiss()
                                                   }
                                               }
                                               
                                               ToolbarItem(placement: .confirmationAction) {
                                                   Button("Save") {
                                                       addBusiness()
                                                   }
                                                   .disabled(businessName.isEmpty)
                                               }
                                           }
                                           .alert("Error", isPresented: $showingError) {
                                               Button("OK", role: .cancel) { }
                                           } message: {
                                               Text(errorMessage)
                                           }
                                           .onAppear {
                                               isBusinessNameFocused = true
                                           }
                                       }
                                       
                                       func addBusiness() {
                                           guard !businessName.isEmpty else { return }
                                           
                                           // Check if business name already exists
                                           if businessViewModel.doesBusinessExist(name: businessName) {
                                               errorMessage = "A business with this name already exists."
                                               showingError = true
                                               return
                                           }
                                           
                                           // Add the business
                                           businessViewModel.addBusiness(name: businessName, businessType: businessType, userId: userId) { newBusiness in
                                               // Call the completion handler
                                               onBusinessCreated?(newBusiness)
                                               
                                               // Reset form fields
                                               businessName = ""
                                               businessType = BusinessViewModel.businessTypes.first ?? ""
                                               
                                               // Close the sheet
                                               dismiss()
                                           }
                                       }
                                   }

                                   // MARK: - Preview Provider
                                   #if DEBUG
                                   struct SummaryView_Previews: PreviewProvider {
                                       static var previews: some View {
                                           NavigationStack {
                                               SummaryView(viewModel: ScheduleViewModel())
                                           }
                                       }
                                   }
                                   #endif
