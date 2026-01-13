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
        let dates = [Date(timeIntervalSince1970: 1_672_531_200)] // 2023-01-01
        let frequency = StatementDatesValidator.identifyFrequency(dates)
        #expect(frequency == .single)
    }

    @Test
    func identifyFrequencyMonthly() {
        var dates = [Date]()
        let calendar = Calendar.current
        let startDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01
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
        let startDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01
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
        let startDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01
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
        // Dates with irregular intervals
        let dates = [
            Date(timeIntervalSince1970: 1_672_531_200), // 2023-01-01
            Date(timeIntervalSince1970: 1_677_628_800), // 2023-03-01
            Date(timeIntervalSince1970: 1_688_169_600)  // 2023-07-01
        ]
        let frequency = StatementDatesValidator.identifyFrequency(dates)
        #expect(frequency == .unkown)
    }

    // MARK: - checkDates Tests

    @Test
    func checkDatesMonthlyComplete() {
        var dates = [Date]()
        let calendar = Calendar.current
        let startDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01
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
        let startDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01
        dates.append(startDate)
        if let feb = calendar.date(byAdding: .month, value: 1, to: startDate) {
            dates.append(feb)
        }
        // Skip March
        if let apr = calendar.date(byAdding: .month, value: 3, to: startDate) {
            dates.append(apr)
        }
        let result = StatementDatesValidator.checkDates(dates, for: "Test Gap")
        #expect(result.frequency == .monthly)
        #expect(!result.errors.isEmpty)
        #expect(result.errors.contains { $0.contains("3/2023") })
    }

    @Test
    func checkDatesMonthlyDuplicate() {
        let calendar = Calendar.current
        let jan2023 = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01
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
        let startDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01
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
        let startDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01
        let dates = [
            startDate, // Q1
            calendar.date(byAdding: .month, value: 3, to: startDate)!, // Q2
            // Skip Q3
            calendar.date(byAdding: .month, value: 9, to: startDate)! // Q4
        ]
        let result = StatementDatesValidator.checkDates(dates, for: "Test Quarterly Gap")
        #expect(!result.errors.isEmpty)
    }

    @Test
    func checkDatesYearlyComplete() {
        var dates = [Date]()
        let calendar = Calendar.current
        let startDate = Date(timeIntervalSince1970: 1_609_459_200) // 2021-01-01
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
        let dates = [
            Date(timeIntervalSince1970: 1_609_459_200), // 2021-01-01
            Date(timeIntervalSince1970: 1_640_995_200), // 2022-01-01
            // Skip 2023
            Date(timeIntervalSince1970: 1_704_067_200)  // 2024-01-01
        ]
        let result = StatementDatesValidator.checkDates(dates, for: "Test Yearly Gap")
        #expect(!result.errors.isEmpty)
    }

    @Test
    func checkDatesSingle() {
        let dates = [Date(timeIntervalSince1970: 1_672_531_200)] // 2023-01-01
        let result = StatementDatesValidator.checkDates(dates, for: "Test Single")
        #expect(result.frequency == .single)
        #expect(result.errors.isEmpty)
        #expect(!result.warnings.isEmpty)
        #expect(result.warnings.contains { $0.contains("Only single statement found") })
    }

    @Test
    func checkDatesStartEndDates() {
        let calendar = Calendar.current
        let startDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01
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
