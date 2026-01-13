//
//  AccountStartEndDateValidatorTests.swift
//  SwiftBeanCountStatementsTests
//
//  Created by GitHub Copilot on 2026-01-13.
//

import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountStatements
import Testing

@Suite
struct AccountStartEndDateValidatorMonthlyTests { // swiftlint:disable:this type_body_length

    private var testAccountName: AccountName {
        try! AccountName("Assets:Test") // swiftlint:disable:this force_try
    }

    // MARK: - Monthly Opening Date Tests

    @Test
    func validateMonthlyMatchingOpeningDate() {
        let calendar = Calendar.current
        let openingDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01
        let startDate = openingDate

        let account = Account(name: testAccountName, opening: openingDate)
        let result = StatementResult(
            name: "Test",
            frequency: .monthly,
            startDate: startDate,
            endDate: calendar.date(byAdding: .month, value: 1, to: startDate)
        )

        let validated = AccountStartEndDateValidator.validate(account, result: result)
        #expect(validated.warnings.isEmpty)
    }

    @Test
    func validateMonthlyMismatchedOpeningDate() {
        let calendar = Calendar.current
        let openingDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01
        let startDate = calendar.date(byAdding: .month, value: 1, to: openingDate)! // 2023-02-01

        let account = Account(name: testAccountName, opening: openingDate)
        let result = StatementResult(
            name: "Test",
            frequency: .monthly,
            startDate: startDate,
            endDate: calendar.date(byAdding: .month, value: 1, to: startDate)
        )

        let validated = AccountStartEndDateValidator.validate(account, result: result)
        #expect(!validated.warnings.isEmpty)
        #expect(validated.warnings.contains { $0.contains("opened") && $0.contains("statements start") })
    }

    // MARK: - Monthly Closing Date Tests

    @Test
    func validateMonthlyMatchingClosingDate() {
        let calendar = Calendar.current
        let openingDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01
        let closingDate = calendar.date(byAdding: .month, value: 2, to: openingDate)! // 2023-03-01
        let endDate = closingDate

        let account = Account(name: testAccountName, opening: openingDate, closing: closingDate)
        let result = StatementResult(
            name: "Test",
            frequency: .monthly,
            startDate: openingDate,
            endDate: endDate
        )

        let validated = AccountStartEndDateValidator.validate(account, result: result)
        #expect(validated.warnings.isEmpty)
    }

    @Test
    func validateMonthlyMismatchedClosingDate() {
        let calendar = Calendar.current
        let openingDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01
        let closingDate = calendar.date(byAdding: .month, value: 3, to: openingDate)! // 2023-04-01
        let endDate = calendar.date(byAdding: .month, value: 2, to: openingDate)! // 2023-03-01

        let account = Account(name: testAccountName, opening: openingDate, closing: closingDate)
        let result = StatementResult(
            name: "Test",
            frequency: .monthly,
            startDate: openingDate,
            endDate: endDate
        )

        let validated = AccountStartEndDateValidator.validate(account, result: result)
        #expect(!validated.warnings.isEmpty)
        #expect(validated.warnings.contains { $0.contains("closed") && $0.contains("statements end") })
    }

    // MARK: - Quarterly Opening Date Tests

    @Test
    func validateQuarterlyMatchingOpeningDate() {
        let calendar = Calendar.current
        let openingDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01 Q1
        let startDate = openingDate

        let account = Account(name: testAccountName, opening: openingDate)
        let result = StatementResult(
            name: "Test",
            frequency: .quarterly,
            startDate: startDate,
            endDate: calendar.date(byAdding: .month, value: 3, to: startDate)
        )

        let validated = AccountStartEndDateValidator.validate(account, result: result)
        #expect(validated.warnings.isEmpty)
    }

    @Test
    func validateQuarterlyMismatchedOpeningDate() {
        let calendar = Calendar.current
        let openingDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01 Q1
        let startDate = calendar.date(byAdding: .month, value: 3, to: openingDate)! // 2023-04-01 Q2

        let account = Account(name: testAccountName, opening: openingDate)
        let result = StatementResult(
            name: "Test",
            frequency: .quarterly,
            startDate: startDate,
            endDate: calendar.date(byAdding: .month, value: 3, to: startDate)
        )

        let validated = AccountStartEndDateValidator.validate(account, result: result)
        #expect(!validated.warnings.isEmpty)
        #expect(validated.warnings.contains { $0.contains("opened Q") && $0.contains("statements start Q") })
    }

