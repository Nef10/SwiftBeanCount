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
    /// be used in the help to allow displaying the help texts of all importers.
    ///
    /// - Returns: All existing importer types
    public static var allImporters: [Importer.Type] {
        FileImporterFactory.importers + TextImporterFactory.importers
    }

    // Creates an Importer to import a transaction and balance String, or nil if the text cannot be imported
    /// - Parameters:
    ///   - ledger: existing ledger which is used to assist the import,
    ///             e.g. to read attributes of accounts
    ///   - transaction: text of a transaction
    ///   - balance: text of a balance
    /// - Returns: Importer, or nil if the text cannot be imported
    public static func new(ledger: Ledger?, transaction: String, balance: String) -> Importer? {
        TextImporterFactory.new(ledger: ledger, transaction: transaction, balance: balance)
    }

    /// Creates an Importer to import a file, or nil if the file cannot be imported
    /// - Parameters:
    ///   - ledger: existing ledger which is used to assist the import,
    ///             e.g. to read attributes of accounts
    ///   - url: URL of the file to import
    /// - Returns: Importer, or nil if the file cannot be imported
    public static func new(ledger: Ledger?, url: URL?) -> Importer? {
        FileImporterFactory.new(ledger: ledger, url: url)
    }

}

/// Struct describing a transaction which has been imported
public struct ImportedTransaction {

    /// Transaction which has been imported
    public let transaction: Transaction

    /// The original description from the file. This is used to allow saving
    /// of description and payee mapping.
    let originalDescription: String

    /// Transaction from the ledger of which the imported transaction
    /// might be a duplicate
    public let possibleDuplicate: Transaction?

    /// Indicates if the app should allow the user to edit the imported transaction.
    ///
    /// Some importer output transactions which normally do not require edits
    /// e.g. from stock purchases. These indicate this by settings this value to true.
    public let shouldAllowUserToEdit: Bool

    /// AccountName of the account the import is for
    ///
    /// You can use this to detect which posting the user should not edit
    /// Note: Not set on imported transactions which have shouldAllowUserToEdit set to false
    public let accountName: AccountName?

    /// Saves a mapping of an imported transaction description to a different
    /// description, payee as well as account name
    ///
    /// Note: You should ask to user if they want to save the mapping, ideally
    /// separately for the account and description/payee
    ///
    /// - Parameters:
    ///   - description: new description to use next time a transaction with the same origial description is imported
    ///   - payee: new payee to use next time a transaction with the same origial description is imported
    ///   - accountName: accountName to use next time a transaction with this payee is imported
    public func saveMapped(description: String, payee: String, accountName: AccountName?) {
        if !payee.isEmpty {
            Settings.setPayeeMapping(key: originalDescription, payee: payee)
            if let accountName = accountName {
                Settings.setAccountMapping(key: payee, account: accountName.fullName)
            }
        }
        Settings.setDescriptionMapping(key: originalDescription, description: description)
    }

}

/// Protocol of the delegate of an Importer
public protocol ImporterDelegate: AnyObject {

    /// Request for a user input, which is required for the importer to operate
    ///
    /// - Parameters:
    ///   - name: name of the input required
    ///   - suggestions: suggestions for the input - may be empty
    ///   - allowSaving: if the app is allowed to offer the user to save this input
    ///                  To save it use the importName together with the name as key.
    ///   - allowSaved: if the app can just respond with a saved value.
    ///                   E.g. if asked for a username, which has allowSaving on, the library
    ///                   would first request the input with allowSaved set to true.
    ///                   But if the username is incorrect it would request again
    ///                   with allowSaved false, upon which the app should remove the saved value.
    ///   - completion: function to pass input to. Returns if the input was accepted.
    ///                 In case an input was not accepted, please call the function again.
    func requestInput(name: String, suggestions: [String], allowSaving: Bool, allowSaved: Bool, completion: @escaping (String) -> Bool)

    // Request for a secret user input, which is required for the importer to operate
    ///
    /// - Parameters:
    ///   - name: name of the input required
    ///   - isSecret: if the requested input is considered a secret, e.g. to show a password type input field
    ///   - allowSaving: if the app is allowed to offer the user to save this input
    ///                  E.g. this could be true for a password but false for an OTP.
    ///                  To save it use the importName together with the name as key.
    ///   - allowSaved: if the app can just respond with a saved value.
    ///                   E.g. if asked for a password, which has allowSaving on, the library
    ///                   would first request the input with allowSaved set to true.
    ///                   But if the password is incorrect it would request again
    ///                   with allowSaved false, upon which the app should remove the saved value.
    ///   - completion: function to pass input to. Returns if the input was accepted.
    ///                 In case an input was not accepted, please call the function again.
    func requestSecretInput(name: String, allowSaving: Bool, allowSaved: Bool, completion: @escaping (String) -> Bool)

}

/// Protocol to represent an Importer, regardless of type
public protocol Importer {

    /// User friendly name of the importer
    ///
    /// Can be used in the help
    static var importerName: String { get }

    /// Help text for the importer
    static var helpText: String { get }

    /// A description of the import, e.g. a file name together with the importer name
    ///
    /// Can be used in the UI when an importer requests more information, e.g.
    /// account selection or credentials
    var importName: String { get }

    /// Delegate to request input
    var delegate: ImporterDelegate? { get set }

    /// Loads the data to import
    ///
    /// You must call this method before you call `nextTransaction()`.
    /// You might want to show a loading indicator during the loading, as depending
    /// on the importer this might take some time.
    func load()

    /// Returns the next `ImportedTransaction`
    ///
    /// You must call `load` before you call this function.
    /// Returns nil when there are no more lines left.
    func nextTransaction() -> ImportedTransaction?

    /// Returns balances to be imported
    ///
    /// Only some importer can import balances, so it might return an empty array
    /// Only call this function after you received all transactions
    func balancesToImport() -> [Balance]

    /// Returns prices to be imported
    ///
    /// Only some importer can import prices, so it might return an empty array
    /// Only call this function after you received all transactions
    func pricesToImport() -> [Price]

}
