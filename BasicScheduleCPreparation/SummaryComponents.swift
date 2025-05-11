// SummaryComponents.swift
// UI Components for the Summary view
import SwiftUI
import Charts

// MARK: - Date Range Selector Component
struct SummaryDateRangePickerView: View {
    @Binding var selectedDateRange: SummaryDateRange
    @Binding var selectedYear: Int
    @Binding var selectedMonth: Int?
    @Binding var startDate: Date
    @Binding var endDate: Date
    
    let availableYears: [Int]
    var onDateRangeChanged: () -> Void
    var onCustomDateRequested: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date Range")
                .font(.headline)
                .padding(.horizontal)
            
            Picker("Date Range", selection: $selectedDateRange) {
                Text("Year to Date").tag(SummaryDateRange.yearToDate)
                Text("Full Year").tag(SummaryDateRange.fullYear)
                Text("Quarter").tag(SummaryDateRange.quarter)
                Text("Month").tag(SummaryDateRange.month)
                Text("Custom").tag(SummaryDateRange.custom)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedDateRange) { _, newValue in
                if newValue == .custom {
                    onCustomDateRequested()
                } else {
                    onDateRangeChanged()
                }
            }
            .padding(.horizontal)
            
            HStack {
                Text("Year:")
                Picker("Year", selection: $selectedYear) {
                    ForEach(availableYears, id: \.self) { year in
                        Text("\(year)").tag(year)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: selectedYear) { _, _ in
                    onDateRangeChanged()
                }
                
                if selectedDateRange == .month || selectedDateRange == .quarter {
                    Text(selectedDateRange == .month ? "Month:" : "Quarter:")
                    Picker(selectedDateRange == .month ? "Month" : "Quarter", selection: $selectedMonth) {
                        if selectedDateRange == .month {
                            ForEach(1...12, id: \.self) { month in
                                Text(SummaryDateManager.monthName(month)).tag(month as Int?)
                            }
                        } else {
                            ForEach(1...4, id: \.self) { quarter in
                                Text("Q\(quarter)").tag(quarter as Int?)
                            }
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: selectedMonth) { _, _ in
                        onDateRangeChanged()
                    }
                }
            }
            .padding(.horizontal)
            
            Text("Showing data from \(startDate.formatted(date: .abbreviated, time: .omitted)) to \(endDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }
}

// MARK: - Category Filter Component
struct SummaryCategoryFilterView: View {
    @Binding var categoryFilter: String?
    @Binding var showExpensesAbove: Bool
    @Binding var minExpenseFilter: Double?
    
    var incomeCategories: [String]
    var expenseCategories: [String]
    var onFilterChanged: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category filter
            HStack {
                Text("Category:")
                Picker("Category", selection: $categoryFilter) {
                    Text("All Categories").tag(nil as String?)
                    
                    Group {
                        Text("Income Categories").tag("" as String?)
                            .disabled(true)
                            .foregroundColor(.secondary)
                        
                        ForEach(incomeCategories, id: \.self) { category in
                            Text(category).tag(category as String?)
                        }
                    }
                    
                    Group {
                        Text("Expense Categories").tag("" as String?)
                            .disabled(true)
                            .foregroundColor(.secondary)
                            
                        ForEach(expenseCategories, id: \.self) { category in
                            Text(category).tag(category as String?)
                        }
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: categoryFilter) { _, _ in
                    onFilterChanged()
                }
            }
            
            Divider()
            
            // Expense amount filter
            Toggle("Show expenses above:", isOn: $showExpensesAbove)
                .onChange(of: showExpensesAbove) { _, _ in
                    onFilterChanged()
                }
            
            if showExpensesAbove {
                HStack {
                    Text("$")
                    TextField("Minimum Amount", value: $minExpenseFilter, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        // Use proper keyboardType with UIKit import
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .onChange(of: minExpenseFilter) { _, _ in
                            onFilterChanged()
                        }
                }
            }
        }
    }
}

// MARK: - Business Selector
struct SummaryBusinessSelectorView: View {
    let businesses: [Business]
    @Binding var selectedBusinessId: UUID?
    var onAddBusiness: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select Business")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // All businesses option
                    businessCard(id: nil, name: "All Businesses")
                    
                    // Individual businesses
                    ForEach(businesses) { business in
                        businessCard(id: business.id, name: business.name ?? "Unknown")
                    }
                    
                    // Add business button
                    Button {
                        onAddBusiness()
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
}

// MARK: - Business Overview Card
struct SummaryBusinessOverviewView: View {
    let name: String
    let income: Decimal
    let expenses: Decimal
    
    var body: some View {
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
}

// MARK: - Financial Chart
struct SummaryChartView: View {
    let title: String
    let chartData: [SummaryChartData]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding(.bottom, 5)
                .padding(.horizontal)
            
            if chartData.isEmpty {
                Text("No data for selected period")
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
            } else {
                Chart {
                    ForEach(chartData) { item in
                        BarMark(
                            x: .value("Amount", item.amount),
                            y: .value("Category", item.category)
                        )
                        .foregroundStyle(color)
                    }
                }
                .frame(height: CGFloat(max(200, chartData.count * 40)))
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
}

// MARK: - Statistics Card
struct SummaryStatisticsView: View {
    let income: Decimal
    let expenses: Decimal
    let transactionCount: Int
    
    var body: some View {
        let profit = income - expenses
        
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
}

// MARK: - Business Summary Card (for grid)
struct SummaryBusinessGridCardView: View {
    let name: String
    let income: Decimal
    let expenses: Decimal
    let onSelect: () -> Void
    
    var body: some View {
        let profit = income - expenses
        
        return Button(action: onSelect) {
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
}

// MARK: - No Businesses View
struct SummaryNoBusinessesView: View {
    var onAddBusiness: () -> Void
    
    var body: some View {
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
                onAddBusiness()
            } label: {
                Label("Add Business", systemImage: "plus.circle.fill")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 10)
        }
        .padding()
    }
}

// MARK: - Filter Section
struct SummaryFilterSection: View {
    @Binding var selectedDateRange: SummaryDateRange
    @Binding var selectedYear: Int
    @Binding var selectedMonth: Int?
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var categoryFilter: String?
    @Binding var showExpensesAbove: Bool
    @Binding var minExpenseFilter: Double?
    
    let availableYears: [Int]
    let incomeCategories: [String]
    let expenseCategories: [String]
    
    var onDateRangeChanged: () -> Void
    var onFilterChanged: () -> Void
    var onCustomDateRequested: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DisclosureGroup("Filtering Options") {
                VStack(alignment: .leading, spacing: 15) {
                    // Date Range Section
                    SummaryDateRangePickerView(
                        selectedDateRange: $selectedDateRange,
                        selectedYear: $selectedYear,
                        selectedMonth: $selectedMonth,
                        startDate: $startDate,
                        endDate: $endDate,
                        availableYears: availableYears,
                        onDateRangeChanged: onDateRangeChanged,
                        onCustomDateRequested: onCustomDateRequested
                    )
                    
                    Divider()
                    
                    // Category Filter Section
                    SummaryCategoryFilterView(
                        categoryFilter: $categoryFilter,
                        showExpensesAbove: $showExpensesAbove,
                        minExpenseFilter: $minExpenseFilter,
                        incomeCategories: incomeCategories,
                        expenseCategories: expenseCategories,
                        onFilterChanged: onFilterChanged
                    )
                }
                .padding(.top, 5)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
}

// MARK: - Custom Date Picker View
struct SummaryCustomDatePickerView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    var onDateChanged: () -> Void
    var onDismiss: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
            }
            .navigationTitle("Select Date Range")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onDateChanged()
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Overall Summary Section
struct SummaryOverallStatisticsView: View {
    let businesses: [Business]
    let totalIncome: Decimal
    let totalExpenses: Decimal
    
    var body: some View {
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
                        Text("\(businesses.count)")
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
}

// MARK: - Business Grid View
struct SummaryBusinessGridView: View {
    let businesses: [Business]
    let getIncome: (UUID) -> Decimal
    let getExpenses: (UUID) -> Decimal
    let onSelectBusiness: (UUID) -> Void
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(businesses) { business in
                if let businessId = business.id {
                    SummaryBusinessGridCardView(
                        name: business.name ?? "Unknown",
                        income: getIncome(businessId),
                        expenses: getExpenses(businessId),
                        onSelect: {
                            onSelectBusiness(businessId)
                        }
                    )
                }
            }
        }
        .padding(.horizontal)
    }
}
