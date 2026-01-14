//
//  StatementValidatorError.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-10-13.
//

import Foundation

/// Errors which can occur when validating
public enum StatementValidatorError: LocalizedError, CaseIterable {
    /// No root founder was configued in the ledger
    case noRootFolder
    /// Error when reading properties of a file
    case resourceValuesMissing
}

extension StatementValidatorError {
    /// Human readable description of the error
    public var errorDescription: String? {
        switch self {
        case .noRootFolder:
            return "Did not find root folder configuration in ledger"
        case .resourceValuesMissing:
            return "Could not read properties of statement files"
        }
    }
}
