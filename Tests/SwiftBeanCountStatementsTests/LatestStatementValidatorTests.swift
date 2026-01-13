//
//  LatestStatementValidatorTests.swift
//  SwiftBeanCountStatementsTests
//
//  Created by GitHub Copilot on 2026-01-13.
//

import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountStatements
import Testing

@Suite
struct LatestStatementValidatorTests {

    private var testAccountName: AccountName {
        try! AccountName("Assets:Test") // swiftlint:disable:this force_try
    }

    // MARK: - Monthly Statements Tests

    @Test
    func validateMonthlyOpenAccountCurrent() {
        let calendar = Calendar.current
        // Create end date from last month
        let currentComponents = calendar.dateComponents([.year, .month], from: Date())
        let lastMonth = currentComponents.month! == 1 ? 12 : currentComponents.month! - 1
        let lastYear = lastMonth == 12 ? currentComponents.year! - 1 : currentComponents.year!
        var endComponents = DateComponents()
        endComponents.year = lastYear
        endComponents.month = lastMonth
        endComponents.day = 1
        let endDate = calendar.date(from: endComponents)!

        let account = Account(name: testAccountName, opening: Date())
        let result = StatementResult(
            name: "Test",
            frequency: .monthly,
            startDate: Date(timeIntervalSince1970: 1_672_531_200),
            endDate: endDate
        )

        let validated = LatestStatementValidator.validate(account, result: result)
        #expect(validated.warnings.isEmpty)
        #expect(!validated.latestStatementMissing)
    }

    @Test
    func validateMonthlyOpenAccountMissing() {
        let calendar = Calendar.current
        // Create end date from 3 months ago to ensure it's missing
        let currentComponents = calendar.dateComponents([.year, .month], from: Date())
        var endComponents = currentComponents
        if endComponents.month! > 3 {
            endComponents.month! -= 3
        } else {
            endComponents.month! = endComponents.month! + 12 - 3
            endComponents.year! -= 1
        }
        endComponents.day = 1
        let endDate = calendar.date(from: endComponents)!

        let account = Account(name: testAccountName, opening: Date())
        let result = StatementResult(
            name: "Test",
            frequency: .monthly,
            startDate: Date(timeIntervalSince1970: 1_672_531_200),
            endDate: endDate
        )

        let validated = LatestStatementValidator.validate(account, result: result)
        #expect(!validated.warnings.isEmpty)
        #expect(validated.warnings.contains { $0.contains("already complete") })
        #expect(validated.latestStatementMissing)
    }

    @Test
    func validateMonthlyClosedAccount() {
        let account = Account(name: testAccountName, opening: Date(), closing: Date())
        let result = StatementResult(
            name: "Test",
            frequency: .monthly,
            startDate: Date(timeIntervalSince1970: 1_672_531_200),
            endDate: Date(timeIntervalSince1970: 1_672_531_200)
        )

        let validated = LatestStatementValidator.validate(account, result: result)
        #expect(validated.warnings.isEmpty)
        #expect(!validated.latestStatementMissing)
    }

    // MARK: - Quarterly Statements Tests

    @Test
    func validateQuarterlyOpenAccountCurrent() {
        let calendar = Calendar.current
        let currentDate = Date()
        let currentQuarter = Int(StatementDatesValidator.quarterDateFormatter.string(from: currentDate))!
        let lastQuarter = currentQuarter == 1 ? 4 : currentQuarter - 1
        let currentYear = calendar.component(.year, from: currentDate)
        let lastYear = lastQuarter == 4 ? currentYear - 1 : currentYear

        // Create date in the last completed quarter
        var endComponents = DateComponents()
        endComponents.year = lastYear
        endComponents.month = (lastQuarter - 1) * 3 + 1
        endComponents.day = 1
        let endDate = calendar.date(from: endComponents)!

        let account = Account(name: testAccountName, opening: Date())
        let result = StatementResult(
            name: "Test",
            frequency: .quarterly,
            startDate: Date(timeIntervalSince1970: 1_672_531_200),
            endDate: endDate
        )

        let validated = LatestStatementValidator.validate(account, result: result)
        #expect(validated.warnings.isEmpty)
        #expect(!validated.latestStatementMissing)
    }

