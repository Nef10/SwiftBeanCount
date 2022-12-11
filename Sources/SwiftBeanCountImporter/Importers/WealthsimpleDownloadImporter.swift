//
//  WealthsimpleDownloadImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2021-09-10.
//  Copyright © 2021 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel
import SwiftBeanCountWealthsimpleMapper
import Wealthsimple

protocol WealthsimpleDownloaderProvider {
    init(authenticationCallback: @escaping WealthsimpleDownloader.AuthenticationCallback, credentialStorage: CredentialStorage)
    func authenticate(completion: @escaping (Error?) -> Void)
    func getAccounts(completion: @escaping (Result<[Wealthsimple.Account], Wealthsimple.AccountError>) -> Void)
    func getPositions(in account: Wealthsimple.Account, date: Date?, completion: @escaping (Result<[Wealthsimple.Position], Wealthsimple.PositionError>) -> Void)
    func getTransactions(
        in account: Wealthsimple.Account,
        startDate: Date?,
        completion: @escaping (Result<[Wealthsimple.Transaction], Wealthsimple.TransactionError>) -> Void
    )
}

class WealthsimpleDownloadImporter: BaseImporter, DownloadImporter {

    override class var importerName: String { "Wealthsimple Download" }
    override class var importerType: String { "wealthsimple" }
    override class var helpText: String { //  swiftlint:disable line_length
        """
        Downloads transactions, prices and balances from Wealthsimple.

        The importer relies on meta data in your Beancount file to find accounts and commodities. Please add these to your Beancount file:

        Commodities:

        If the commodity in your ledger differs from the symbol used by Wealthsimple, simply add `wealthsimple-symbol` as meta data, for example:

        2011-10-18 commodity ACWVETF
          wealthsimple-symbol: "ACWV"

        Accounts:

        For Wealthsimple accounts themselves, you need to add this metadata: `importer-type: "wealthsimple"` and `number: "XXX"`. If the account can hold more than one commodity (all accounts except chequing and saving), it needs to follow this structure: `Assets:X:Y:Z:CashAccountName`, `Assets:X:Y:Z:CommodityName`, `Assets:X:Y:Z:OtherCommodityName`. The name of the cash account does not matter, but all other account must end with the commodity symbol (see above). Add the `importer-type` and `number` only to the cash account.

        For accounts used in transactions to and from your Wealthsimple accounts you need to provide meta data as well. These is in the form of `wealthsimple-key: "accountNumber1 accountNumber2"`. The account number is the same as above, and you can specify one or multiple per key. As keys use these values:
        * For dividend income accounts `wealthsimple-dividend-COMMODITYSYMBOL`, e.g. `wealthsimple-dividend-XGRO`
        * For the assset account you are using to contribute to registered accounts from, use `wealthsimple-contribution`
        * For the assset account you are using to deposit to non-registered accounts from, use `wealthsimple-deposit`
        * Use `wealthsimple-fee` on an expense account to track the wealthsimple fees
        * Use `wealthsimple-non-resident-withholding-tax` on an expense account for non resident withholding tax
        * In case some transaction does not balance within your ledger, an expense account with `wealthsimple-rounding` will get the difference
        * If you want to track contribution room, use `wealthsimple-contribution-room` on an asset and expense account (optional, if not set it will not create postings for the contribution room)
        * Other values for transaction types you might incur are:
            * `wealthsimple-reimbursement`
            * `wealthsimple-interest`
            * `wealthsimple-withdrawal`
            * `wealthsimple-payment-transfer-in` and `wealthsimple-payment-transfer-out`
            * `wealthsimple-transfer-in` and `wealthsimple-transfer-out`
            * `wealthsimple-referral-bonus`
            * `wealthsimple-giveaway-bonus`
            * `wealthsimple-refund`
            * `wealthsimple-payment-spend` (optional, will use fallback account if not provided)

        Configuration:

        By default the last two month of data are loaded. To control this, add a custom options like this to your file: YYYY-MM-DD custom "wealthsimple-importer" "pastDaysToLoad" "5".

        Full Example:

        2020-07-31 open Assets:Checking:Wealthsimple CAD
          importer-type: "wealthsimple"
          number: "A001"

        2020-07-31 open Assets:Investment:Wealthsimple:TFSA:Parking CAD
          importer-type: "wealthsimple"
          number: "B002"
        2020-07-31 open Assets:Investment:Wealthsimple:TFSA:ACWV ACWV
        2020-07-31 open Assets:Investment:Wealthsimple:TFSA:XGRO XGRO

        2020-07-31 open Income:Capital:Dividend:ACWV USD
          wealthsimple-dividend-ACWV: "A001 B002"

        2020-07-31 open Assets:Checking:Bank CAD
          wealthsimple-contribution: "A001 B002"

        2020-07-31 open Expenses:FinancialInstitutions:Investment:NonRegistered:Fees
          wealthsimple-fee: "A001"

        2020-07-31 open Expenses:FinancialInstitutions:Investment:Registered:Fees
          wealthsimple-fee: "B002"

        2020-07-31 open Assets:TFSAContributionRoom TFSA.ROOM
          wealthsimple-contribution-room: "B002"

        2020-07-31 open Expenses:TFSAContributionRoom TFSA.ROOM
          wealthsimple-contribution-room: "B002"
        """ //  swiftlint:enable line_length
    }

