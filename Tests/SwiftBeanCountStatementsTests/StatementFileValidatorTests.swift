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
    func statementsFromMonthly() async throws {
        let resourcesURL = try #require(Bundle.module.url(forResource: "Resource", withExtension: nil))
        let results = try await StatementFileValidator.checkStatementsFrom(
            folder: resourcesURL,
            statementNames: ["Statement Monthly"]
        )

        #expect(results.count == 1)
        let monthlyResult = try #require(results.first { $0.name == "Statement Monthly" })
        #expect(monthlyResult.frequency == .monthly)
        #expect(monthlyResult.errors.isEmpty)
    }

    @Test
    func statementsFromQuarterly() async throws {
        let resourcesURL = try #require(Bundle.module.url(forResource: "Resource", withExtension: nil))
        let results = try await StatementFileValidator.checkStatementsFrom(
            folder: resourcesURL,
            statementNames: ["Statement Quarterly"]
        )

        #expect(results.count == 1)
        let quarterlyResult = try #require(results.first { $0.name == "Statement Quarterly" })
        #expect(quarterlyResult.frequency == .quarterly)
        #expect(quarterlyResult.errors.isEmpty)
    }

    @Test
    func statementsFromYearly() async throws {
        let resourcesURL = try #require(Bundle.module.url(forResource: "Resource", withExtension: nil))
        let results = try await StatementFileValidator.checkStatementsFrom(
            folder: resourcesURL,
            statementNames: ["Statement Yearly"]
        )

        #expect(results.count == 1)
        let yearlyResult = try #require(results.first { $0.name == "Statement Yearly" })
        #expect(yearlyResult.frequency == .yearly)
        #expect(yearlyResult.errors.isEmpty)
    }

    @Test
    func statementsFromWithGaps() async throws {
        let resourcesURL = try #require(Bundle.module.url(forResource: "Resource", withExtension: nil))
        let results = try await StatementFileValidator.checkStatementsFrom(
            folder: resourcesURL,
            statementNames: ["Statement Gap"]
        )

        #expect(results.count == 1)
        let gapResult = try #require(results.first { $0.name == "Statement Gap" })
        // With only 3 files (Jan, Feb, Apr), it can't reliably determine the frequency
        // The algorithm should detect it as unknown since there's not enough data
        #expect(gapResult.frequency == .unkown)
        #expect(gapResult.errors.count == 1)
        #expect(gapResult.errors.contains { $0.contains("Frequency could not be determined") })
    }

    @Test
    func statementsFromMultipleTypes() async throws {
        let resourcesURL = try #require(Bundle.module.url(forResource: "Resource", withExtension: nil))
        let results = try await StatementFileValidator.checkStatementsFrom(
            folder: resourcesURL,
            statementNames: ["Statement A", "Statement Monthly"]
        )

        #expect(results.count == 2)
        // Both Statement A and Statement B should be detected
        let hasA = results.contains { $0.name == "Statement A" }
        let hasB = results.contains { $0.name == "Statement Monthly" }
        #expect(hasA && hasB)
    }

    @Test
    func statementsFromSingle() async throws {
        let resourcesURL = try #require(Bundle.module.url(forResource: "Resource", withExtension: nil))
        let results = try await StatementFileValidator.checkStatementsFrom(
            folder: resourcesURL,
            statementNames: ["Statement Single"]
        )

        #expect(results.count == 1)
        let singleResult = try #require(results.first { $0.name == "Statement Single" })
        #expect(singleResult.frequency == .single)
        #expect(singleResult.errors.isEmpty)
    }

    @Test
    func statementsFromEmptyFolder() async throws {
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

        #expect(results.count == 1)
        let result = try #require(results.first)
        #expect(result.frequency == .unkown)
        #expect(result.errors.count == 1)
        #expect(result.errors.contains { $0.contains("Could not find statement files") })
    }

    @Test
    func statementsFromNoMatchingFiles() async throws {
        let resourcesURL = try #require(Bundle.module.url(forResource: "Resource", withExtension: nil))
        let results = try await StatementFileValidator.checkStatementsFrom(
            folder: resourcesURL,
            statementNames: ["NonExistent"]
        )

        #expect(results.count == 1)
        let result = try #require(results.first)
        #expect(result.frequency == .unkown)
        #expect(result.errors.count == 1)
        #expect(result.errors.contains { $0.contains("Could not find statement files") })
    }

    @Test
    func statementsFromMixedMonthlyAndQuarterly() async throws {
        let resourcesURL = try #require(Bundle.module.url(forResource: "Resource", withExtension: nil))
        let results = try await StatementFileValidator.checkStatementsFrom(
            folder: resourcesURL,
            statementNames: ["Statement Monthly", "Statement Quarterly"]
        )

        // Should find both monthly and quarterly statements
        #expect(results.count == 2)
        #expect(results.contains { $0.name == "Statement Monthly" && $0.frequency == .monthly && $0.errors.isEmpty })
        #expect(results.contains { $0.name == "Statement Quarterly" && $0.frequency == .quarterly && $0.errors.isEmpty })
    }

}
