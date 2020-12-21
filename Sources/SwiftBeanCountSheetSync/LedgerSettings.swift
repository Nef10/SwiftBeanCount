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

/// Settings for SwiftBeanCountSheetSync which were read from the ledger file
public struct LedgerSettings {
    static let fallbackAccountName = try! AccountName("Expenses:TODO") // swiftlint:disable:this force_try
    static let ownAccountName = try! AccountName("Assets:TODO") // swiftlint:disable:this force_try

    /// Commodity symbol for all transactions - The syncronization only supports one commodity
    public let commoditySymbol: String
    /// Tag which is appended to all transactions from the sheet
    public let tag: Tag
    /// Name of the person of the ledger - used to identify the colunms of the sheet
    public let name: String
    /// Account which is used to keep track of the balance between the people
    public let accountName: AccountName
    /// tolerance used to detect already existing transactions
    public let dateTolerance: TimeInterval
    /// Mapping from sheet categories to the corresponding account names in the ledger
    public let categoryAccountNames: [String: AccountName]
    /// Mapping from account names in the ledger to the corresponding categories in the sheet
    public let accountNameCategories: [String: String]
}
