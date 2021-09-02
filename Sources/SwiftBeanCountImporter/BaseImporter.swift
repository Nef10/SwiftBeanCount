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

    class var importerType: String { "" } // Override

    var ledger: Ledger?
    private(set) var accountName: AccountName?
    var configuredAccountName: AccountName {
        guard let accountName = accountName else {
            fatalError("No account configured - You must call useAccount(name:) before attempting to import")
        }
        return accountName
    }
    var importName: String { "" } // Override

    var commoditySymbol: String {
        ledger?.accounts.first { $0.name == accountName }?.commoditySymbol ?? Settings.fallbackCommodity
    }

    init(ledger: Ledger?) {
        self.ledger = ledger
    }

    func possibleAccountNames() -> [AccountName] {
        if let accountName = accountName {
            return [accountName]
        }
        return accountsFromLedger()
    }

    func useAccount(name: AccountName) {
        self.accountName = name
    }

    func accountsFromLedger() -> [AccountName] {
        // Override if neccessary, e.g. to do more filtering based on more meta data, e.g. account numbers
        ledger?.accounts.filter { $0.metaData[Settings.importerTypeKey] == Self.importerType }.map { $0.name } ?? []
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

    func getPossibleDuplicateFor(_ transaction: Transaction) -> Transaction? {
        guard let ledger = ledger else {
            return nil
        }
        return ledger.transactions.first {
            $0.postings.contains { $0.accountName == transaction.postings.first?.accountName && $0.amount == transaction.postings.first?.amount }
                && $0.metaData.date + Settings.dateTolerance >= transaction.metaData.date && $0.metaData.date - Settings.dateTolerance <= transaction.metaData.date
        }
    }
}
