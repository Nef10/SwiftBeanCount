//
//  StatementValidatorErrorTests.swift
//  SwiftBeanCountStatementsTests
//
//  Created by GitHub Copilot on 2026-01-13.
//

import Foundation
@testable import SwiftBeanCountStatements
import Testing

@Suite
struct StatementValidatorErrorTests {

    @Test
    func noRootFolderErrorDescription() {
        let error = StatementValidatorError.noRootFolder
        let description = error.localizedDescription
        #expect(description == "Did not find root folder configuration in ledger")
    }

    @Test
    func resourceValuesMissingErrorDescription() {
        let error = StatementValidatorError.resourceValuesMissing
        let description = error.localizedDescription
        #expect(description == "Could not read properties of statement files")
    }

    @Test
    func errorDescriptionNotNil() {
        for error in [StatementValidatorError.noRootFolder, StatementValidatorError.resourceValuesMissing] {
            #expect(error.errorDescription != nil)
        }
    }

}
