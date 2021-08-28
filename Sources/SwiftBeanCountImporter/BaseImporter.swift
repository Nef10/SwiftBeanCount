//
//  BaseImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2020-05-14.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

class BaseImporter: Importer {

    private static let regexe: [NSRegularExpression] = {  // swiftlint:disable force_try
        [
            try! NSRegularExpression(pattern: "(C-)?IDP PURCHASE( )?-( )?[0-9]{4}", options: []),
            try! NSRegularExpression(pattern: "VISA DEBIT (PUR|REF)-[0-9]{4}", options: []),
            try! NSRegularExpression(pattern: "WWWINTERAC PUR [0-9]{4}", options: []),
            try! NSRegularExpression(pattern: "INTERAC E-TRF- [0-9]{4}", options: []),
            try! NSRegularExpression(pattern: "[0-9]* ~ Internet Withdrawal", options: []),
            try! NSRegularExpression(pattern: "(-)? SAP(?! CANADA)", options: []),
            try! NSRegularExpression(pattern: "-( )?(MAY|JUNE)( )?201(4|6)", options: []),
            try! NSRegularExpression(pattern: "  BC  CA", options: []),
            try! NSRegularExpression(pattern: "#( )?[0-9]{1,5}", options: []),
        ]
    }() // swiftlint:enable force_try

    static let accountsSetting = ImporterSetting(identifier: "accounts", name: "Account(s)")

    class var settingsName: String { "" }
    class var settings: [ImporterSetting] { [accountsSetting] }

    private(set) var accountName: AccountName?
    var ledger: Ledger?

    var commoditySymbol: String {
        ledger?.accounts.first { $0.name == accountName }?.commoditySymbol ?? Settings.fallbackCommodity
    }

    var importName: String {
        "" // Override
    }

    init(ledger: Ledger?) {
        self.ledger = ledger
    }

    func possibleAccountNames(for ledger: Ledger?) -> [AccountName] {
        if let accountName = accountName {
            return [accountName]
        }
        return accountsFromSettings()
    }

    func useAccount(name: AccountName) {
        self.accountName = name
    }

    func accountsFromSettings() -> [AccountName] {
        (Self.get(setting: Self.accountsSetting) ?? "").components(separatedBy: CharacterSet(charactersIn: " ,")).map { try? AccountName($0) }.compactMap { $0 }
    }

    func load() {
        // Override if neccessary
    }

    func nextTransaction() -> ImportedTransaction? {
        nil // Override
    }

    func balancesToImport() -> [Balance] {
        [] // Override if neccessary
    }

    func pricesToImport() -> [Price] {
        [] // Override if neccessary
    }

    func sanitize(description: String) -> String {
        var result = description
        for regex in Self.regexe {
            result = regex.stringByReplacingMatches(in: result,
                                                    options: .withoutAnchoringBounds,
                                                    range: NSRange(result.startIndex..., in: result),
                                                    withTemplate: "")
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    func savedDescriptionAndPayeeFor(description: String) -> (String?, String?) {
        (Settings.allDescriptionMappings[description], Settings.allPayeeMappings[description])
    }

    func savedAccountNameFor(payee: String) -> AccountName? {
        if let accountNameString = Settings.allAccountMappings[payee], let accountName = try? AccountName(accountNameString) {
            return accountName
        }
        return nil
    }
}
