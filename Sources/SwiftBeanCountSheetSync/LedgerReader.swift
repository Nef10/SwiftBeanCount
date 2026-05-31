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
        let accounts = ledger.accounts.filter { $0.metaData[LedgerSettingsConstants.categoryKey] != nil }

        guard let commoditySymbol = latestSettingValue(for: LedgerSettingsConstants.commoditySymbolKey, in: settings) else {
            return .failure(SyncError.missingSetting(LedgerSettingsConstants.commoditySymbolKey))
        }
        guard let tagValue = latestSettingValue(for: LedgerSettingsConstants.tagKey, in: settings) else {
            return .failure(SyncError.missingSetting(LedgerSettingsConstants.commoditySymbolKey))
        }
        guard let accountNameValue = latestSettingValue(for: LedgerSettingsConstants.accountKey, in: settings) else {
            return .failure(SyncError.missingSetting(LedgerSettingsConstants.accountKey))
        }
        guard let accountName = try? AccountName(accountNameValue) else {
            return .failure(SyncError.invalidSetting(LedgerSettingsConstants.accountKey, accountNameValue))
        }
        guard let name = latestSettingValue(for: LedgerSettingsConstants.nameKey, in: settings) else {
            return .failure(SyncError.missingSetting(LedgerSettingsConstants.commoditySymbolKey))
        }
        guard let dateToleranceValue = latestSettingValue(for: LedgerSettingsConstants.dateToleranceKey, in: settings) else {
            return .failure(SyncError.missingSetting(LedgerSettingsConstants.dateToleranceKey))
        }
        guard let dateToleranceDays = Int(dateToleranceValue) else {
            return .failure(SyncError.invalidSetting(LedgerSettingsConstants.dateToleranceKey, dateToleranceValue))
        }

        let negateRunningTotal = latestSettingValue(for: LedgerSettingsConstants.negateRunningTotalKey, in: settings) == "true"

        return .success((ledger.transactions.filter { transaction in
            guard let applicableTagValue = latestSettingValue(for: LedgerSettingsConstants.tagKey, in: settings, on: transaction.metaData.date) else {
                return false
            }
            return transaction.metaData.tags.contains(Tag(name: applicableTagValue))
        }, LedgerSettings(
            commoditySymbol: commoditySymbol,
            tag: Tag(name: tagValue),
            name: name,
            accountName: accountName,
            dateTolerance: TimeInterval(dateToleranceDays * 60 * 60 * 24),
            categoryAccountNames: Dictionary(accounts.map { ($0.metaData[LedgerSettingsConstants.categoryKey]!, $0.name) }) { first, _ in first },
            accountNameCategories: Dictionary(accounts.map { ($0.name.fullName, $0.metaData[LedgerSettingsConstants.categoryKey]! ) }) { first, _ in first },
            negateRunningTotal: negateRunningTotal))
        )

    }

    private static func latestSettingValue(for key: String, in settings: [Custom], on date: Date? = nil) -> String? {
        settings
            .filter { setting in
                setting.values.count == 2
                    && setting.values[0] == key
                    && date.map { setting.date <= $0 } != false
            }
            .min(by: { $0.date > $1.date })?
            .values[1]
    }

}