    // MARK: - Quarterly Closing Date Tests

    @Test
    func validateQuarterlyMatchingClosingDate() {
        let calendar = Calendar.current
        let openingDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01 Q1
        let closingDate = calendar.date(byAdding: .month, value: 6, to: openingDate)! // 2023-07-01 Q3
        let endDate = closingDate

        let account = Account(name: testAccountName, opening: openingDate, closing: closingDate)
        let result = StatementResult(
            name: "Test",
            frequency: .quarterly,
            startDate: openingDate,
            endDate: endDate
        )

        let validated = AccountStartEndDateValidator.validate(account, result: result)
        #expect(validated.warnings.isEmpty)
    }

    @Test
    func validateQuarterlyMismatchedClosingDate() {
        let calendar = Calendar.current
        let openingDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01 Q1
        let closingDate = calendar.date(byAdding: .month, value: 6, to: openingDate)! // 2023-07-01 Q3
        let endDate = calendar.date(byAdding: .month, value: 3, to: openingDate)! // 2023-04-01 Q2

        let account = Account(name: testAccountName, opening: openingDate, closing: closingDate)
        let result = StatementResult(
            name: "Test",
            frequency: .quarterly,
            startDate: openingDate,
            endDate: endDate
        )

        let validated = AccountStartEndDateValidator.validate(account, result: result)
        #expect(!validated.warnings.isEmpty)
        #expect(validated.warnings.contains { $0.contains("closed Q") && $0.contains("statements end Q") })
    }

    // MARK: - Yearly Opening Date Tests

    @Test
    func validateYearlyMatchingOpeningDate() {
        let calendar = Calendar.current
        let openingDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01
        let startDate = openingDate

        let account = Account(name: testAccountName, opening: openingDate)
        let result = StatementResult(
            name: "Test",
            frequency: .yearly,
            startDate: startDate,
            endDate: calendar.date(byAdding: .year, value: 1, to: startDate)
        )

        let validated = AccountStartEndDateValidator.validate(account, result: result)
        #expect(validated.warnings.isEmpty)
    }

    @Test
    func validateYearlyMismatchedOpeningDate() {
        let calendar = Calendar.current
        let openingDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01
        let startDate = calendar.date(byAdding: .year, value: 1, to: openingDate)! // 2024-01-01

        let account = Account(name: testAccountName, opening: openingDate)
        let result = StatementResult(
            name: "Test",
            frequency: .yearly,
            startDate: startDate,
            endDate: calendar.date(byAdding: .year, value: 1, to: startDate)
        )

        let validated = AccountStartEndDateValidator.validate(account, result: result)
        #expect(!validated.warnings.isEmpty)
        #expect(validated.warnings.contains { $0.contains("opened") && $0.contains("statements start") })
    }

    // MARK: - Yearly Closing Date Tests

    @Test
    func validateYearlyMatchingClosingDate() {
        let calendar = Calendar.current
        let openingDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01
        let closingDate = calendar.date(byAdding: .year, value: 2, to: openingDate)! // 2025-01-01
        let endDate = closingDate

        let account = Account(name: testAccountName, opening: openingDate, closing: closingDate)
        let result = StatementResult(
            name: "Test",
            frequency: .yearly,
            startDate: openingDate,
            endDate: endDate
        )

        let validated = AccountStartEndDateValidator.validate(account, result: result)
        #expect(validated.warnings.isEmpty)
    }

    @Test
    func validateYearlyMismatchedClosingDate() {
        let calendar = Calendar.current
        let openingDate = Date(timeIntervalSince1970: 1_672_531_200) // 2023-01-01
        let closingDate = calendar.date(byAdding: .year, value: 2, to: openingDate)! // 2025-01-01
        let endDate = calendar.date(byAdding: .year, value: 1, to: openingDate)! // 2024-01-01

        let account = Account(name: testAccountName, opening: openingDate, closing: closingDate)
        let result = StatementResult(
            name: "Test",
            frequency: .yearly,
            startDate: openingDate,
            endDate: endDate
        )

        let validated = AccountStartEndDateValidator.validate(account, result: result)
        #expect(!validated.warnings.isEmpty)
        #expect(validated.warnings.contains { $0.contains("closed") && $0.contains("statements end") })
    }

