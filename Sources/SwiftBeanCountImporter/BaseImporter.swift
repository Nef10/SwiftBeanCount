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

    static let accountsSetting = ImporterSetting(identifier: "accounts", name: "Account(s)")

    class var settingsName: String { "" }
    class var settings: [ImporterSetting] { [accountsSetting] }

    private let fallbackCommodity = "CAD"

    private(set) var accountName: AccountName?
    var ledger: Ledger?

    var commoditySymbol: String {
        ledger?.accounts.first { $0.name == accountName }?.commoditySymbol ?? fallbackCommodity
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

}
