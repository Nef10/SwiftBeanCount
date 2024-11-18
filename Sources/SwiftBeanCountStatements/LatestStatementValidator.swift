//
//  LatestStatementValidator.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-11-17.
//

import Foundation
import SwiftBeanCountModel

/// Helper to validate if the latest statement which should exist based on the current date is present
enum LatestStatementValidator {

    /// Validates if the latest statement which should exist based on the current date is present in the statement result
    ///
    /// It only checks for completed periods. E.g. for quarterly statements a Q3 statement would not be considered missing
    /// till Oct 1st, after Q3 is finished.
    ///
    /// - Parameters:
    ///   - account: Account to check - if the account is closed no check is performed
    ///   - result: Result with the date of the latest statements and the frequency
    /// - Returns: updated `StatementResult` with added warning and latestStatementMissing flag in case the statement is missing
    static func validate(_ account: Account, result: StatementResult) -> StatementResult {
        guard account.closing == nil else {
            return result
        }
        if let message = validateLastStatement(result) {
            return StatementResult(
                name: result.name,
                frequency: result.frequency,
                errors: result.errors,
                warnings: result.warnings + [message],
                startDate: result.startDate,
                endDate: result.endDate,
                latestStatementMissing: true)
        }
        return result
    }

    private static func validateLastStatement(_ result: StatementResult) -> String? {
        guard let endDate = result.endDate else {
            return nil
        }
        let end = Calendar.current.dateComponents([.month, .year], from: endDate)
        let current = Calendar.current.dateComponents([.month, .year], from: Date())
        let latestMonth = current.month! == 1 ? 12 : current.month! - 1
        switch result.frequency {
        case .monthly:
            let latestYear = latestMonth == 12 ? current.year! - 1 : current.year!
            if end.year! < latestYear || (end.month! < latestMonth && end.year! == latestYear) {
                return "Statements end \(end.month!)/\(end.year!) even though \(latestMonth)/\(latestYear) is already complete"
            }
        case .quarterly:
            let endQuarter = Int(StatementDatesValidator.quarterDateFormatter.string(from: endDate))!
            let currentQuarter = Int(StatementDatesValidator.quarterDateFormatter.string(from: Date()))!
            let latestQuarter = currentQuarter == 1 ? 4 : currentQuarter - 1
            let latestYear = latestQuarter == 4 ? current.year! - 1 : current.year!
            if end.year! < latestYear || (endQuarter < latestQuarter && end.year! == latestYear) {
                return "Statements end Q\(endQuarter)/\(end.year!) even though Q\(latestQuarter)/\(latestYear) is already complete"
            }
        case .yearly:
            let latestYear = current.year! - 1
            if end.year! < latestYear {
                return "Statements end \(end.year!) even though \(latestYear) is already complete"
            }
        default:
            return nil
        }
        return nil
    }

}
