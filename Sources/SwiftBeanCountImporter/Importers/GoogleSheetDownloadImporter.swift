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
    override class var helpText: String { //  swiftlint:disable line_length
        """
        Downloads transactions from a Google Sheet.

        The download relies on meta data in your Beancount file to find for configuration.

        - commoditySymbol: The synchronization only works with one commodity which needs to be specified here
        - account: Account which is used to keep track of the balance between the people
        - tag: Tag which is appended to all transactions which are or should be synchronized
        - name: Your name - this will be used to identify the colunms of the sheet
        - dateTolerance: Tolerance in days which will be used when checking if a transactions already exists

        These options are specified globally via customs like this (the date does not matter and will be ignored):
        YYYY-MM-DD custom "sheet-sync-settings" "commoditySymbol" "CAD"

        You can attatch sheet-sync-category metadata to accounts to map categories from the sheet to accounts and vice-versa in a 1-1 relationship. This is optional, in case no mapping could be found a fallback account / an empty category will be used.

        Example:

        2020-12-26 open Expenses:Communication:Internet
          sheet-sync-category: "Internet"

        The Google sheet need to be in a specifc format in order to be read. The tab must be named Expenses.

        The following columns are required to be within colunms A-I, other columns are ignored:

        - Date: in yyyy-MM-dd format
        - Paid to: e.g. Store name, can be an empty string
        - Amount: Use . as decimal point. , to separate thousand is ok, accouting style with brackets for negative values is supported
        - Category: See account configuration above
        - Part Name1 and Part Name2: Name1 and Name2 should be the name of the people (e.g. replace them). One of them must be the same as configured as name in the ledger (see above). Each column must contain a number which represents the amount this party is paying for the purchase. Same formatting rules as for amount apply.
        - Who paid: One of the two names
        - Comment: While the column is required, it can be an empty string
        """
    } //  swiftlint:enable line_length

    override var importName: String { "Google Sheet Download" }

    private let existingLedger: Ledger
    private let authentication = Authentication(appID: "1039239506189-ia9evaeo7ggpp4p9f8c94dqvappke54h",
                                                consumerSecret: "08duXE23dRYMpBt1BXedX2aw",
                                                scope: "https://www.googleapis.com/auth/spreadsheets.readonly",
                                                keychainService: "de.steffenkoette.SwiftBeanCountSheetSync")

    /// Results
    private var transactions = [ImportedTransaction]()

    override required init(ledger: Ledger?) {
        existingLedger = ledger ?? Ledger()
        super.init(ledger: ledger)
    }

    override func load() {
        var sheet = ""
        let group = DispatchGroup()
        group.enter()
        delegate?.requestInput(name: "URL", type: .text([])) {
            sheet = $0
            group.leave()
            return true
        }
        group.wait()
        let downloader = Downloader(sheetURL: sheet, ledger: existingLedger)
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

}

#endif