    override var importName: String { "Wealthsimple Download" }
    var downloaderClass: WealthsimpleDownloaderProvider.Type = WealthsimpleDownloader.self

    private let existingLedger: Ledger
    private let sixtyTwoDays = -60 * 60 * 24 * 62.0
    private let customsKey = "wealthsimple-importer"
    private let daysSettings = "pastDaysToLoad"

    private var downloader: WealthsimpleDownloaderProvider!
    private var mapper: WealthsimpleLedgerMapper

    private var downloadedAccounts = [Wealthsimple.Account]()

    /// Results
    private var transactions = [ImportedTransaction]()
    private var balances = [Balance]()
    private var prices = [Price]()

    override required init(ledger: Ledger?) {
        existingLedger = ledger ?? Ledger()
        mapper = WealthsimpleLedgerMapper(ledger: existingLedger)
        super.init(ledger: ledger)
    }

    override func load() {
        downloader = downloaderClass.init(authenticationCallback: authenticationCallback, credentialStorage: self)

        let group = DispatchGroup()
        group.enter()

        download {
            group.leave()
        }

        group.wait()
    }

    private func dateToLoadFrom() -> Date {
        guard let days = Int(existingLedger.custom.filter({ $0.name == customsKey && $0.values.first == daysSettings }).max(by: { $0.date < $1.date })?.values[1] ?? "") else {
            return Date(timeIntervalSinceNow: self.sixtyTwoDays )
        }
        return Date(timeIntervalSinceNow: -60 * 60 * 24 * Double(days) )
    }

    private func download(_ completion: @escaping () -> Void) {
        downloader.authenticate { error in
            if let error = error {
                self.delegate?.error(error)
                completion()
            } else {
                self.downloadAccounts(completion)
            }
        }
    }

    private func downloadAccounts(_ completion: @escaping () -> Void) {
        downloader.getAccounts { result in
            switch result {
            case let .failure(error):
                self.delegate?.error(error)
                completion()
            case let .success(accounts):
                self.downloadedAccounts = accounts
                self.mapper.accounts = accounts
                DispatchQueue.global(qos: .userInitiated).async {
                    self.downloadPositions(completion)
                }
            }
        }
    }

