//
//  Importer.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2020-05-10.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The ImporterFactory is used to create the different importer types
public enum ImporterFactory {

    /// Return all existing importer types
    ///
    /// As the importers do not need to be called directly, this should only
    /// be used in the help to allow displaying the help texts of all importers.
    ///
    /// - Returns: All existing importer types
    public static var allImporters: [Importer.Type] {
        FileImporterFactory.importers + TextImporterFactory.importers + DownloadImporterFactory.importers
    }

    /// Returns the names of the download importers
    ///
    /// These names can be used to create an importer via the `new(ledger:name:)` function
    ///
    /// - Returns: The names of all existing download importer types
    public static var downloadImporterNames: [String] {
        // see https://github.com/realm/SwiftLint/issues/5831
        // swiftlint:disable:next prefer_key_path
        DownloadImporterFactory.importers.map { $0.importerName }
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

    /// Creates an Inporter which downloads data from the internet
    /// - Parameters:
    ///   - ledger: existing ledger which is used to assist the import,
    ///             e.g. to read attributes of accounts
    ///   - name: Name of the importer to initialize
    /// - Returns: Importer, or nil if an importer with this name cannot be found
    public static func new(ledger: Ledger?, name: String) -> Importer? {
        DownloadImporterFactory.new(ledger: ledger, name: name)
    }

}

/// Struct describing a transaction which has been imported
public struct ImportedTransaction: Equatable {

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
    /// e.g. from stock purchases. These indicate this by settings this value to false.
    public let shouldAllowUserToEdit: Bool

    /// AccountName of the account the import is for
    ///
    /// You can use this to detect which posting the user should not edit
    /// Note: Not set on imported transactions which have shouldAllowUserToEdit set to false
    public let accountName: AccountName?

    init(
        _ transaction: Transaction,
        originalDescription: String = "",
        possibleDuplicate: Transaction? = nil,
        shouldAllowUserToEdit: Bool = false,
        accountName: AccountName? = nil
    ) {
        self.transaction = transaction
        self.originalDescription = originalDescription
        self.possibleDuplicate = possibleDuplicate
        self.shouldAllowUserToEdit = shouldAllowUserToEdit
        self.accountName = accountName
    }

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
        guard !originalDescription.isEmpty else {
            return
        }
        if !payee.isEmpty {
            Settings.setPayeeMapping(key: originalDescription, payee: payee)
            if let accountName {
                Settings.setAccountMapping(key: payee, account: accountName.fullName)
            }
        }
        Settings.setDescriptionMapping(key: originalDescription, description: description)
    }

}

/// Type of user input requested by the importer
public enum ImporterInputRequestType {
    /// Normal text, with suggestions (optional)
    case text([String])
    /// Secrect, should not be visible if the user enters it
    case secret
    /// one time passcase, can offer the use auto fill from text or similr
    case otp
    /// a questions which the user can answer with yes or no
    case bool
    /// a choice betweeen multiple options
    case choice([String])
}

/// Protocol of the delegate of an Importer
public protocol ImporterDelegate: AnyObject {

    /// Request for a user input in form of a text, which is required for the importer to operate
    ///
    /// - Parameters:
    ///   - name: name of the input required
    ///   - type: type of the input requested
    ///   - completion: function to pass input to. Returns if the input was accepted.
    ///                 In case an input was not accepted, please call the function again.
    func requestInput(name: String, type: ImporterInputRequestType, completion: @escaping (String) -> Bool)

    /// Request to save a credential
    ///
    /// Importers which require authenticate can for example save tokens this way.
    /// Make sure to properly encrypt the storage.
    ///
    /// It is not strictly required, you can just do nothing in this method.
    ///
    /// - Parameters:
    ///   - value: value to save
    ///   - key: key to retreive the value. Importers are required to ensure the uniqueness.
    func saveCredential(_ value: String, for key: String)

    /// Request for a saved credential
    ///
    /// It is not strictly required, you can just always return nil.
    ///
    /// Parameter: key: key used to save the value
    /// Returns: String with the value or nil if no value can be found
    func readCredential(_ key: String) -> String?

    #if canImport(UIKit)

    /// Request a view to show / operate in
    /// Returns: UIView?
    func view() -> UIView?

    #elseif canImport(AppKit)

    /// Request a view to show / operate in
    /// Returns: NSView?
    func view() -> NSView?

    #endif

    #if canImport(UIKit) || canImport(AppKit)

    /// Request to remove the previously requested view from the screen
    func removeView()

    #endif

    /// Indicates an error occured
    ///
    /// - Parameters:
    ///   - error: The error which occured. Display the localized description to the user
    ///   - completion: completion handler to call when the user has acknowledged the error
    func error(_: Error, completion: @escaping () -> Void)

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

extension ImporterInputRequestType: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.secret, .secret),
             (.otp, .otp),
             (.bool, .bool):
            return true
        case let (.text(lhsArray), .text(rhsArray)):
            return lhsArray.sorted() == rhsArray.sorted()
        case let (.choice(lhsArray), .choice(rhsArray)):
            return lhsArray.sorted() == rhsArray.sorted()
        default:
            return false
        }
    }
}
