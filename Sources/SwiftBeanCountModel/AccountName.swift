//
//  AccountName.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2020-05-22.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation

/// Errors an AccountName can throw
public enum AccountNameError: Error {
    /// an invalid account name
    case invaildName(String)
}

/// Struct with represents just the name of an Account
public struct AccountName: AccountItem {

    /// Full quilified name of the account, e.g. Assets:Cash:CAD
    public let fullName: String

    /// Type, see `AccountType`
    public let accountType: AccountType

    /// Last part of the name, for **Assets:Cash:CAD** this would be **CAD**
    public var nameItem: String {
        String(describing: fullName.split(separator: Account.nameSeperator).last!)
    }

    /// Creates an Account Name
    ///
    /// - Parameters:
    ///   - name: a vaild name for the account
    /// - Throws: AccountNameError.invaildName in case the account name is invalid
    public init(_ name: String) throws {
        guard Self.isNameValid(name) else {
            throw AccountNameError.invaildName(name)
        }
        self.fullName = name
        self.accountType = Self.getAccountType(for: name)
    }

    /// Gets the `AccountType` from a name string
    ///
    /// In case of an invalid account name the function might just return .assets
    ///
    /// - Parameter name: valid account name
    /// - Returns: `AccountType` of the account with this name
    private static func getAccountType(for name: String) -> AccountType {
        var type = AccountType.asset
        for accountType in AccountType.allValues() where name.starts(with: accountType.rawValue) {
            type = accountType
        }
        return type
    }

    /// Checks if a given name for an account is valid
    ///
    /// This includes that the name start with one of the base groups and is correctly formattet with seperators
    ///
    /// - Parameter name: String to check
    /// - Returns: if the name is valid
    public static func isNameValid(_ name: String) -> Bool {
        struct Cache { // https://stackoverflow.com/a/25354915/3386893 // swiftlint:disable:this convenience_type
            static var validNames = Set<String>()
        }
        if Cache.validNames.contains(name) {
            return true
        }
        guard !name.isEmpty else {
            return false
        }
        for type in AccountType.allValues() {
            if name.starts(with: type.rawValue + String(Account.nameSeperator)) // has to start with one base account followed by a seperator
                && name.last != Account.nameSeperator //  is not allowed to end in a seperator
                && !name.contains("\(Account.nameSeperator)\(Account.nameSeperator)") // no account item is allowed to be empty
                && !name.contains(" ") { // account names are not allowed to contain spaces
                Cache.validNames.insert(name)
                return true
            }
        }
        return false
    }

}

extension AccountNameError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .invaildName(error):
            return "Invalid Account name: \(error)"
        }
    }
}

extension AccountName: Equatable {

    /// Compare the full name of the two Account names.
    ///
    /// - Returns: if the account names are equal
    public static func == (lhs: AccountName, rhs: AccountName) -> Bool {
        rhs.fullName == lhs.fullName
    }

}

extension AccountName: CustomStringConvertible {

    public var description: String { fullName }
}

extension AccountName: Hashable {

    public func hash(into hasher: inout Hasher) {
        hasher.combine(fullName)
    }

}
