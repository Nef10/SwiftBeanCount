//
//  AccountStartEndDateValidator.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-11-17.
//

import Foundation
import SwiftBeanCountModel

/// Helper to check if statements are present for the whole period an account was open
enum AccountStartEndDateValidator {

    /// Checks if statements are present for the whole period an account was open
    ///
    /// Note: If an account is still open it will not check for the latest statement. Use `LatestStatementValidator` instead.
    ///
    /// - Parameters:
    ///   - account: account to check with the opening and closing date
    ///   - result: result with the start and end dates of the found statements as well as the frequency
    /// - Returns: updated `StatementResult` with added warnings if neccessary
    static func validate(_ account: Account, result: StatementResult) -> StatementResult {
        var warnings = result.warnings
        if let openingDate = account.opening {
            if let message = validateOpeningDate(openingDate, result: result) {
                warnings += [message]
            }
        }
        if let closingDate = account.closing {
            if let message = validateClosingDate(closingDate, result: result) {
                warnings += [message]
            }
        }
        return StatementResult(name: result.name, frequency: result.frequency, errors: result.errors, warnings: warnings, startDate: result.startDate, endDate: result.endDate)
    }

    private static func validateOpeningDate(_ openingDate: Date, result: StatementResult) -> String? {
        guard let startDate = result.startDate else {
            return nil
        }
        let start = Calendar.current.dateComponents([.month, .year], from: startDate)
        let opening = Calendar.current.dateComponents([.month, .year], from: openingDate)
        switch result.frequency {
        case .monthly:
            if start.year != opening.year || start.month != opening.month {
                return "Account opened \(opening.month!)/\(opening.year!) but statements start \(start.month!)/\(start.year!)"
            }
        case .quarterly:
            let startQuarter = Int(StatementDatesValidator.quarterDateFormatter.string(from: startDate))!
            let openingQuarter = Int(StatementDatesValidator.quarterDateFormatter.string(from: openingDate))!
            if start.year! != opening.year! || startQuarter != openingQuarter {
                return "Account opened Q\(openingQuarter)/\(opening.year!) but statements start Q\(startQuarter)/\(start.year!)"
            }
        case .yearly:
            if start.year! != opening.year! {
                return "Account opened \(opening.year!) but statements start \(start.year!)"
            }
        default:
            return nil
        }
        return nil
    }

    private static func validateClosingDate(_ closingDate: Date, result: StatementResult) -> String? {
        guard let endDate = result.endDate else {
            return nil
        }
        let closing = Calendar.current.dateComponents([.month, .year], from: closingDate)
        let end = Calendar.current.dateComponents([.month, .year], from: endDate)
        switch result.frequency {
        case .monthly:
            if end.year != closing.year || end.month != closing.month {
                return "Account closed \(closing.month!)/\(closing.year!) but statements end \(end.month!)/\(end.year!)"
            }
        case .quarterly:
            let endQuarter = Int(StatementDatesValidator.quarterDateFormatter.string(from: endDate))!
            let closingQuarter = Int(StatementDatesValidator.quarterDateFormatter.string(from: closingDate))!
            if end.year! != closing.year! || endQuarter != closingQuarter {
                return "Account closed Q\(closingQuarter)/\(closing.year!) but statements end Q\(endQuarter)/\(end.year!)"
            }
        case .yearly:
            if end.year! != closing.year! {
                return "Account closed \(closing.year!) but statements end \(end.year!)"
            }
        default:
            return nil
        }
        return nil
    }

}
