//
//  LedgerReader.swift
//  SwiftBeanCountSheetSync
//
//  Created by Steffen Koette on 2020-12-13.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel
import SwiftBeanCountParser

enum LedgerReader {

    static func readLedger(from ledgerURL: URL) -> Result<Ledger, Error> {
        do {
            let ledger = try Parser.parse(contentOf: ledgerURL)
            return .success(ledger)
        } catch {
            return .failure(error)
        }
    }

    static func readLedgerSettingsAndTransactions(ledger: Ledger) -> Result<([Transaction], LedgerSettings), Error> { // swiftlint:disable:this function_body_length
        let settings = ledger.custom.filter { $0.name == LedgerSettingsConstants.settingsKey }

        guard let commoditySymbol = settings.first(where: { $0.values.count == 2 && $0.values[0] == LedgerSettingsConstants.commoditySymbolKey })?.values[1] else {
            return .failure(SyncError.missingSetting(LedgerSettingsConstants.commoditySymbolKey))
        }
        guard let tagValue = settings.first(where: { $0.values.count == 2 && $0.values[0] == LedgerSettingsConstants.tagKey })?.values[1] else {
            return .failure(SyncError.missingSetting(LedgerSettingsConstants.commoditySymbolKey))
        }
        guard let accountNameValue = settings.first(where: { $0.values.count == 2 && $0.values[0] == LedgerSettingsConstants.accountKey })?.values[1] else {
            return .failure(SyncError.missingSetting(LedgerSettingsConstants.accountKey))
        }
        guard let accountName = try? AccountName(accountNameValue) else {
            return .failure(SyncError.invalidSetting(LedgerSettingsConstants.accountKey, accountNameValue))
        }
        guard let name = settings.first(where: { $0.values.count == 2 && $0.values[0] == LedgerSettingsConstants.nameKey })?.values[1] else {
            return .failure(SyncError.missingSetting(LedgerSettingsConstants.commoditySymbolKey))
        }
        guard let dateToleranceValue = settings.first(where: { $0.values.count == 2 && $0.values[0] == LedgerSettingsConstants.dateToleranceKey })?.values[1] else {
            return .failure(SyncError.missingSetting(LedgerSettingsConstants.dateToleranceKey))
        }
        guard let dateToleranceDays = Int(dateToleranceValue) else {
            return .failure(SyncError.invalidSetting(LedgerSettingsConstants.dateToleranceKey, dateToleranceValue))
        }

        let accounts = ledger.accounts.filter { $0.metaData[LedgerSettingsConstants.categoryKey] != nil }

        return .success((ledger.transactions.filter { $0.metaData.tags.contains(Tag(name: tagValue)) }, LedgerSettings(
            commoditySymbol: commoditySymbol,
            tag: Tag(name: tagValue),
            name: name,
            accountName: accountName,
            dateTolerance: TimeInterval(dateToleranceDays * 60 * 60 * 24),
            categoryAccountNames: Dictionary(accounts.map { ($0.metaData[LedgerSettingsConstants.categoryKey]!, $0.name) }) { first, _ in first },
            accountNameCategories: Dictionary(accounts.map { ($0.name.fullName, $0.metaData[LedgerSettingsConstants.categoryKey]! ) }) { first, _ in first }))
        )

    }

}
