// DateExtensions.swift
// Centralized file for all Date extension methods used throughout the app
// With unique method names to avoid conflicts

import Foundation

extension Date {
    /// Returns a date representing the start of the year (January 1, 00:00:00)
    func getStartOfYear() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year], from: self)
        components.month = 1
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        return calendar.date(from: components) ?? self
    }
    
    /// Returns the last day of the month for the current date (28, 29, 30, or 31)
    func getLastDayOfMonth() -> Int {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: self)!
        return range.upperBound - 1
    }
    
    /// Creates a Date from individual year, month, and day components
    static func createFrom(year: Int, month: Int, day: Int) -> Date {
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        
        return Calendar.current.date(from: dateComponents) ?? Date()
    }
    
    /// Returns a date representing the start of the month (1st day, 00:00:00)
    func getStartOfMonth() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: self)
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        return calendar.date(from: components) ?? self
    }
    
    /// Returns a date representing the end of the month (last day, 23:59:59)
    func getEndOfMonth() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: self)
        components.month! += 1
        components.day = 0
        components.hour = 23
        components.minute = 59
        components.second = 59
        
        return calendar.date(from: components) ?? self
    }
    
    /// Returns a date representing the start of the day (00:00:00)
    func getStartOfDay() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: self)
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        return calendar.date(from: components) ?? self
    }
    
    /// Returns a date representing the end of the day (23:59:59)
    func getEndOfDay() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: self)
        components.hour = 23
        components.minute = 59
        components.second = 59
        
        return calendar.date(from: components) ?? self
    }
    
    /// Returns a date representing the start of the week (Sunday 00:00:00)
    func getStartOfWeek() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
    
    /// Returns a date representing the end of the week (Saturday 23:59:59)
    func getEndOfWeek() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        components.weekOfYear! += 1
        components.day = 0
        components.hour = 23
        components.minute = 59
        components.second = 59
        
        return calendar.date(from: components) ?? self
    }
    
    /// Returns a date representing the start of the quarter
    func getStartOfQuarter() -> Date {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: self)
        let quarter = (month - 1) / 3
        let startMonth = quarter * 3 + 1
        
        var components = calendar.dateComponents([.year], from: self)
        components.month = startMonth
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        return calendar.date(from: components) ?? self
    }
    
    /// Returns a date representing the end of the quarter
    func getEndOfQuarter() -> Date {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: self)
        let quarter = (month - 1) / 3
        let endMonth = quarter * 3 + 3
        
        var components = calendar.dateComponents([.year], from: self)
        components.month = endMonth + 1
        components.day = 0
        components.hour = 23
        components.minute = 59
        components.second = 59
        
        return calendar.date(from: components) ?? self
    }
    
    /// Format date to a string using the given format
    func formatWithPattern(_ format: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
    }
    
    /// Get month name from a date
    func getMonthName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        return dateFormatter.string(from: self)
    }
    
    /// Get short month name from a date
    func getShortMonthName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        return dateFormatter.string(from: self)
    }
    
    /// Get year as a string from a date
    func getYearString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy"
        return dateFormatter.string(from: self)
    }
    
    /// Add days to a date
    func addDays(_ days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
    
    /// Add months to a date
    func addMonths(_ months: Int) -> Date {
        return Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }
    
    /// Add years to a date
    func addYears(_ years: Int) -> Date {
        return Calendar.current.date(byAdding: .year, value: years, to: self) ?? self
    }
    
    /// Check if date is today
    var isDateToday: Bool {
        return Calendar.current.isDateInToday(self)
    }
    
    /// Check if date is yesterday
    var isDateYesterday: Bool {
        return Calendar.current.isDateInYesterday(self)
    }
    
    /// Check if date is in the current month
    var isInCurrentMonth: Bool {
        return Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }
    
    /// Check if date is in the current year
    var isInCurrentYear: Bool {
        return Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year)
    }
    
    /// Get the day of month (1-31)
    var dayOfMonth: Int {
        return Calendar.current.component(.day, from: self)
    }
    
    /// Get the month (1-12)
    var monthNumber: Int {
        return Calendar.current.component(.month, from: self)
    }
    
    /// Get the year
    var yearNumber: Int {
        return Calendar.current.component(.year, from: self)
    }
    
    /// Get the quarter (1-4)
    var quarterNumber: Int {
        let month = self.monthNumber
        return (month - 1) / 3 + 1
    }
}

// Helper function to get month name from a month number (1-12)
func getMonthNameForNumber(_ month: Int) -> String {
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

// Helper function to get short month name from a month number (1-12)
func getShortMonthNameForNumber(_ month: Int) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MMM"
    
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
