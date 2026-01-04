import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountSheetSync
import Testing

@Suite
struct LedgerReaderTests {

    @Test
    func readLedgerSettingsAndTransactionsWithValidLedger() throws {
        let ledger = Ledger()
        let date = Date()

        // Add custom settings
        ledger.custom.append(Custom(date: date, name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.commoditySymbolKey, "USD"]))
        ledger.custom.append(Custom(date: date, name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.tagKey, "shared"]))
        ledger.custom.append(Custom(date: date, name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.accountKey, "Assets:SharedAccount"]))
        ledger.custom.append(Custom(date: date, name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.nameKey, "Alice"]))
        ledger.custom.append(Custom(date: date, name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.dateToleranceKey, "1"]))

        // Add accounts with categories
        let groceryAccount = try AccountName("Expenses:Groceries")
        try ledger.add(Account(name: groceryAccount, metaData: [LedgerSettingsConstants.categoryKey: "Food"]))

        // Add transaction with tag
        let transaction = Transaction(
            metaData: TransactionMetaData(date: Date(), payee: "Store", narration: "Test", tags: [Tag(name: "shared")]),
            postings: []
        )
        ledger.add(transaction)

        let result = LedgerReader.readLedgerSettingsAndTransactions(ledger: ledger)

        switch result {
        case .success(let (transactions, settings)):
            #expect(transactions.count == 1)
            #expect(settings.commoditySymbol == "USD")
            #expect(settings.tag == Tag(name: "shared"))
            #expect(settings.name == "Alice")
            #expect(settings.accountName.fullName == "Assets:SharedAccount")
            #expect(settings.dateTolerance == 86_400)
            #expect(settings.categoryAccountNames["Food"] == groceryAccount)
            #expect(settings.accountNameCategories[groceryAccount.fullName] == "Food")
        case .failure:
            Issue.record("Expected success but got failure")
        }
    }

    @Test
    func readLedgerSettingsWithMissingCommoditySymbol() {
        let ledger = Ledger()
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.tagKey, "shared"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.accountKey, "Assets:SharedAccount"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.nameKey, "Alice"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.dateToleranceKey, "1"]))

        let result = LedgerReader.readLedgerSettingsAndTransactions(ledger: ledger)

        switch result {
        case .success:
            Issue.record("Expected failure but got success")
        case .failure(let error):
            if let syncError = error as? SyncError, case .missingSetting = syncError {
                // Expected
            } else {
                Issue.record("Expected SyncError.missingSetting")
            }
        }
    }

    @Test
    func readLedgerSettingsWithMissingTag() {
        let ledger = Ledger()
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.commoditySymbolKey, "USD"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.accountKey, "Assets:SharedAccount"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.nameKey, "Alice"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.dateToleranceKey, "1"]))

        let result = LedgerReader.readLedgerSettingsAndTransactions(ledger: ledger)

        switch result {
        case .success:
            Issue.record("Expected failure but got success")
        case .failure(let error):
            if let syncError = error as? SyncError, case .missingSetting = syncError {
                // Expected
            } else {
                Issue.record("Expected SyncError.missingSetting")
            }
        }
    }

    @Test
    func readLedgerSettingsWithMissingAccount() {
        let ledger = Ledger()
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.commoditySymbolKey, "USD"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.tagKey, "shared"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.nameKey, "Alice"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.dateToleranceKey, "1"]))

        let result = LedgerReader.readLedgerSettingsAndTransactions(ledger: ledger)

        switch result {
        case .success:
            Issue.record("Expected failure but got success")
        case .failure(let error):
            if let syncError = error as? SyncError, case .missingSetting = syncError {
                // Expected
            } else {
                Issue.record("Expected SyncError.missingSetting")
            }
        }
    }

    @Test
    func readLedgerSettingsWithInvalidAccount() {
        let ledger = Ledger()
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.commoditySymbolKey, "USD"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.tagKey, "shared"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.accountKey, "InvalidAccountName"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.nameKey, "Alice"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.dateToleranceKey, "1"]))

        let result = LedgerReader.readLedgerSettingsAndTransactions(ledger: ledger)

        switch result {
        case .success:
            Issue.record("Expected failure but got success")
        case .failure(let error):
            if let syncError = error as? SyncError, case .invalidSetting = syncError {
                // Expected
            } else {
                Issue.record("Expected SyncError.invalidSetting")
            }
        }
    }

    @Test
    func readLedgerSettingsWithMissingName() {
        let ledger = Ledger()
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.commoditySymbolKey, "USD"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.tagKey, "shared"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.accountKey, "Assets:SharedAccount"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.dateToleranceKey, "1"]))

        let result = LedgerReader.readLedgerSettingsAndTransactions(ledger: ledger)

        switch result {
        case .success:
            Issue.record("Expected failure but got success")
        case .failure(let error):
            if let syncError = error as? SyncError, case .missingSetting = syncError {
                // Expected
            } else {
                Issue.record("Expected SyncError.missingSetting")
            }
        }
    }

    @Test
    func readLedgerSettingsWithMissingDateTolerance() {
        let ledger = Ledger()
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.commoditySymbolKey, "USD"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.tagKey, "shared"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.accountKey, "Assets:SharedAccount"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.nameKey, "Alice"]))

        let result = LedgerReader.readLedgerSettingsAndTransactions(ledger: ledger)

        switch result {
        case .success:
            Issue.record("Expected failure but got success")
        case .failure(let error):
            if let syncError = error as? SyncError, case .missingSetting = syncError {
                // Expected
            } else {
                Issue.record("Expected SyncError.missingSetting")
            }
        }
    }

    @Test
    func readLedgerSettingsWithInvalidDateTolerance() {
        let ledger = Ledger()
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.commoditySymbolKey, "USD"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.tagKey, "shared"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.accountKey, "Assets:SharedAccount"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.nameKey, "Alice"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.dateToleranceKey, "invalid"]))

        let result = LedgerReader.readLedgerSettingsAndTransactions(ledger: ledger)

        switch result {
        case .success:
            Issue.record("Expected failure but got success")
        case .failure(let error):
            if let syncError = error as? SyncError, case .invalidSetting = syncError {
                // Expected
            } else {
                Issue.record("Expected SyncError.invalidSetting")
            }
        }
    }

    @Test
    func readLedgerFiltersByTag() {
        let ledger = Ledger()

        // Add custom settings
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.commoditySymbolKey, "USD"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.tagKey, "shared"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.accountKey, "Assets:SharedAccount"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.nameKey, "Alice"]))
        ledger.custom.append(Custom(date: Date(), name: LedgerSettingsConstants.settingsKey, values: [LedgerSettingsConstants.dateToleranceKey, "1"]))

        // Add transactions
        let sharedTransaction = Transaction(
            metaData: TransactionMetaData(date: Date(), payee: "Store1", narration: "Shared", tags: [Tag(name: "shared")]),
            postings: []
        )
        let otherTransaction = Transaction(
            metaData: TransactionMetaData(date: Date(), payee: "Store2", narration: "Not shared", tags: [Tag(name: "other")]),
            postings: []
        )
        ledger.add(sharedTransaction)
        ledger.add(otherTransaction)

        let result = LedgerReader.readLedgerSettingsAndTransactions(ledger: ledger)

        switch result {
        case .success(let (transactions, _)):
            #expect(transactions.count == 1)
            #expect(transactions[0].metaData.payee == "Store1")
        case .failure:
            Issue.record("Expected success but got failure")
        }
    }
}