    private func downloadPositions(_ completion: @escaping () -> Void) { // swiftlint:disable:this function_body_length
        let group = DispatchGroup()
        var errorOccurred = false

        downloadedAccounts.forEach { account in
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                self.downloader.getPositions(in: account, date: nil) { result in
                    switch result {
                    case let .failure(error):
                        self.delegate?.error(error)
                        errorOccurred = true
                        group.leave()
                    case let .success(positions):
                        do {
                            let (accountPrices, accountBalances) = try self.mapper.mapPositionsToPriceAndBalance(positions)
                            self.prices.append(contentsOf: accountPrices)
                            self.balances.append(contentsOf: accountBalances)
                            group.leave()
                        } catch {
                            self.delegate?.error(error)
                            errorOccurred = true
                            group.leave()
                        }
                    }
                }
            }
        }

        group.wait()
        if !errorOccurred {
            self.downloadTransactions(completion)
        } else {
            completion()
        }
    }

    private func downloadTransactions(_ completion: @escaping () -> Void) { // swiftlint:disable:this function_body_length
        let group = DispatchGroup()
        var downloadedTransactions = [SwiftBeanCountModel.Transaction]()
        var errorOccurred = false

        downloadedAccounts.forEach { account in
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                self.downloader.getTransactions(in: account, startDate: self.dateToLoadFrom()) { result in
                    switch result {
                    case let .failure(error):
                        self.delegate?.error(error)
                        errorOccurred = true
                        group.leave()
                    case let .success(transactions):
                        do {
                            let (accountPrices, accountTransactions) = try self.mapper.mapTransactionsToPriceAndTransactions(transactions)
                            self.prices.append(contentsOf: accountPrices)
                            downloadedTransactions.append(contentsOf: accountTransactions)
                            group.leave()
                        } catch {
                            self.delegate?.error(error)
                            errorOccurred = true
                            group.leave()
                        }
                    }
                }
            }
        }

        group.wait()
        if !errorOccurred {
            self.mapTransactions(downloadedTransactions, completion)
        } else {
            completion()
        }
    }

    private func mapTransactions(_ transactions: [SwiftBeanCountModel.Transaction], _ completion: @escaping () -> Void) {
        self.transactions = transactions.map {
            if $0.postings.contains(where: { $0.accountName == WealthsimpleLedgerMapper.fallbackExpenseAccountName }) {
                return ImportedTransaction($0,
                                           shouldAllowUserToEdit: true,
                                           accountName: $0.postings.first { $0.accountName != WealthsimpleLedgerMapper.fallbackExpenseAccountName }!.accountName)
            }
            return ImportedTransaction($0)
        }
        completion()
    }

    override func nextTransaction() -> ImportedTransaction? {
        guard !transactions.isEmpty else {
            return nil
        }
        return transactions.removeFirst()
    }

    override func balancesToImport() -> [Balance] {
       balances
    }

    override func pricesToImport() -> [Price] {
        prices
    }

    private func authenticationCallback(callback: @escaping ((String, String, String) -> Void)) {
        var username, password, otp: String!

        let group = DispatchGroup()
        group.enter()

        delegate?.requestInput(name: "Username", suggestions: [], isSecret: false) {
            username = $0
            group.leave()
            return true
        }
        group.wait()
        group.enter()
        delegate?.requestInput(name: "Password", suggestions: [], isSecret: true) {
            password = $0
            group.leave()
            return true
        }
        group.wait()
        group.enter()
        delegate?.requestInput(name: "OTP", suggestions: [], isSecret: false) {
            otp = $0
            group.leave()
            return true
        }
        group.wait()
        callback(username, password, otp)
    }

}

extension WealthsimpleDownloadImporter: CredentialStorage {

    func save(_ value: String, for key: String) {
        self.delegate?.saveCredential(value, for: "\(Self.importerType)-\(key)")
    }

    func read(_ key: String) -> String? {
        self.delegate?.readCredential("\(Self.importerType)-\(key)")
    }

}

extension WealthsimpleDownloader: WealthsimpleDownloaderProvider {
}
