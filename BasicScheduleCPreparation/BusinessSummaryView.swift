// BusinessSummaryView.swift
import SwiftUI
import Charts

struct BusinessSummaryView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @ObservedObject var businessViewModel: BusinessViewModel
    @Binding var selectedBusinessId: UUID?
    
    @State private var selectedDateRange: DateRange = .yearToDate
    @State private var startDate: Date = Date().startOfYear()
    @State private var endDate: Date = Date()
    @State private var showingCustomDatePicker = false
    
    enum DateRange {
        case yearToDate
        case fullYear
        case quarter
        case month
        case custom
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Business selector
                businessSelectorSection
                
                // Date range selector
                dateRangeSection
                
                if let businessId = selectedBusinessId {
                    // Overview card
                    businessOverviewCard(for: businessId)
                    
                    // Income chart
                    incomeChartSection(for: businessId)
                    
                    // Expense chart
                    expenseChartSection(for: businessId)
                    
                    // Summary statistics
                    summaryStatisticsSection(for: businessId)
                } else {
                    // All businesses summary
                    allBusinessesSummarySection
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingCustomDatePicker) {
            customDatePickerView
        }
        .onAppear {
            updateDateRange()
        }
    }
    
    // Business selector
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
    
    // Date range selector
    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date Range")
                .font(.headline)
                .padding(.horizontal)
            
            Picker("Date Range", selection: $selectedDateRange) {
                Text("Year to Date").tag(DateRange.yearToDate)
                Text("Full Year").tag(DateRange.fullYear)
                Text("Last Quarter").tag(DateRange.quarter)
                Text("Last Month").tag(DateRange.month)
                Text("Custom").tag(DateRange.custom)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedDateRange) { _, newValue in
                if newValue == .custom {
                    showingCustomDatePicker = true
                } else {
                    updateDateRange()
                }
            }
            .padding(.horizontal)
            
            Text("Showing data from \(startDate.formatted(date: .abbreviated, time: .omitted)) to \(endDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }
    
    // Business overview card
    private func businessOverviewCard(for businessId: UUID) -> some View {
        let businessName = businessViewModel.getBusiness(by: businessId)?.name ?? "Selected Business"
        let income = getIncomeForBusiness(businessId)
        let expenses = getExpensesForBusiness(businessId)
        let profit = income - expenses
        
        return VStack(alignment: .leading, spacing: 16) {
            Text(businessName)
                .font(.title)
                .fontWeight(.bold)
            
            HStack(spacing: 20) {
                // Income card
                financeCard(
                    title: "Income",
                    amount: income,
                    iconName: "arrow.down.circle.fill",
                    color: .green
                )
                
                // Expenses card
                financeCard(
                    title: "Expenses",
                    amount: expenses,
                    iconName: "arrow.up.circle.fill",
                    color: .red
                )
            }
            
            // Profit/Loss card
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
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGroupedBackground))
        )
        .padding(.horizontal)
    }
    
    // Finance metric card
    private func financeCard(title: String, amount: Decimal, iconName: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(alignment: .center) {
                Image(systemName: iconName)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                
                Text(amount, format: .currency(code: "USD"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
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
    
    // Income chart section
    private func incomeChartSection(for businessId: UUID) -> some View {
        let incomeCategoryData = getIncomeTotalsByCategory(for: businessId)
        
        return VStack(alignment: .leading, spacing: 10) {
            Text("Income by Category")
                .font(.headline)
                .padding(.horizontal)
            
            if incomeCategoryData.isEmpty {
                Text("No income data for selected period")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                    )
                    .padding(.horizontal)
            } else {
                VStack {
                    Chart {
                        ForEach(incomeCategoryData, id: \.category) { item in
                            BarMark(
                                x: .value("Amount", item.amount),
                                y: .value("Category", item.category)
                            )
                            .foregroundStyle(.green)
                        }
                    }
                    .chartXAxisLabel("Amount ($)")
                    .frame(height: CGFloat(max(200, incomeCategoryData.count * 40)))
                }
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
        let expenseCategoryData = getExpenseTotalsByCategory(for: businessId)
        
        return VStack(alignment: .leading, spacing: 10) {
            Text("Expenses by Category")
                .font(.headline)
                .padding(.horizontal)
            
            if expenseCategoryData.isEmpty {
                Text("No expense data for selected period")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                    )
                    .padding(.horizontal)
            } else {
                VStack {
                    Chart {
                        ForEach(expenseCategoryData, id: \.category) { item in
                            BarMark(
                                x: .value("Amount", item.amount),
                                y: .value("Category", item.category)
                            )
                            .foregroundStyle(.red)
                        }
                    }
                    .chartXAxisLabel("Amount ($)")
                    .frame(height: CGFloat(max(200, expenseCategoryData.count * 40)))
                }
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
        let income = getIncomeForBusiness(businessId)
        let expenses = getExpensesForBusiness(businessId)
        let profit = income - expenses
        let transactionCount = getItemsForBusiness(businessId).count
        
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
                        Text("\(transactionCount)")
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
    
    // All businesses summary section
    private var allBusinessesSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Businesses Summary")
                .font(.title)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            // Business cards grid
            if businessViewModel.businesses.isEmpty {
                noBusinessesView
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(businessViewModel.businesses, id: \.id) { business in
                        if let businessId = business.id {
                            allBusinessSummaryCard(
                                name: business.name ?? "Unknown",
                                id: businessId
                            )
                        }
                    }
                }
                .padding(.horizontal)
                
                // Overall summary
                overallSummarySection
            }
        }
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
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
        .padding()
    }
    
    // Summary card for a single business in all businesses view
    private func allBusinessSummaryCard(name: String, id: UUID) -> some View {
        let income = getIncomeForBusiness(id)
        let expenses = getExpensesForBusiness(id)
        let profit = income - expenses
        
        return Button {
            withAnimation {
                selectedBusinessId = id
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
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
        .buttonStyle(PlainButtonStyle())
    }
    
    // Overall summary for all businesses
    private var overallSummarySection: some View {
        // Calculate totals across all businesses
        let totalIncome = businessViewModel.businesses.compactMap { $0.id }.reduce(Decimal(0)) { sum, businessId in
            sum + getIncomeForBusiness(businessId)
        }
        
        let totalExpenses = businessViewModel.businesses.compactMap { $0.id }.reduce(Decimal(0)) { sum, businessId in
            sum + getExpensesForBusiness(businessId)
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
    
    // Filter items by date range
    private func filteredItems() -> [Schedule] {
        viewModel.scheduleItems.filter { item in
            guard let date = item.date else { return false }
            return date >= startDate && date <= endDate
        }
    }
    
    // Get items for a specific business
    private func getItemsForBusiness(_ businessId: UUID) -> [Schedule] {
        return filteredItems().filter { item in
            guard let itemBusinessIdObj = item.businessId as? NSUUID else { return false }
            return UUID(uuidString: itemBusinessIdObj.uuidString) == businessId
        }
    }
    
    // Get income for a business
    private func getIncomeForBusiness(_ businessId: UUID) -> Decimal {
        let businessItems = getItemsForBusiness(businessId)
        let incomeItems = businessItems.filter { ($0.transactionType ?? "") == "income" }
        
        return incomeItems.reduce(Decimal(0)) { sum, item in
            sum + (item.amount?.decimalValue ?? Decimal(0))
        }
    }
    
    // Get expenses for a business
    private func getExpensesForBusiness(_ businessId: UUID) -> Decimal {
        let businessItems = getItemsForBusiness(businessId)
        let expenseItems = businessItems.filter { ($0.transactionType ?? "") == "expense" }
        
        return expenseItems.reduce(Decimal(0)) { sum, item in
            sum + (item.amount?.decimalValue ?? Decimal(0))
        }
    }
    
    // Get income totals by category
    private func getIncomeTotalsByCategory(for businessId: UUID) -> [(category: String, amount: Decimal)] {
        let businessItems = getItemsForBusiness(businessId)
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
    
    // Get expense totals by category
    private func getExpenseTotalsByCategory(for businessId: UUID) -> [(category: String, amount: Decimal)] {
        let businessItems = getItemsForBusiness(businessId)
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
    
    // Update date range based on selected option
    private func updateDateRange() {
        let calendar = Calendar.current
        switch selectedDateRange {
        case .yearToDate:
            let currentYear = calendar.component(.year, from: Date())
            startDate = Date().startOfYear()
            endDate = Date()
            
        case .fullYear:
            let currentYear = calendar.component(.year, from: Date())
            startDate = Date.from(year: currentYear, month: 1, day: 1)
            endDate = Date.from(year: currentYear, month: 12, day: 31)
            
        case .quarter:
            // Last 3 months
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()
            startDate = calendar.startOfDay(for: threeMonthsAgo)
            endDate = Date()
            
        case .month:
            // Last month
            let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            startDate = calendar.startOfDay(for: oneMonthAgo)
            endDate = Date()
            
        case .custom:
            // Don't change dates - they're set by the date picker
            break
        }
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
    
    static func from(year: Int, month: Int, day: Int) -> Date {
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        
        return Calendar.current.date(from: dateComponents) ?? Date()
    }
}
