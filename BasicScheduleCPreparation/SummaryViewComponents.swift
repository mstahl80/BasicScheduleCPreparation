// Updated SummaryViewComponents.swift
import SwiftUI
import Charts

// MARK: - Chart Data Structure for the Summary Charts
struct SummaryChartDataPoint: Identifiable {
    let id = UUID()
    let category: String
    let amount: Double
}

// MARK: - Expense and Income Chart Component
struct SummaryFinancialChart: View {
    let viewModel: ScheduleViewModel
    let businessId: UUID
    
    enum ChartType {
        case income
        case expense
    }
    
    let chartType: ChartType
    let dateRange: (start: Date, end: Date)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(chartType == .income ? "Income by Category" : "Expenses by Category")
                .font(.headline)
                .padding(.horizontal)
            
            if chartData.isEmpty {
                Text("No \(chartType == .income ? "income" : "expense") data for selected period")
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
                        ForEach(chartData, id: \.category) { item in
                            BarMark(
                                x: .value("Amount", item.amount),
                                y: .value("Category", item.category)
                            )
                            .foregroundStyle(chartType == .income ? .green : .red)
                        }
                    }
                    .chartXAxisLabel("Amount ($)")
                    .frame(height: CGFloat(max(200, chartData.count * 40)))
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
    
    private var chartData: [(category: String, amount: Decimal)] {
        // Filter items by date range
        let filteredItems = viewModel.scheduleItems.filter { item in
            guard let date = item.date else { return false }
            return date >= dateRange.start && date <= dateRange.end
        }
        
        // Filter by business
        let businessItems = filteredItems.filter { item in
            if let businessIdObj = item.businessId {
                // businessId is already an object, just get its uuidString
                let idString = businessIdObj.uuidString
                return UUID(uuidString: idString) == businessId
            }
            return false
        }
        
        // Filter by transaction type
        let transactionType = chartType == .income ? "income" : "expense"
        let typeItems = businessItems.filter { ($0.transactionType ?? "") == transactionType }
        
        // Group by category
        var categoryTotals: [String: Decimal] = [:]
        
        for item in typeItems {
            guard let category = item.category else { continue }
            let amount = item.amount?.decimalValue ?? Decimal(0)
            categoryTotals[category, default: Decimal(0)] += amount
        }
        
        // Convert to array and sort
        return categoryTotals.map { (category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
}

// MARK: - Date Range Selection Component
struct SummaryDateRangeSelector: View {
    @Binding var selectedDateRange: BusinessSummaryView.DateRange
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var selectedYear: Int
    @Binding var selectedMonth: Int?
    @Binding var showingCustomDatePicker: Bool
    
    let availableYears: [Int]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date Range")
                .font(.headline)
                .padding(.horizontal)
            
            Picker("Date Range", selection: $selectedDateRange) {
                Text("Year to Date").tag(BusinessSummaryView.DateRange.yearToDate)
                Text("Full Year").tag(BusinessSummaryView.DateRange.fullYear)
                Text("Last Quarter").tag(BusinessSummaryView.DateRange.quarter)
                Text("Last Month").tag(BusinessSummaryView.DateRange.month)
                Text("Custom").tag(BusinessSummaryView.DateRange.custom)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedDateRange) { _, newValue in
                if newValue == .custom {
                    showingCustomDatePicker = true
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
                
                if selectedDateRange == .month || selectedDateRange == .quarter {
                    Text(selectedDateRange == .month ? "Month:" : "Quarter:")
                    Picker(selectedDateRange == .month ? "Month" : "Quarter", selection: $selectedMonth) {
                        if selectedDateRange == .month {
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
            .padding(.horizontal)
            
            Text("Showing data from \(startDate.formatted(date: .abbreviated, time: .omitted)) to \(endDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
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
}

// MARK: - Horizontal Business Cards Component
struct SummaryBusinessCardsView: View {
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
            selectedBusinessId = id
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

// MARK: - Financial Statistics Summary Card
struct SummaryStatisticsCard: View {
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

// MARK: - Empty State - No Businesses
struct SummaryEmptyBusinessView: View {
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

// MARK: - Business Overview Card
struct SummaryBusinessOverviewCard: View {
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

// MARK: - Business Summary Card for Grid View
struct SummaryCompactBusinessCard: View {
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

// MARK: - Date Helper Extension
extension Date {
    // Only implement functions that don't already exist in your project
    func lastDayOfMonth() -> Int {
        let calendar = Calendar.current
        if let interval = calendar.dateInterval(of: .month, for: self),
           let lastDay = calendar.dateComponents([.day], from: interval.end.addingTimeInterval(-1)).day {
            return lastDay
        }
        return 28 // Default fallback
    }
}
