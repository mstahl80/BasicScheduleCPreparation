// SummaryView.swift - Updated version using modular components
import SwiftUI
import Charts

// MARK: - Add Business Form - needed for SummaryView
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

// MARK: - Summary View
struct SummaryView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @StateObject private var businessViewModel = BusinessViewModel()
    
    // State properties
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var availableYears: [Int] = []
    @State private var selectedMonth: Int? = nil
    @State private var dateRange: SummaryDateRange = .yearToDate
    @State private var startDate: Date = Date().startOfYear()
    @State private var endDate: Date = Date()
    @State private var showingCustomDatePicker = false
    @State private var minExpenseFilter: Double? = nil
    @State private var showExpensesAbove: Bool = false
    @State private var categoryFilter: String? = nil
    
    // Business selection
    @State private var selectedBusinessId: UUID? = nil
    @State private var showingAddBusinessSheet = false
    
    // Filtered items
    @State private var filteredItems: [Schedule] = []
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Business selection
                SummaryBusinessSelectorView(
                    businesses: businessViewModel.businesses,
                    selectedBusinessId: $selectedBusinessId,
                    onAddBusiness: {
                        showingAddBusinessSheet = true
                    }
                )
                
                // Filtering Options
                SummaryFilterSection(
                    selectedDateRange: $dateRange,
                    selectedYear: $selectedYear,
                    selectedMonth: $selectedMonth,
                    startDate: $startDate,
                    endDate: $endDate,
                    categoryFilter: $categoryFilter,
                    showExpensesAbove: $showExpensesAbove,
                    minExpenseFilter: $minExpenseFilter,
                    availableYears: availableYears,
                    incomeCategories: ScheduleViewModel.incomeCategories,
                    expenseCategories: ScheduleViewModel.expenseCategories,
                    onDateRangeChanged: updateDateRange,
                    onFilterChanged: updateFilteredItems,
                    onCustomDateRequested: {
                        showingCustomDatePicker = true
                    }
                )
                
                if businessViewModel.businesses.isEmpty {
                    SummaryNoBusinessesView(
                        onAddBusiness: {
                            showingAddBusinessSheet = true
                        }
                    )
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
            updateDateRange()
            viewModel.fetchScheduleItems()
            businessViewModel.fetchBusinesses()
            
            // Auto-select the first business if there's only one
            if businessViewModel.businesses.count == 1,
               let firstBusiness = businessViewModel.businesses.first,
               let firstBusinessId = firstBusiness.id {
                selectedBusinessId = firstBusinessId
            }
        }
        .onChange(of: viewModel.scheduleItems) { _, _ in
            updateFilteredItems()
        }
        .sheet(isPresented: $showingCustomDatePicker) {
            SummaryCustomDatePickerView(
                startDate: $startDate,
                endDate: $endDate,
                onDateChanged: updateFilteredItems,
                onDismiss: {
                    showingCustomDatePicker = false
                }
            )
        }
        .sheet(isPresented: $showingAddBusinessSheet) {
            NavigationStack {
                AddBusinessForm(
                    businessViewModel: businessViewModel,
                    userId: viewModel.getCurrentUserName()
                ) { newBusiness in
                    if let businessId = newBusiness.id {
                        selectedBusinessId = businessId
                    }
                }
            }
        }
    }
    
    // MARK: - Content Builders
    
    private func businessSummaryContent(for businessId: UUID) -> some View {
        let businessName = businessViewModel.getBusiness(by: businessId)?.name ?? "Selected Business"
        
        // Get data for the business from filtered items
        let businessItems = filteredItemsForBusiness(businessId)
        let income = incomeForBusiness(businessId)
        let expenses = expensesForBusiness(businessId)
        
        // Get chart data
        let incomeChartData = incomeByCategory(for: businessId)
        let expenseChartData = expensesByCategory(for: businessId)
        
        return VStack(alignment: .leading, spacing: 20) {
            // Business overview
            SummaryBusinessOverviewView(
                name: businessName,
                income: income,
                expenses: expenses
            )
            
            // Income chart
            SummaryChartView(
                title: "Income by Category",
                chartData: incomeChartData,
                color: .green
            )
            
            // Expense chart
            SummaryChartView(
                title: "Expenses by Category",
                chartData: expenseChartData,
                color: .red
            )
            
            // Summary statistics
            SummaryStatisticsView(
                income: income,
                expenses: expenses,
                transactionCount: businessItems.count
            )
        }
    }
    
    // All businesses overview
    private var allBusinessesOverview: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Businesses cards grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(businessViewModel.businesses) { business in
                    if let businessId = business.id {
                        SummaryBusinessGridCardView(
                            name: business.name ?? "Unknown",
                            income: incomeForBusiness(businessId),
                            expenses: expensesForBusiness(businessId),
                            onSelect: {
                                selectedBusinessId = businessId
                            }
                        )
                    }
                }
            }
            .padding(.horizontal)
            
            // Overall summary
            overallSummarySection
        }
    }
    
    // Overall summary for all businesses
    private var overallSummarySection: some View {
        // Calculate totals across all businesses
        let totalIncome = businessViewModel.businesses.compactMap { $0.id }.reduce(Decimal(0)) { sum, businessId in
            sum + incomeForBusiness(businessId)
        }
        
        let totalExpenses = businessViewModel.businesses.compactMap { $0.id }.reduce(Decimal(0)) { sum, businessId in
            sum + expensesForBusiness(businessId)
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
    
    // MARK: - Helper Methods
    
    // Update available years based on data
    private func updateAvailableYears() {
        availableYears = SummaryDateManager.availableYears(from: viewModel.scheduleItems)
        
        // Set selected year to current year if available
        let currentYear = Calendar.current.component(.year, from: Date())
        if availableYears.contains(currentYear) {
            selectedYear = currentYear
        } else if let maxYear = availableYears.max() {
            selectedYear = maxYear
        }
    }
    
    // Update date range based on selected option
    private func updateDateRange() {
        let dateRangeResult = SummaryDateManager.calculateDateRange(
            range: dateRange,
            selectedYear: selectedYear,
            selectedMonth: selectedMonth,
            customStartDate: startDate,
            customEndDate: endDate
        )
        
        startDate = dateRangeResult.start
        endDate = dateRangeResult.end
        
        updateFilteredItems()
    }
    
    // Update filtered items based on criteria
    private func updateFilteredItems() {
        filteredItems = SummaryDataManager.filteredItems(
            from: viewModel.scheduleItems,
            dateRange: (startDate, endDate),
            categoryFilter: categoryFilter,
            showExpensesAbove: showExpensesAbove,
            minExpenseFilter: minExpenseFilter
        )
    }
    
    // Filter items for a specific business
    private func filteredItemsForBusiness(_ businessId: UUID) -> [Schedule] {
        SummaryDataManager.filteredItemsForBusiness(businessId, from: filteredItems)
    }
    
    // Calculate income for a business
    private func incomeForBusiness(_ businessId: UUID) -> Decimal {
        SummaryDataManager.incomeForBusiness(businessId, from: filteredItems)
    }
    
    // Calculate expenses for a business
    private func expensesForBusiness(_ businessId: UUID) -> Decimal {
        SummaryDataManager.expensesForBusiness(businessId, from: filteredItems)
    }
    
    // Calculate income by category
    private func incomeByCategory(for businessId: UUID) -> [SummaryChartData] {
        SummaryDataManager.incomeByCategory(for: businessId, from: filteredItems)
    }
    
    // Calculate expenses by category
    private func expensesByCategory(for businessId: UUID) -> [SummaryChartData] {
        SummaryDataManager.expensesByCategory(for: businessId, from: filteredItems)
    }
}

// MARK: - Preview
#if DEBUG
struct SummaryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SummaryView(viewModel: ScheduleViewModel())
        }
    }
}
#endif
