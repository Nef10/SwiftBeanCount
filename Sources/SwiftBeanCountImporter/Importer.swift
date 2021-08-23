//
//  Importer.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2020-05-10.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

/// The ImporterFactory is used to create the different importer types
public enum ImporterFactory {

    /// Return all existing importer types
    ///
    /// As the importers do not need to be called directly, this should only
    /// be used in the settings to allow displaying all settings of all importers
    ///
    /// - Returns: All existing importer types
    public static var allImporters: [Importer.Type] {
        FileImporterFactory.importers + TextImporterFactory.importers
    }

    // Returns a TextImporter, or nil if the text cannot be imported
    /// - Parameters:
    ///   - ledger: existing ledger which is used to assist the import,
    ///             e.g. to read attributes of accounts
    ///   - transaction: text of a transaction
    ///   - balance: text of a balance
    /// - Returns: TextImporter, or nil if the text cannot be imported
    public static func new(ledger: Ledger?, transaction: String, balance: String) -> TextImporter? {
        TextImporterFactory.new(ledger: ledger, transaction: transaction, balance: balance)
    }

    /// Returns a FileImporter, or nil if the file cannot be imported
    /// - Parameters:
    ///   - ledger: existing ledger which is used to assist the import,
    ///             e.g. to read attributes of accounts
    ///   - url: URL of the file to import
    /// - Returns: FileImporter, or nil if the file cannot be imported
    public static func new(ledger: Ledger?, url: URL?) -> FileImporter? {
        FileImporterFactory.new(ledger: ledger, url: url)
    }

}

/// Represents a single setting of an importer
public struct ImporterSetting {

    let identifier: String

    /// User friendly name of the setting
    public let name: String

}

/// Protocol to represent an Importer, regardless of type
public protocol Importer {

    /// User friendly name of the Importer
    ///
    /// Should be used in the settings to group the setting of this importer.
    static var settingsName: String { get }

    /// Settings of this importer
    static var settings: [ImporterSetting] { get }

    /// Get possible account names for this importer
    /// - Parameter ledger: existing ledger to allow reading attributes of the accounts
    ///                     which can be used to determine to correct account
    func possibleAccountNames(for ledger: Ledger?) -> [AccountName]

    /// Tells the importer to use the named account for the import.
    ///
    /// Must be called before importing if `possibleAccountNames` does not return
    /// exactly one account
    /// - Parameter name: name for the accout to use
    func useAccount(name: AccountName)

}

extension Importer {

    /// Get the settings value of a specific setting
    /// - Parameter setting: Setting to read
    /// - Returns: value of the setting
    public static func get(setting: ImporterSetting) -> String? {
        UserDefaults.standard.string(forKey: getUserDefaultsKey(for: setting))
    }

    /// Set the value of a sepcific setting
    /// - Parameters:
    ///   - setting: Setting to write
    ///   - value: value to set
    public static func set(setting: ImporterSetting, to value: String) {
        UserDefaults.standard.set(value, forKey: getUserDefaultsKey(for: setting))
    }

    /// Get the key used in the `UserDefaults` to save a particular setting
    /// - Parameter setting: Setting of which you want to have the key
    /// - Returns: key used in the `UserDefaults`
    public static func getUserDefaultsKey(for setting: ImporterSetting) -> String {
        "\(String(describing: self)).\(setting.identifier)"
    }

}