    // MARK: - Edge Cases

    @Test
    func validateNoOpeningDate() {
        let account = Account(name: testAccountName)
        let result = StatementResult(
            name: "Test",
            frequency: .monthly,
            startDate: Date(timeIntervalSince1970: 1_672_531_200),
            endDate: Date(timeIntervalSince1970: 1_675_209_600)
        )

        let validated = AccountStartEndDateValidator.validate(account, result: result)
        #expect(validated.warnings.isEmpty)
    }

    @Test
    func validateNoClosingDate() {
        let openingDate = Date(timeIntervalSince1970: 1_672_531_200)
        let account = Account(name: testAccountName, opening: openingDate)
        let result = StatementResult(
            name: "Test",
            frequency: .monthly,
            startDate: openingDate,
            endDate: Date(timeIntervalSince1970: 1_675_209_600)
        )

        let validated = AccountStartEndDateValidator.validate(account, result: result)
        #expect(validated.warnings.isEmpty)
    }

    @Test
    func validateNilStartDate() {
        let account = Account(name: testAccountName, opening: Date(timeIntervalSince1970: 1_672_531_200))
        let result = StatementResult(
            name: "Test",
            frequency: .monthly,
            startDate: nil,
            endDate: Date(timeIntervalSince1970: 1_675_209_600)
        )

        let validated = AccountStartEndDateValidator.validate(account, result: result)
        #expect(validated.warnings.isEmpty)
    }

    @Test
    func validateNilEndDate() {
        let account = Account(name: testAccountName, opening: Date(timeIntervalSince1970: 1_672_531_200), closing: Date(timeIntervalSince1970: 1_675_209_600))
        let result = StatementResult(
            name: "Test",
            frequency: .monthly,
            startDate: Date(timeIntervalSince1970: 1_672_531_200),
            endDate: nil
        )

        let validated = AccountStartEndDateValidator.validate(account, result: result)
        #expect(validated.warnings.isEmpty)
    }

    @Test
    func validateSingleFrequency() {
        let openingDate = Date(timeIntervalSince1970: 1_672_531_200)
        let account = Account(name: testAccountName, opening: openingDate)
        let result = StatementResult(
            name: "Test",
            frequency: .single,
            startDate: Date(timeIntervalSince1970: 1_675_209_600),
            endDate: Date(timeIntervalSince1970: 1_675_209_600)
        )

        let validated = AccountStartEndDateValidator.validate(account, result: result)
        #expect(validated.warnings.isEmpty)
    }

    @Test
    func validateUnknownFrequency() {
        let openingDate = Date(timeIntervalSince1970: 1_672_531_200)
        let account = Account(name: testAccountName, opening: openingDate, closing: Date(timeIntervalSince1970: 1_675_209_600))
        let result = StatementResult(
            name: "Test",
            frequency: .unkown,
            startDate: Date(timeIntervalSince1970: 1_675_209_600),
            endDate: Date(timeIntervalSince1970: 1_675_209_600)
        )

        let validated = AccountStartEndDateValidator.validate(account, result: result)
        #expect(validated.warnings.isEmpty)
    }

    @Test
    func validatePreservesExistingData() {
        let account = Account(name: testAccountName)
        let result = StatementResult(
            name: "Test Name",
            frequency: .monthly,
            errors: ["Error 1"],
            warnings: ["Warning 1"],
            startDate: Date(timeIntervalSince1970: 1_672_531_200),
            endDate: Date(timeIntervalSince1970: 1_675_209_600)
        )

        let validated = AccountStartEndDateValidator.validate(account, result: result)
        #expect(validated.name == "Test Name")
        #expect(validated.frequency == .monthly)
        #expect(validated.errors == ["Error 1"])
        #expect(validated.warnings.contains("Warning 1"))
        #expect(validated.startDate == result.startDate)
        #expect(validated.endDate == result.endDate)
    }

}
