//
//  GoogleSheetDownloadImporter.swift
//
//
//  Created by Steffen Kötte on 2023-10-07.
//

#if os(macOS)

import AuthenticationServices
import Foundation
import GoogleAuthentication
import SwiftBeanCountModel
import SwiftBeanCountSheetSync

class AuthenticationPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}

class GoogleSheetDownloadImporter: BaseImporter, DownloadImporter {

    override class var importerName: String { "Google Sheet Download" }
    override class var importerType: String { "google-sheet" }
    override class var helpText: String {
        """
        Downloads transactions from a Google Sheet.

        The download relies on meta data in your Beancount file for configuration.

        - commoditySymbol: The synchronization only works with one commodity which needs to be specified here
        - account: Account which is used to keep track of the balance between the people
        - tag: Tag which is appended to all transactions which are or should be synchronized
        - name: Your name - this will be used to identify the columns of the sheet
        - dateTolerance: Tolerance in days which will be used when checking if a transactions already exists
        - negateRunningTotal: Set to "true" to negate an optional Running Total column before it is used for a balance assertion

        These options are specified via customs like this:
        YYYY-MM-DD custom "sheet-sync-settings" "commoditySymbol" "CAD"

        When the same setting appears multiple times, the newest dated one is used. The tag is resolved per transaction using the most recent value on or before the transaction date.

        You can attach sheet-sync-category metadata to accounts to map categories from the sheet to accounts and vice-versa in a 1-1 relationship. This is optional, in case no mapping could be found a fallback account / an empty category will be used.

        Example:

        2020-12-26 open Expenses:Communication:Internet
          sheet-sync-category: "Internet"

        The Google Sheet tab must be named Expenses. Two column formats are supported and detected automatically.

        Total amount format:
        - Date: in yyyy-MM-dd format
        - Paid to or Payee: e.g. store name, can be an empty string
        - Amount: Total amount paid
        - Category: See account configuration above
        - Part Name1 and Part Name2: Name1 and Name2 should be the name of the people. One of them must be the same as configured as name in the ledger. Each column must contain a number which represents the amount this party is paying for the purchase
        - Who paid or Payor: One of the two names
        - Comment or Description: The column is required, but it can be an empty string

        Share amount format (detected when Share Other Person is present):
        - Date: in yyyy-MM-dd format
        - Paid to or Payee: e.g. store name, can be an empty string
        - Comment or Description: Can be an empty string
        - Category: See account configuration above
        - Who paid or Payor: Name of the person who paid
        - Share Other Person: Share owed by the person who did not pay

        In both formats, amount columns support . as decimal point, optional , as thousands separator, optional currency symbols / prefixes, and negative values with either a leading minus or accounting brackets.

        Optional columns:
        - Running Total: Uses the last row as a balance assertion. negateRunningTotal can be used to flip the sign before importing.

        In the share amount format there is no total amount column. If the configured name is the person who paid, new transactions assume an equal split and derive the total as 2 × Share Other Person. When a matching ledger transaction already exists, its actual amounts are preserved.
        """
    }

    override var importName: String { "Google Sheet Download" }

    private let existingLedger: Ledger
    private let authentication = Authentication(appID: "1039239506189-ia9evaeo7ggpp4p9f8c94dqvappke54h",
                                                consumerSecret: "08duXE23dRYMpBt1BXedX2aw",
                                                scope: "https://www.googleapis.com/auth/spreadsheets.readonly",
                                                keychainService: "de.steffenkoette.SwiftBeanCountSheetSync")

    /// Results
    private var transactions = [ImportedTransaction]()
    private var balance: Balance?

    override required init(ledger: Ledger?) {
        existingLedger = ledger ?? Ledger()
        super.init(ledger: ledger)
    }

    func requestSheetURL() -> String {
        var sheet = ""
        let group = DispatchGroup()
        group.enter()
        delegate?.requestInput(name: "URL", type: .text(Settings.recentGoogleSheetURLs)) {
            sheet = $0
            Settings.addRecentGoogleSheetURL($0)
            group.leave()
            return true
        }
        group.wait()
        return sheet
    }

    override func load() {
        let sheet = requestSheetURL()
        let downloader = Downloader(sheetURL: sheet, ledger: existingLedger)
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.main.async { [self] in
            authentication.authenticate(authenticationPresentationContextProvider: AuthenticationPresentationContextProvider()) { [self] in
                switch $0 {
                case .success:
                    downloader.start(authentication: authentication) { [self] in
                        process($0)
                        group.leave()
                    }
                case .failure(let error):
                    delegate?.error(error) {
                        group.leave()
                    }
                }
            }
        }
        group.wait()
    }

    private func process(_ result: Result<SyncResult, Error>) {
        if case let .success(result) = result {
            transactions = result.transactions.map { ImportedTransaction($0) }
            balance = result.balance
        }
        guard let delegate else {
            return
        }
        let group = DispatchGroup()
        switch result {
        case .success(let result):
            for error in result.parserErrors {
                group.enter()
                delegate.error(error) {
                    group.leave()
                }
                group.wait()
            }
        case .failure(let error):
            group.enter()
            delegate.error(error) {
                group.leave()
            }
            group.wait()
        }
    }

    override func nextTransaction() -> ImportedTransaction? {
        guard !transactions.isEmpty else {
            return nil
        }
        return transactions.removeFirst()
    }

    override func balancesToImport() -> [Balance] {
        guard let balance else {
            return []
        }
        let exists = existingLedger.accounts.first { $0.name == balance.accountName }?
            .balances.contains { $0.date == balance.date && $0.amount == balance.amount } ?? false
        return exists ? [] : [balance]
    }

}

#endif
