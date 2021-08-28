//
//  Settings.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2020-05-10.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation

/// Protocol to define a storage for the settings
public protocol SettingsStorage {

    /// Saves a value for a key
    func set(_ value: Any?, forKey defaultName: String)

    /// Gets a saved string for a given key
    func string(forKey defaultName: String) -> String?

    /// Gets a saved dictionary for a given key
    func dictionary(forKey defaultName: String) -> [String: Any]?
}

/// Constants releated to settings of the importer
public enum Settings {

    /// Storage key for the payee mapping
    static let payeesKey = "payees"
    /// Storage key for the account mapping
    static let accountsKey = "accounts"
    /// Storage key for the description mapping
    static let descriptionKey = "description"
    /// Storage key for the date tolerance to detect duplicate transactions
    static let dateToleranceKey = "date_tolerance"

    /// Default date tolerance to detect duplicate transactions
    static let defaultDateTolerance = 2 // days

    static let defaultAccountName = "Expenses:TODO"
    static let fallbackCommodity = "CAD"

    /// A Storage which saves the settings
    ///
    /// Default value is `UserDefaults.standard`
    public static var storage: SettingsStorage = UserDefaults.standard

    /// Mappings of descriptions the user saved when importing previous transactions
    ///
    /// These are automatically applied when importing and are only exported to allow apps
    /// to offer a settings screen to view and modify them.
    ///
    /// Keys are the original descriptions from the importer and the value are the new descriptions
    /// the user mapped them to
    public static var allDescriptionMappings: [String: String] {
       storage.dictionary(forKey: descriptionKey) as? [String: String] ?? [:]
    }

    /// Mappings of payees the user saved when importing previous transactions
    ///
    /// These are automatically applied when importing and are only exported to allow apps
    /// to offer a settings screen to view and modify them.
    ///
    /// Keys are the original descriptions from the importer and the values are the new payees
    /// the user mapped them to
    public static var allPayeeMappings: [String: String] {
        storage.dictionary(forKey: payeesKey) as? [String: String] ?? [:]
    }

    /// Mappings of accounts the user saved when importing previous transactions
    ///
    /// These are automatically applied when importing and are only exported to allow apps
    /// to offer a settings screen to view and modify them.
    ///
    /// Keys are payees and the values are account name strings the user mapped them to
    public static var allAccountMappings: [String: String] {
        storage.dictionary(forKey: accountsKey) as? [String: String] ?? [:]
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
            if let daysString = storage.string(forKey: Settings.dateToleranceKey), let days = Int(daysString) {
                return days
            }
            return defaultDateTolerance
        }
        set(newValue) {
            // the string conversion is a workaround for https://bugs.swift.org/plugins/servlet/mobile#issue/SR-15124
            storage.set("\(newValue)", forKey: dateToleranceKey)
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
        var desciptions = storage.dictionary(forKey: descriptionKey) as? [String: String] ?? [:]
        desciptions[key] = description
        storage.set(desciptions, forKey: descriptionKey)
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
        var payees = storage.dictionary(forKey: payeesKey) as? [String: String] ?? [:]
        payees[key] = payee
       storage.set(payees, forKey: payeesKey)
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
        var accounts = storage.dictionary(forKey: accountsKey) as? [String: String] ?? [:]
        accounts[key] = account
        storage.set(accounts, forKey: accountsKey)
    }

}

extension UserDefaults: SettingsStorage {
}
