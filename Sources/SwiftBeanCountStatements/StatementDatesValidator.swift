//
//  StatementValidator.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-10-14.
//

import Foundation

/// Frequency in which account statements can occur
public enum StatementFrequency: String, CaseIterable, Hashable {
    /// Only a single document was found
    case single
    /// Statements happend once a month
    case monthly
    /// Statements happen once quarter / three month
    case quarterly
    /// Statements happen once a year
    case yearly
    /// Unable to determine a regular frequency of the statements
    case unkown
}

/// Result of a statement validation
public struct StatementResult: Hashable, Identifiable {
    /// Unique ID
    public let id = UUID()
    /// Name of the file
    public let name: String
    /// Frequency the statement is issued
    public let frequency: StatementFrequency
    /// Errors found while validating
    public let errors: [String]
    /// Warnings found while validating
    public let warnings: [String]
    /// Date of the earliest statement found
    public let startDate: Date?
    /// Date of the latest statement found
    public let endDate: Date?
    /// If after the latest statement there should be another one based on todays date
    public let latestStatementMissing: Bool

    init(
        name: String,
        frequency: StatementFrequency,
        errors: [String] = [],
        warnings: [String] = [],
        startDate: Date? = nil,
        endDate: Date? = nil,
        latestStatementMissing: Bool = false
    ) {
        self.name = name
        self.frequency = frequency
        self.errors = errors
        self.warnings = warnings
        self.startDate = startDate
        self.endDate = endDate
        self.latestStatementMissing = latestStatementMissing
    }

}

/// Helps validate if all statements are present based on the statement dates
public enum StatementDatesValidator {

