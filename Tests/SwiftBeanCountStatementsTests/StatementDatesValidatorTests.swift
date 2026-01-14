//
//  StatementDatesValidatorTests.swift
//  SwiftBeanCountStatementsTests
//
//  Created by GitHub Copilot on 2026-01-13.
//

import Foundation
@testable import SwiftBeanCountStatements
import Testing

@Suite
struct StatementDatesValidatorTests {

    // MARK: - identifyFrequency Tests

    @Test
    func identifyFrequencySingle() {
        let dates = [Date(timeIntervalSince1970: 1_672_704_000)] // 2023-01-03
        let frequency = StatementDatesValidator.identifyFrequency(dates)
        #expect(frequency == .single)
    }

    @Test
    func identifyFrequencyMonthly() {
        var dates = [Date]()
        let calendar = Calendar.current
        let startDate = Date(timeIntervalSince1970: 1_672_704_000) // 2023-01-03
        for month in 0..<12 {
            if let date = calendar.date(byAdding: .month, value: month, to: startDate) {
                dates.append(date)
            }
        }
        let frequency = StatementDatesValidator.identifyFrequency(dates)
        #expect(frequency == .monthly)
    }

    @Test
    func identifyFrequencyQuarterly() {
        var dates = [Date]()
        let calendar = Calendar.current
        let startDate = Date(timeIntervalSince1970: 1_672_704_000) // 2023-01-03
        for quarter in 0..<4 {
            if let date = calendar.date(byAdding: .month, value: quarter * 3, to: startDate) {
                dates.append(date)
            }
        }
        let frequency = StatementDatesValidator.identifyFrequency(dates)
        #expect(frequency == .quarterly)
    }

    @Test
    func identifyFrequencyYearly() {
        var dates = [Date]()
        let calendar = Calendar.current
        let startDate = Date(timeIntervalSince1970: 1_672_704_000) // 2023-01-03
        for year in 0..<3 {
            if let date = calendar.date(byAdding: .year, value: year, to: startDate) {
                dates.append(date)
            }
        }
        let frequency = StatementDatesValidator.identifyFrequency(dates)
        #expect(frequency == .yearly)
    }

    @Test
    func identifyFrequencyUnknown() {
        // Dates with irregular intervals - needs more than 3 dates to be clearly irregular
        let dates = [
            Date(timeIntervalSince1970: 1_672_704_000), // 2023-01-03
            Date(timeIntervalSince1970: 1_677_628_800), // 2023-03-01 (2 month gap)
            Date(timeIntervalSince1970: 1_688_169_600), // 2023-07-01 (4 month gap)
            Date(timeIntervalSince1970: 1_690_848_000)  // 2023-08-01 (1 month gap)
        ]
        let frequency = StatementDatesValidator.identifyFrequency(dates)
        #expect(frequency == .unkown)
    }

    // MARK: - checkDates Tests

    @Test
    func checkDatesMonthlyComplete() {
        var dates = [Date]()
        let calendar = Calendar.current
        let startDate = Date(timeIntervalSince1970: 1_672_704_000) // 2023-01-03
        for month in 0..<12 {
            if let date = calendar.date(byAdding: .month, value: month, to: startDate) {
                dates.append(date)
            }
        }
        let result = StatementDatesValidator.checkDates(dates, for: "Test Monthly")
        #expect(result.frequency == .monthly)
        #expect(result.errors.isEmpty)
        #expect(result.warnings.isEmpty)
        #expect(result.name == "Test Monthly")
    }

    @Test
    func checkDatesMonthlyWithGap() {
        var dates = [Date]()
        let calendar = Calendar.current
        let startDate = Date(timeIntervalSince1970: 1_672_704_000) // 2023-01-03
        // Create enough dates for monthly detection (Jan, Feb, Apr, May, Jun)
        dates.append(startDate) // Jan
        if let feb = calendar.date(byAdding: .month, value: 1, to: startDate) {
            dates.append(feb) // Feb
        }
        // Skip March
        if let apr = calendar.date(byAdding: .month, value: 3, to: startDate) {
            dates.append(apr) // Apr
        }
        if let may = calendar.date(byAdding: .month, value: 4, to: startDate) {
            dates.append(may) // May
        }
        if let jun = calendar.date(byAdding: .month, value: 5, to: startDate) {
            dates.append(jun) // Jun
        }
        let result = StatementDatesValidator.checkDates(dates, for: "Test Gap")
        #expect(result.frequency == .monthly)
        #expect(!result.errors.isEmpty)
        #expect(result.errors.contains { $0.contains("3/2023") })
    }

