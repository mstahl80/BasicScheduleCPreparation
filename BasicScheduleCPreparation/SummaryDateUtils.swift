// SummaryDateUtils.swift
// Date utilities for the Summary view
import Foundation

enum SummaryDateRange {
    case yearToDate
    case fullYear
    case quarter
    case month
    case custom
}

class SummaryDateManager {
    // Calculate date range based on selected option
    static func calculateDateRange(
        range: SummaryDateRange,
        selectedYear: Int,
        selectedMonth: Int?,
        customStartDate: Date? = nil,
        customEndDate: Date? = nil
    ) -> (start: Date, end: Date) {
        
        let calendar = Calendar.current
        
        switch range {
        case .yearToDate:
            let currentYear = calendar.component(.year, from: Date())
            if selectedYear == currentYear {
                // Current year - from Jan 1 to today
                return (
                    date(year: selectedYear, month: 1, day: 1),
                    Date()
                )
            } else {
                // Past year - show full year
                return (
                    date(year: selectedYear, month: 1, day: 1),
                    date(year: selectedYear, month: 12, day: 31)
                )
            }
            
        case .fullYear:
            return (
                date(year: selectedYear, month: 1, day: 1),
                date(year: selectedYear, month: 12, day: 31)
            )
            
        case .quarter:
            let quarter = selectedMonth ?? 1
            let startMonth = (quarter - 1) * 3 + 1
            let endMonth = startMonth + 2
            
            let startDate = date(year: selectedYear, month: startMonth, day: 1)
            
            // Calculate end day based on month
            let endDay = endDayForMonth(month: endMonth, year: selectedYear)
            let endDate = date(year: selectedYear, month: endMonth, day: endDay)
            
            return (startDate, endDate)
            
        case .month:
            let month = selectedMonth ?? 1
            let startDate = date(year: selectedYear, month: month, day: 1)
            
            // Calculate end day based on month
            let endDay = endDayForMonth(month: month, year: selectedYear)
            let endDate = date(year: selectedYear, month: month, day: endDay)
            
            return (startDate, endDate)
            
        case .custom:
            // Use custom dates if provided, otherwise use current month
            if let start = customStartDate, let end = customEndDate {
                return (start, end)
            } else {
                // Default to current month if no custom dates
                let currentMonth = calendar.component(.month, from: Date())
                let startDate = date(year: selectedYear, month: currentMonth, day: 1)
                let endDay = endDayForMonth(month: currentMonth, year: selectedYear)
                let endDate = date(year: selectedYear, month: currentMonth, day: endDay)
                
                return (startDate, endDate)
            }
        }
    }
    
    // Get available years from schedule items
    static func availableYears(from scheduleItems: [Schedule]) -> [Int] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        // Get all years from items using a more explicit approach
        var years: [Int] = []
        for item in scheduleItems {
            if let date = item.date {
                let year = calendar.component(.year, from: date)
                years.append(year)
            }
        }
        
        // Create a set to get unique years and sort them
        let uniqueYears = Array(Set(years)).sorted()
        
        if uniqueYears.isEmpty {
            // If no data, just use current year
            return [currentYear]
        } else {
            // Return sorted years
            return uniqueYears
        }
    }
    
    // Get month name from month number
    static func monthName(_ month: Int) -> String {
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
    
    // Helper method to create date
    private static func date(year: Int, month: Int, day: Int) -> Date {
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        
        return Calendar.current.date(from: dateComponents) ?? Date()
    }
    
    // Helper method to get end day for month
    private static func endDayForMonth(month: Int, year: Int) -> Int {
        switch month {
        case 2:
            // February - check for leap year
            let isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
            return isLeapYear ? 29 : 28
        case 4, 6, 9, 11:
            // April, June, September, November
            return 30
        default:
            // January, March, May, July, August, October, December
            return 31
        }
    }
    
    // Calculate last day of month (use this instead of Date extension)
    static func lastDayOfMonth(for date: Date) -> Int {
        let calendar = Calendar.current
        if let interval = calendar.dateInterval(of: .month, for: date),
           let lastDay = calendar.dateComponents([.day], from: interval.end.addingTimeInterval(-1)).day {
            return lastDay
        }
        return 28 // Default fallback
    }
}

// Note: No Date extension is defined here to avoid conflicts
// If you need additional Date functionality, add it to the SummaryDateManager class