    static let quarterDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "Q"
        return dateFormatter
    }()

    /// Checks an array of dates for a recurring pattern
    ///
    /// Identifies if the dates occur on a monthly, quarterly or yearly pattern
    /// If a pattern is identified, it will check for any missing occurrences.
    ///
    /// - Parameters:
    ///   - dates: array of dates to check
    ///   - name: file name, will be added to the result
    /// - Returns: `StatementResult` with the identified frequency, errors and warnings
    public static func checkDates(_ dates: [Date], for name: String) -> StatementResult {
        let dates = dates.sorted(by: <)
        let frequency = identifyFrequency(dates)
        var errors = [String]()
        var warnings = [String]()
        switch frequency {
        case .yearly:
            errors = checkYearly(dates)
        case .monthly:
            errors = checkMonthly(dates)
        case .quarterly:
            errors = checkQuarterly(dates)
        case .single:
            let date = Calendar.current.dateComponents([.month, .year], from: dates.first!)
            warnings = ["Only single statement found for \(date.month!)/\(date.year!)"]
        case .unkown:
            errors = ["Frequency could not be determined"]
        }
        return StatementResult(name: name, frequency: frequency, errors: Array(Set(errors)), warnings: Array(Set(warnings)), startDate: dates.first!, endDate: dates.last!)
    }

    /// Tried to determine the frequency of statements based on the dates
    ///
    /// Identifies if the dates occur on a monthly, quarterly or yearly pattern
    ///
    /// - Parameters:
    ///   - dates: array of dates to check
    /// - Returns: `StatementFrequency`
    public static func identifyFrequency(_ dates: [Date]) -> StatementFrequency {
        guard dates.count > 1 else {
            return .single
        }
        var lastDate: Date?
        var differences = [Int]()
        for date in dates {
            guard let previousDate = lastDate else {
                lastDate = date
                continue
            }
            if let difference = Calendar.current.dateComponents([.day], from: previousDate, to: date).day {
                differences.append(difference)
            }
            lastDate = date
        }
        differences.sort()
        let median = Double(differences[differences.count / 2] + (differences.reversed()[differences.count / 2])) / 2.0
        if median >= 25 && median <= 31 {
            return .monthly
        }
        if median >= 83 && median <= 98 {
            return .quarterly
        }
        if median >= 320 && median <= 400 {
            return .yearly
        }
        return .unkown
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private static func checkQuarterly(_ dates: [Date]) -> [String] {
        var errors = [String]()
        let first = Calendar.current.dateComponents([.year], from: dates.first!), firstYear = first.year!, firstQuarter = Int(quarterDateFormatter.string(from: dates.first!))!
        var lastQuarter = firstQuarter == 1 ? 4 : firstQuarter - 1, lastYear = firstQuarter == 1 ? firstYear - 1 : firstYear
        for date in dates {
            let quarter = Int(quarterDateFormatter.string(from: date))!
            var date = Calendar.current.dateComponents([.year], from: date)
            date.quarter = quarter
            if date.year == lastYear {
                // all good if date.quarter == lastQuarter + 1
                if date.quarter! == lastQuarter {
                    errors.append("Multiple Statements for Quarter \(date.quarter!)/\(lastYear)")
                } else if date.quarter! == lastQuarter + 2 {
                    errors.append("No Statements for Quarter \(lastQuarter + 1)/\(lastYear)")
                } else if date.quarter! > lastQuarter + 2 {
                    errors.append("No Statements between Quarter \(lastQuarter)/\(lastYear) and \(date.quarter!)/\(date.year!)")
                }
            } else if date.year! == lastYear + 1 {
                // all good if lastQuarter == 4 and date.quarter == 1
                if lastQuarter == 4 {
                    if date.quarter == 2 {
                        errors.append("No Statements for Quarter 1/\(date.year!)")
                    } else if date.quarter! > 2 {
                        errors.append("No Statements between Quarter 4/\(lastYear) and \(date.quarter!)/\(date.year!)")
                    }
                } else if lastQuarter == 3 {
                    if date.quarter == 1 {
                        errors.append("No Statements for Quarter 4/\(lastYear)")
                    } else if date.quarter! > 1 {
                        errors.append("No Statements between Quarter 3/\(lastYear) and \(date.quarter!)/\(date.year!)")
                    }
                } else {
                    errors.append("No Statements between Quarter \(lastQuarter)/\(lastYear) and \(date.quarter!)/\(date.year!)")
                }
            } else if date.year! > lastYear + 1 {
                errors.append("No Statements between Quarter \(lastQuarter)/\(lastYear) and \(date.quarter!)/\(date.year!)")
            }
            lastQuarter = date.quarter!
            lastYear = date.year!
        }
        return errors
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private static func checkMonthly(_ dates: [Date]) -> [String] {
        var errors = [String]()
        let first = Calendar.current.dateComponents([.month, .year], from: dates.first!), firstYear = first.year!, firstMonth = first.month!
        var lastMonth = firstMonth == 1 ? 12 : firstMonth - 1, lastYear = firstMonth == 1 ? firstYear - 1 : firstYear
        for date in dates {
            let date = Calendar.current.dateComponents([.month, .year], from: date)
            if date.year == lastYear {
                // all good if date.month == lastMonth + 1
                if date.month! == lastMonth {
                    errors.append("Multiple Statements for Month \(date.month!)/\(lastYear)")
                } else if date.month! == lastMonth + 2 {
                    errors.append("No Statements for Month \(lastMonth + 1)/\(lastYear)")
                } else if date.month! > lastMonth + 2 {
                    errors.append("No Statements between Month \(lastMonth)/\(lastYear) and \(date.month!)/\(date.year!)")
                }
            } else if date.year! == lastYear + 1 {
                // all good if lastMonth == 12 and date.month == 1
                if lastMonth == 12 {
                    if date.month == 2 {
                        errors.append("No Statements for Month 1/\(date.year!)")
                    } else if date.month! > 2 {
                        errors.append("No Statements between Month 12/\(lastYear) and \(date.month!)/\(date.year!)")
                    }
                } else if lastMonth == 11 {
                    if date.month == 1 {
                        errors.append("No Statements for Month 12/\(lastYear)")
                    } else if date.month! > 1 {
                        errors.append("No Statements between Month 11/\(lastYear) and \(date.month!)/\(date.year!)")
                    }
                } else {
                    errors.append("No Statements between Month \(lastMonth)/\(lastYear) and \(date.month!)/\(date.year!)")
                }
            } else if date.year! > lastYear + 1 {
                errors.append("No Statements between Month \(lastMonth)/\(lastYear) and \(date.month!)/\(date.year!)")
            }
            lastMonth = date.month!
            lastYear = date.year!
        }
        return errors
    }

    private static func checkYearly(_ dates: [Date]) -> [String] {
        var errors = [String]()
        let firstYear = Calendar.current.dateComponents([.year], from: dates.first!).year!
        var lastYear = firstYear - 1
        for date in dates {
            let year = Calendar.current.dateComponents([.year], from: date)
            // all good if year.year == lastYear + 1
            if year.year! == lastYear {
                errors.append("Multiple Statements for Year \(lastYear)")
            } else if year.year! == lastYear + 2 {
                errors.append("No Statements for Year \(lastYear + 1)")
            } else if year.year! > lastYear + 2 {
                errors.append("No Statements between Year \(lastYear) and \(year.year!)")
            }
            lastYear = year.year!
        }
        return errors
    }

}