    @Test
    func validateQuarterlyOpenAccountMissing() {
        // Create end date from over a year ago to ensure it's missing
        let endDate = Date(timeIntervalSince1970: 1_640_995_200) // 2022-01-01

        let account = Account(name: testAccountName, opening: Date())
        let result = StatementResult(
            name: "Test",
            frequency: .quarterly,
            startDate: Date(timeIntervalSince1970: 1_640_995_200),
            endDate: endDate
        )

        let validated = LatestStatementValidator.validate(account, result: result)
        #expect(!validated.warnings.isEmpty)
        #expect(validated.warnings.contains { $0.contains("already complete") })
        #expect(validated.latestStatementMissing)
    }

    // MARK: - Yearly Statements Tests

    @Test
    func validateYearlyOpenAccountCurrent() {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let lastYear = currentYear - 1

        // Create date in the last completed year
        var endComponents = DateComponents()
        endComponents.year = lastYear
        endComponents.month = 1
        endComponents.day = 1
        let endDate = calendar.date(from: endComponents)!

        let account = Account(name: testAccountName, opening: Date())
        let result = StatementResult(
            name: "Test",
            frequency: .yearly,
            startDate: Date(timeIntervalSince1970: 1_672_531_200),
            endDate: endDate
        )

        let validated = LatestStatementValidator.validate(account, result: result)
        #expect(validated.warnings.isEmpty)
        #expect(!validated.latestStatementMissing)
    }

    @Test
    func validateYearlyOpenAccountMissing() {
        // Create end date from 3 years ago to ensure it's missing
        let endDate = Date(timeIntervalSince1970: 1_609_459_200) // 2021-01-01

        let account = Account(name: testAccountName, opening: Date())
        let result = StatementResult(
            name: "Test",
            frequency: .yearly,
            startDate: Date(timeIntervalSince1970: 1_609_459_200),
            endDate: endDate
        )

        let validated = LatestStatementValidator.validate(account, result: result)
        #expect(!validated.warnings.isEmpty)
        #expect(validated.warnings.contains { $0.contains("already complete") })
        #expect(validated.latestStatementMissing)
    }

    // MARK: - Edge Cases

    @Test
    func validateWithNilEndDate() {
        let account = Account(name: testAccountName, opening: Date())
        let result = StatementResult(
            name: "Test",
            frequency: .monthly,
            startDate: Date(timeIntervalSince1970: 1_672_531_200),
            endDate: nil
        )

        let validated = LatestStatementValidator.validate(account, result: result)
        #expect(validated.warnings.isEmpty)
        #expect(!validated.latestStatementMissing)
    }

    @Test
    func validateSingleFrequency() {
        let account = Account(name: testAccountName, opening: Date())
        let result = StatementResult(
            name: "Test",
            frequency: .single,
            startDate: Date(timeIntervalSince1970: 1_672_531_200),
            endDate: Date(timeIntervalSince1970: 1_672_531_200)
        )

        let validated = LatestStatementValidator.validate(account, result: result)
        #expect(validated.warnings.isEmpty)
        #expect(!validated.latestStatementMissing)
    }

    @Test
    func validateUnknownFrequency() {
        let account = Account(name: testAccountName, opening: Date())
        let result = StatementResult(
            name: "Test",
            frequency: .unkown,
            startDate: Date(timeIntervalSince1970: 1_672_531_200),
            endDate: Date(timeIntervalSince1970: 1_672_531_200)
        )

        let validated = LatestStatementValidator.validate(account, result: result)
        #expect(validated.warnings.isEmpty)
        #expect(!validated.latestStatementMissing)
    }

    @Test
    func validatePreservesExistingData() {
        let account = Account(name: testAccountName, opening: Date())
        let result = StatementResult(
            name: "Test Name",
            frequency: .monthly,
            errors: ["Error 1"],
            warnings: ["Warning 1"],
            startDate: Date(timeIntervalSince1970: 1_672_531_200),
            endDate: Date(timeIntervalSince1970: 1_672_531_200)
        )

        let validated = LatestStatementValidator.validate(account, result: result)
        #expect(validated.name == "Test Name")
        #expect(validated.frequency == .monthly)
        #expect(validated.errors == ["Error 1"])
        #expect(validated.warnings.contains("Warning 1"))
        #expect(validated.startDate == result.startDate)
        #expect(validated.endDate == result.endDate)
    }

}
