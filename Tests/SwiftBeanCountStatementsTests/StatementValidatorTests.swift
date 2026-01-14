//
//  StatementValidatorTests.swift
//  SwiftBeanCountStatementsTests
//
//  Created by GitHub Copilot on 2026-01-13.
//

import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountStatements
import Testing

@Suite
struct StatementValidatorTests {

    private var testAccountName: AccountName {
        try! AccountName("Assets:Test") // swiftlint:disable:this force_try
    }

    private var parentURL: URL {
        let resourcesURL = try! #require(Bundle.module.url(forResource: "Resource", withExtension: nil)) // swiftlint:disable:this force_try
        return resourcesURL.deletingLastPathComponent()
    }

    private let customFileNames = Custom(
        date: Date(timeIntervalSince1970: 1_672_531_200),
        name: "statements-settings",
        values: ["file-names", "Statement Monthly"],
    )

    // MARK: - getRootFolder Tests

    @Test
    func getRootFolderSuccess() throws {
        let custom = Custom(
            date: Date(timeIntervalSince1970: 1_672_531_200),
            name: "statements-settings",
            values: ["root-folder", "/path/to/statements"]
        )
        let ledger = Ledger()
        ledger.custom.append(custom)

        let rootFolder = try StatementValidator.getRootFolder(from: ledger)
        #expect(rootFolder == "/path/to/statements")
    }

