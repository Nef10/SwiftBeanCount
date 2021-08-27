//
//  Settings.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2020-05-10.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation

/// Constants releated to settings of the importer
public enum Settings {

    /// `UserDefaults` key for the payee mapping
    static let payeesUserDefaultKey = "payees"
    /// `UserDefaults` key for the account mapping
    static let accountsUserDefaultsKey = "accounts"
    /// `UserDefaults` key for the description mapping
    static let descriptionUserDefaultsKey = "description"
    /// `UserDefaults` key for the date tolerance to detect duplicate transactions
    static let dateToleranceUserDefaultsKey = "date_tolerance"

    /// Default date tolerance to detect duplicate transactions
    static let defaultDateTolerance = 2 // days

    static let defaultAccountName = "Expenses:TODO"
    static let fallbackCommodity = "CAD"

    /// Mappings of descriptions the user saved when importing previous transactions
    ///
    /// These are automatically applied when importing and are only exported to allow apps
    /// to offer a settings screen to view and modify them.
    ///
    /// Keys are the original descriptions from the importer and the value are the new descriptions
    /// the user mapped them to
    public static var allDescriptionMappings: [String: String] {
        UserDefaults.standard.dictionary(forKey: descriptionUserDefaultsKey) as? [String: String] ?? [:]
    }

    /// Mappings of payees the user saved when importing previous transactions
    ///
    /// These are automatically applied when importing and are only exported to allow apps
    /// to offer a settings screen to view and modify them.
    ///
    /// Keys are the original descriptions from the importer and the values are the new payees
    /// the user mapped them to
    public static var allPayeeMappings: [String: String] {
        UserDefaults.standard.dictionary(forKey: payeesUserDefaultKey) as? [String: String] ?? [:]
    }

    /// Mappings of accounts the user saved when importing previous transactions
    ///
    /// These are automatically applied when importing and are only exported to allow apps
    /// to offer a settings screen to view and modify them.
    ///
    /// Keys are payees and the values are account name strings the user mapped them to
    public static var allAccountMappings: [String: String] {
        UserDefaults.standard.dictionary(forKey: accountsUserDefaultsKey) as? [String: String] ?? [:]
    }

    // Date tolerance to check for duplicate transactions when importing
    ///
    /// See also `dateToleranceInDays` which offers this value as Int
    public static var dateTolerance: TimeInterval {
        Double(dateToleranceInDays * 60 * 60 * 24)
    }

    /// Date tolerance in days to check for duplicate transactions when importing
    ///
    /// See also `dateTolerance` which offers this value as `TimeInterval`
    public static var dateToleranceInDays: Int {
        get {
            if let daysString = UserDefaults.standard.string(forKey: Settings.dateToleranceUserDefaultsKey), let days = Int(daysString) {
                return days
            }
            return defaultDateTolerance
        }
        set(newValue) {
            // the string conversion is a workaround for https://bugs.swift.org/plugins/servlet/mobile#issue/SR-15124
            UserDefaults.standard.set("\(newValue)", forKey: dateToleranceUserDefaultsKey)
        }
    }

    /// Save a new mapping of a description the user wants to automatically apply to
    /// new transactions
    ///
    /// Note: Do not use this function to save the mapping for an imported transaction
    /// (use the functions on `ImportedTransaction` instead), but only for adjustments
    /// made on a settings screen.
    ///
    /// - Parameters:
    ///   - key: original description of the imported transaction
    ///   - description: new description - Use nil to delete a mapping.
    public static func setDescriptionMapping(key: String, description: String?) {
        var desciptions = UserDefaults.standard.dictionary(forKey: descriptionUserDefaultsKey) as? [String: String] ?? [:]
        desciptions[key] = description
        UserDefaults.standard.set(desciptions, forKey: descriptionUserDefaultsKey)
    }

    /// Save a new mapping of a payee the user wants to automatically apply to
    /// new transactions with a certain description
    ///
    /// Note: Do not use this function to save the mapping for an imported transaction
    /// (use the functions on `ImportedTransaction` instead), but only for adjustments
    /// made on a settings screen.
    ///
    /// - Parameters:
    ///   - key: original description of an imported transaction
    ///   - payee: payee to map transactions with this description to. Use nil to delete a mapping.
    public static func setPayeeMapping(key: String, payee: String?) {
        var payees = UserDefaults.standard.dictionary(forKey: payeesUserDefaultKey) as? [String: String] ?? [:]
        payees[key] = payee
        UserDefaults.standard.set(payees, forKey: payeesUserDefaultKey)
    }

    /// Save a new mapping of an account the user wants to automatically apply to
    /// new transactions from a certain payee
    ///
    /// Note: Do not use this function to save the mapping for an imported transaction
    /// (use the functions on `ImportedTransaction` instead), but only for adjustments
    /// made on a settings screen.
    ///
    /// - Parameters:
    ///   - key: payee
    ///   - account: account name string - Use nil to delete a mapping
    public static func setAccountMapping(key: String, account: String?) {
        var accounts = UserDefaults.standard.dictionary(forKey: accountsUserDefaultsKey) as? [String: String] ?? [:]
        accounts[key] = account
        UserDefaults.standard.set(accounts, forKey: accountsUserDefaultsKey)
    }

}
