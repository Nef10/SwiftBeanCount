//
//  StatementFileValidatorTests.swift
//  SwiftBeanCountStatementsTests
//
//  Created by GitHub Copilot on 2026-01-13.
//

import Foundation
@testable import SwiftBeanCountStatements
import Testing

@Suite
struct StatementFileValidatorTests {

    @Test
    func checkStatementsFromMonthly() async throws {
        let resourcesURL = try #require(Bundle.module.url(forResource: "Resources", withExtension: nil))
        let results = try await StatementFileValidator.checkStatementsFrom(
            folder: resourcesURL,
            statementNames: ["Statement Monthly"]
        )

        #expect(!results.isEmpty)
        let monthlyResult = try #require(results.first { $0.name == "Statement Monthly" })
        #expect(monthlyResult.frequency == .monthly)
        #expect(monthlyResult.errors.isEmpty)
    }

    @Test
    func checkStatementsFromQuarterly() async throws {
        let resourcesURL = try #require(Bundle.module.url(forResource: "Resources", withExtension: nil))
        let results = try await StatementFileValidator.checkStatementsFrom(
            folder: resourcesURL,
            statementNames: ["Statement Quarterly"]
        )

        #expect(!results.isEmpty)
        let quarterlyResult = try #require(results.first { $0.name == "Statement Quarterly" })
        #expect(quarterlyResult.frequency == .quarterly)
        #expect(quarterlyResult.errors.isEmpty)
    }

    @Test
    func checkStatementsFromYearly() async throws {
        let resourcesURL = try #require(Bundle.module.url(forResource: "Resources", withExtension: nil))
        let results = try await StatementFileValidator.checkStatementsFrom(
            folder: resourcesURL,
            statementNames: ["Statement Yearly"]
        )

        #expect(!results.isEmpty)
        let yearlyResult = try #require(results.first { $0.name == "Statement Yearly" })
        #expect(yearlyResult.frequency == .yearly)
        #expect(yearlyResult.errors.isEmpty)
    }

    @Test
    func checkStatementsFromWithGaps() async throws {
        let resourcesURL = try #require(Bundle.module.url(forResource: "Resources", withExtension: nil))
        let results = try await StatementFileValidator.checkStatementsFrom(
            folder: resourcesURL,
            statementNames: ["Statement Gap"]
        )

        #expect(!results.isEmpty)
        let gapResult = try #require(results.first { $0.name == "Statement Gap" })
        #expect(gapResult.frequency == .monthly)
        #expect(!gapResult.errors.isEmpty)
    }

    @Test
    func checkStatementsFromMultipleTypes() async throws {
        let resourcesURL = try #require(Bundle.module.url(forResource: "Resources", withExtension: nil))
        let results = try await StatementFileValidator.checkStatementsFrom(
            folder: resourcesURL,
            statementNames: ["Statement A", "Statement B"]
        )

        #expect(results.count >= 2)
        #expect(results.contains { $0.name == "Statement A" })
        #expect(results.contains { $0.name == "Statement B" })
    }

    @Test
    func checkStatementsFromSingle() async throws {
        let resourcesURL = try #require(Bundle.module.url(forResource: "Resources", withExtension: nil))
        let results = try await StatementFileValidator.checkStatementsFrom(
            folder: resourcesURL,
            statementNames: ["Statement Single"]
        )

        #expect(!results.isEmpty)
        let singleResult = try #require(results.first { $0.name == "Statement Single" })
        #expect(singleResult.frequency == .single)
    }

    @Test
    func checkStatementsFromEmptyFolder() async throws {
        // Create a temporary empty directory
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let results = try await StatementFileValidator.checkStatementsFrom(
            folder: tempDir,
            statementNames: ["Statement"]
        )

        #expect(!results.isEmpty)
        let result = try #require(results.first)
        #expect(result.errors.contains { $0.contains("Could not find statement files") })
    }

    @Test
    func checkStatementsFromNoMatchingFiles() async throws {
        let resourcesURL = try #require(Bundle.module.url(forResource: "Resources", withExtension: nil))
        let results = try await StatementFileValidator.checkStatementsFrom(
            folder: resourcesURL,
            statementNames: ["NonExistent"]
        )

        #expect(!results.isEmpty)
        let result = try #require(results.first)
        #expect(result.errors.contains { $0.contains("Could not find statement files") })
    }

    @Test
    func checkStatementsFromMixedMonthlyAndQuarterly() async throws {
        let resourcesURL = try #require(Bundle.module.url(forResource: "Resources", withExtension: nil))
        let results = try await StatementFileValidator.checkStatementsFrom(
            folder: resourcesURL,
            statementNames: ["Statement Monthly", "Statement Quarterly"]
        )

        // Should find both monthly and quarterly statements
        #expect(results.count >= 2)
        #expect(results.contains { $0.name == "Statement Monthly" && $0.frequency == .monthly })
        #expect(results.contains { $0.name == "Statement Quarterly" && $0.frequency == .quarterly })
    }

}