    @Test
    func checkDatesMonthlyDuplicate() {
        let calendar = Calendar.current
        let jan2023 = Date(timeIntervalSince1970: 1_672_704_000) // 2023-01-03
        let dates = [
            jan2023,
            jan2023, // Duplicate
            calendar.date(byAdding: .month, value: 1, to: jan2023)!,
            calendar.date(byAdding: .month, value: 2, to: jan2023)!
        ]
        let result = StatementDatesValidator.checkDates(dates, for: "Test Duplicate")
        #expect(!result.errors.isEmpty)
        #expect(result.errors.contains { $0.contains("Multiple Statements") })
    }

    @Test
    func checkDatesQuarterlyComplete() {
        var dates = [Date]()
        let calendar = Calendar.current
        let startDate = Date(timeIntervalSince1970: 1_672_704_000) // 2023-01-03
        for quarter in 0..<4 {
            if let date = calendar.date(byAdding: .month, value: quarter * 3, to: startDate) {
                dates.append(date)
            }
        }
        let result = StatementDatesValidator.checkDates(dates, for: "Test Quarterly")
        #expect(result.frequency == .quarterly)
        #expect(result.errors.isEmpty)
        #expect(result.warnings.isEmpty)
    }

    @Test
    func checkDatesQuarterlyWithGap() {
        let calendar = Calendar.current
        let startDate = Date(timeIntervalSince1970: 1_672_704_000) // 2023-01-03
        let dates = [
            startDate, // Q1
            calendar.date(byAdding: .month, value: 3, to: startDate)!, // Q2
            // Skip Q3
            calendar.date(byAdding: .month, value: 9, to: startDate)!, // Q4
            calendar.date(byAdding: .month, value: 12, to: startDate)! // Q1 next year
        ]
        let result = StatementDatesValidator.checkDates(dates, for: "Test Quarterly Gap")
        #expect(result.frequency == .quarterly)
        #expect(!result.errors.isEmpty)
        #expect(result.errors.contains { $0.contains("Quarter 3/2023") })
        #expect(result.warnings.isEmpty)
    }

    @Test
    func checkDatesYearlyComplete() {
        var dates = [Date]()
        let calendar = Calendar.current
        let startDate = Date(timeIntervalSince1970: 1_609_632_000) // 2021-01-03
        for year in 0..<3 {
            if let date = calendar.date(byAdding: .year, value: year, to: startDate) {
                dates.append(date)
            }
        }
        let result = StatementDatesValidator.checkDates(dates, for: "Test Yearly")
        #expect(result.frequency == .yearly)
        #expect(result.errors.isEmpty)
        #expect(result.warnings.isEmpty)
    }

    @Test
    func checkDatesYearlyWithGap() {
        let calendar = Calendar.current
        let startDate = Date(timeIntervalSince1970: 1_609_632_000) // 2021-01-03
        let dates = [
            startDate, // 2021
            calendar.date(byAdding: .year, value: 1, to: startDate)!, // 2022
            // Skip 2023
            calendar.date(byAdding: .year, value: 3, to: startDate)!, // 2024
            calendar.date(byAdding: .year, value: 4, to: startDate)!  // 2025
        ]
        let result = StatementDatesValidator.checkDates(dates, for: "Test Yearly Gap")
        #expect(result.frequency == .yearly)
        #expect(!result.errors.isEmpty)
        #expect(result.errors.contains { $0.contains("2023") })
        #expect(result.warnings.isEmpty)
    }

    @Test
    func checkDatesSingle() {
        let dates = [Date(timeIntervalSince1970: 1_672_704_000)] // 2023-01-03
        let result = StatementDatesValidator.checkDates(dates, for: "Test Single")
        #expect(result.frequency == .single)
        #expect(result.errors.isEmpty)
        #expect(!result.warnings.isEmpty)
        #expect(result.warnings.contains { $0.contains("Only single statement found for 1/2023") })
    }

    @Test
    func checkDatesStartEndDates() {
        let calendar = Calendar.current
        let startDate = Date(timeIntervalSince1970: 1_672_704_000) // 2023-01-03
        var dates = [Date]()
        for month in 0..<3 {
            if let date = calendar.date(byAdding: .month, value: month, to: startDate) {
                dates.append(date)
            }
        }
        let result = StatementDatesValidator.checkDates(dates, for: "Test Dates")
        #expect(result.startDate == startDate)
        #expect(result.endDate == dates.last)
    }

}