    @Test
    func getRootFolderNoRootFolder() throws {
        let ledger = Ledger()

        #expect(throws: StatementValidatorError.noRootFolder) {
            try StatementValidator.getRootFolder(from: ledger)
        }
    }

    @Test
    func getRootFolderMultipleSettingsUsesLatest() throws {
        let custom1 = Custom(
            date: Date(timeIntervalSince1970: 1_672_531_200), // 2023-01-01
            name: "statements-settings",
            values: ["root-folder", "/old/path"]
        )
        let custom2 = Custom(
            date: Date(timeIntervalSince1970: 1_675_209_600), // 2023-02-01
            name: "statements-settings",
            values: ["root-folder", "/new/path"]
        )
        let ledger = Ledger()
        ledger.custom.append(custom1)
        ledger.custom.append(custom2)

        let rootFolder = try StatementValidator.getRootFolder(from: ledger)
        #expect(rootFolder == "/new/path")
    }

    @Test
    func getRootFolderIgnoresOtherSettings() throws {
        let custom = Custom(
            date: Date(timeIntervalSince1970: 1_672_531_200),
            name: "statements-settings",
            values: ["root-folder", "/path/to/statements"]
        )
        let ledger = Ledger()
        ledger.custom.append(customFileNames)
        ledger.custom.append(custom)

        let rootFolder = try StatementValidator.getRootFolder(from: ledger)
        #expect(rootFolder == "/path/to/statements")
    }

    // MARK: - validate Tests

    @Test
    func validateWithResourcesFolder() async throws {
        let account = Account(
            name: testAccountName,
            opening: Date(timeIntervalSince1970: 1_672_531_200),
            metaData: ["folder": "Resource"]
        )

        let ledger = Ledger()
        ledger.custom.append(customFileNames)
        try ledger.add(account)

        let results = try await StatementValidator.validate(
            ledger,
            securityScopedRootURL: parentURL,
            includeClosedAccounts: false,
            includeStartEndDateWarning: false,
            includeCurrentStatementWarning: false
        )

        #expect(results.count == 1)
        let accountResult = try #require(results[testAccountName])
        #expect(accountResult.statementResults.count == 2)
        #expect(accountResult.statementResults.contains { $0.name == "Statement Monthly" && $0.frequency == .monthly && $0.errors.isEmpty && $0.warnings.isEmpty })
        #expect(accountResult.statementResults.contains { $0.name == "Statement A" && $0.frequency == .monthly && $0.errors.isEmpty && $0.warnings.isEmpty })
        #expect(accountResult.folderName.contains("Resource"))
    }

    @Test
    func validateClosedAccounts() async throws {
        let closedAccount = Account(
            name: testAccountName,
            opening: Date(timeIntervalSince1970: 1_672_531_200),
            closing: Date(timeIntervalSince1970: 1_675_209_600),
            metaData: ["folder": "Resource"]
        )

        let ledger = Ledger()
        ledger.custom.append(customFileNames)
        try ledger.add(closedAccount)

        var results = try await StatementValidator.validate(
            ledger,
            securityScopedRootURL: parentURL,
            includeClosedAccounts: false, // exclude closed accounts
            includeStartEndDateWarning: false,
            includeCurrentStatementWarning: false
        )

        #expect(results.isEmpty)

        results = try await StatementValidator.validate(
            ledger,
            securityScopedRootURL: parentURL,
            includeClosedAccounts: true, // include closed accounts
            includeStartEndDateWarning: false,
            includeCurrentStatementWarning: false
        )

        #expect(!results.isEmpty)
        #expect(results[testAccountName] != nil)
    }

    @Test
    func validateExcludesDisabledAccounts() async throws {
        let disabledAccount = Account(
            name: testAccountName,
            opening: Date(timeIntervalSince1970: 1_672_531_200),
            metaData: ["folder": "Resource", "statements": "disable"]
        )

        let ledger = Ledger()
        ledger.custom.append(customFileNames)
        try ledger.add(disabledAccount)

        let results = try await StatementValidator.validate(
            ledger,
            securityScopedRootURL: parentURL,
            includeClosedAccounts: false,
            includeStartEndDateWarning: false,
            includeCurrentStatementWarning: false
        )

        #expect(results.isEmpty)
    }

    @Test
    func validateExcludesAccountsWithoutFolder() async throws {
        let accountWithoutFolder = Account(
            name: testAccountName,
            opening: Date(timeIntervalSince1970: 1_672_531_200)
        )

        let ledger = Ledger()
        ledger.custom.append(customFileNames)
        try ledger.add(accountWithoutFolder)

        let results = try await StatementValidator.validate(
            ledger,
            securityScopedRootURL: parentURL,
            includeClosedAccounts: false,
            includeStartEndDateWarning: false,
            includeCurrentStatementWarning: false
        )

        #expect(results.isEmpty)
    }

    @Test
    func validateWithStartEndDateWarning() async throws {
        let account = Account(
            name: testAccountName,
            opening: Date(timeIntervalSince1970: 1_609_459_200), // Different from statement start
            metaData: ["folder": "Resource"]
        )

        let ledger = Ledger()
        ledger.custom.append(customFileNames)
        try ledger.add(account)

        let results = try await StatementValidator.validate(
            ledger,
            securityScopedRootURL: parentURL,
            includeClosedAccounts: false,
            includeStartEndDateWarning: true,
            includeCurrentStatementWarning: false
        )

        let accountResult = try #require(results[testAccountName])
        // Should have warnings due to date mismatch
        #expect(accountResult.statementResults.contains { !$0.warnings.isEmpty })
    }

    @Test
    func validateWithCurrentStatementWarning() async throws {
        let account = Account(
            name: testAccountName,
            opening: Date(timeIntervalSince1970: 1_609_459_200), // Different from statement start
            metaData: ["folder": "Resource"]
        )

        let ledger = Ledger()
        ledger.custom.append(customFileNames)
        try ledger.add(account)

        let results = try await StatementValidator.validate(
            ledger,
            securityScopedRootURL: parentURL,
            includeClosedAccounts: false,
            includeStartEndDateWarning: false,
            includeCurrentStatementWarning: true
        )

        let accountResult = try #require(results[testAccountName])
        // Should have warnings due to date mismatch
        #expect(accountResult.statementResults.contains { !$0.warnings.isEmpty })
    }

    @Test
    func emptyLedger() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let ledger = Ledger()

        let results = try await StatementValidator.validate(
            ledger,
            securityScopedRootURL: tempDir,
            includeClosedAccounts: false,
            includeStartEndDateWarning: false,
            includeCurrentStatementWarning: false
        )

        #expect(results.isEmpty)
    }

    @Test
    func ledgerWithoutAccounts() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let ledger = Ledger()

        ledger.custom.append(customFileNames)

        let results = try await StatementValidator.validate(
            ledger,
            securityScopedRootURL: tempDir,
            includeClosedAccounts: false,
            includeStartEndDateWarning: false,
            includeCurrentStatementWarning: false
        )

        #expect(results.isEmpty)
    }

}
