//
//  LedgerSettings.swift
//  SwiftBeanCountSheetSync
//
//  Created by Steffen Koette on 2020-12-13.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

enum LedgerSettingsConstants {

    static let settingsKey = "sheet-sync-settings"
    static let categoryKey = "sheet-sync-category"
    static let commoditySymbolKey = "commoditySymbol"
    static let accountKey = "account"
    static let tagKey = "tag"
    static let nameKey = "name"
    static let dateToleranceKey = "dateTolerance"

}

public struct LedgerSettings {
    static let fallbackAccountName = try! AccountName("Expenses:TODO") // swiftlint:disable:this force_try
    static let ownAccountName = try! AccountName("Assets:TODO") // swiftlint:disable:this force_try

    let commoditySymbol: String
    let tag: Tag
    let name: String
    let accountName: AccountName
    let dateTolerance: TimeInterval
    let categoryAccountNames: [String: AccountName]
    let accountNameCategories: [String: String]
}
