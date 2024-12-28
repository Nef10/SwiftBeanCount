//
//  TangerineDownloadImporter.swift
//
//
//  Created by Steffen Kötte on 2022-08-13.
//

#if canImport(UIKit) || canImport(AppKit)

import Foundation
import SwiftBeanCountModel
import SwiftBeanCountTangerineMapper
import TangerineDownloader
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

protocol TangerineDownloaderProvider: AnyObject {
    var delegate: TangerineDownloaderDelegate? { get set }

    func authorizeAndGetAccounts(username: String, pin: String, _ completion: @escaping (Result<[[String: Any]], Error>) -> Void)
    func downloadAccountTransactions(accounts: [String: [String: Any]], dateToLoadFrom: Date) -> Result<[String: [[String: Any]]], Error>
}

protocol SwiftBeanCountTangerineMapperProvider {
    var defaultAccountName: AccountName { get }

    func createTransactions(_ rawTransactions: [String: [[String: Any]]]) throws -> [Transaction]
    func createBalances(accounts: [[String: Any]], date: Date) throws -> [Balance]
    func ledgerAccountName(account: [String: Any]) throws -> AccountName
}

class TangerineDownloadImporter: BaseImporter, DownloadImporter {

    enum MetaDataKey {
        static let customsKey = "tangerine-download-importer"
        static let daysSettings = "pastDaysToLoad"
    }

    enum CredentialKey: String, CaseIterable {
        case username
        case password
        case otp
    }

    override class var importerName: String { "Tangerine Download" }
    override class var importerType: String { "tangerine-download" }
    override class var helpText: String { //  swiftlint:disable line_length
        """
        Downloads transactions and the current balance from the Tangerine website.

        The importer relies on meta data in your Beancount file to find your accounts.
        For Credit Cards, please add `importer-type: "tangerine-card"` and `last-four: "XXXX"` with the last four digits of your number to your Credit Card Liability account. For other account types (like Checking, Savings, and LOC), please add `importer-type: "tangerine-account"` and `number: "XXXX"` with the account number as meta data to the account in your Beancount file.

        By default the last two month of data are loaded. To control this, add a custom options like this to your file: YYYY-MM-DD custom "tangerine-download-importer" "pastDaysToLoad" "5".
        """
    } //  swiftlint:enable line_length

    override var importName: String { "Tangerine Download" }

    private let existingLedger: Ledger
    private let mapper: SwiftBeanCountTangerineMapperProvider
    private let downloader: TangerineDownloaderProvider

    private let sixtyTwoDays = -60 * 60 * 24 * 62.0

    /// Results
    private var transactions = [ImportedTransaction]()
    private var balances = [Balance]()

    override required convenience init(ledger: Ledger?) {
        self.init(ledger: ledger, downloader: TangerineDownloader())
    }

    init(ledger: Ledger?, downloader: TangerineDownloaderProvider, mapper: SwiftBeanCountTangerineMapperProvider? = nil) {
        existingLedger = ledger ?? Ledger()
        self.mapper = mapper ?? SwiftBeanCountTangerineMapper(ledger: existingLedger)
        self.downloader = downloader
        super.init(ledger: ledger)
    }

    override func load() {
        downloader.delegate = self
        let group = DispatchGroup()
        group.enter()

        download {
            group.leave()
        }

        group.wait()
    }

    private func download(_ completion: @escaping () -> Void) {
        let username = getCredential(key: .username, name: "Username", type: .text([]))
        let pin = getCredential(key: .password, name: "PIN", type: .secret)

        downloader.authorizeAndGetAccounts(username: username, pin: pin) {
            switch $0 {
            case .success(let accounts):
                do {
                    self.balances = try self.mapper.createBalances(accounts: accounts)
                    let accountDict = try accounts.reduce(into: [String: [String: Any]]()) {
                        let accountName = try self.mapper.ledgerAccountName(account: $1)
                        $0[accountName.fullName] = $1
                    }
                    self.downloadTransactions(accountDict, completion)
                } catch {
                    self.importFinished(error: error, completion: completion)
                    return
                }
            case .failure(let error):
                self.importFinished(error: error) {
                    self.removeSavedCredentials {
                        completion()
                    }
                }
                return
            }
        }
    }

    private func downloadTransactions(_ accountDict: [String: [String: Any]], _ completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.downloader.downloadAccountTransactions(accounts: accountDict, dateToLoadFrom: self.dateToLoadFrom())
            switch result {
            case .success(let transactions):
                do {
                    try self.mapTransactions(transactions)
                } catch {
                    self.importFinished(error: error, completion: completion)
                    return
                }
                self.importFinished(completion: completion)
            case .failure(let error):
                self.importFinished(error: error, completion: completion)
                return
            }
        }
    }

    private func importFinished(error: Error? = nil, completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.delegate?.removeView()
            DispatchQueue.global(qos: .userInitiated).async {
                if let error {
                    self.delegate?.error(error) {
                        completion()
                    }
                } else {
                    completion()
                }
            }
        }
    }

    private func mapTransactions(_ downloadedTransactions: [String: [[String: Any]]]) throws {
        transactions = try mapper.createTransactions(downloadedTransactions).map {
            var expenseAccounts = [mapper.defaultAccountName]
            let description = sanitize(description: $0.metaData.narration)
            let (savedDescription, savedPayee) = savedDescriptionAndPayeeFor(description: description)
            let metaData = TransactionMetaData(date: $0.metaData.date,
                                               payee: savedPayee ?? $0.metaData.payee,
                                               narration: savedDescription ?? description,
                                               metaData: $0.metaData.metaData)
            var transaction = Transaction(metaData: metaData, postings: $0.postings)
            if let account = savedAccountNameFor(payee: metaData.payee),
                let posting = transaction.postings.first(where: { $0.accountName == mapper.defaultAccountName }) {
                expenseAccounts.append(account)
                var postings: [Posting] = transaction.postings.filter { $0 != posting }
                postings.append(Posting(accountName: account, amount: posting.amount, price: posting.price, cost: posting.cost))
                transaction = Transaction(metaData: transaction.metaData, postings: postings)
            }

            return ImportedTransaction(transaction,
                                       originalDescription: description,
                                       shouldAllowUserToEdit: true,
                                       accountName: transaction.postings.first { !expenseAccounts.contains($0.accountName) }!.accountName)
        }
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

    private func dateToLoadFrom() -> Date {
        let customOptions = existingLedger.custom.filter { $0.name == MetaDataKey.customsKey && $0.values.first == MetaDataKey.daysSettings }
        guard let days = Int(customOptions.max(by: { $0.date < $1.date })?.values[1] ?? "") else {
            return Date(timeIntervalSinceNow: self.sixtyTwoDays )
        }
        return Date(timeIntervalSinceNow: -60 * 60 * 24 * Double(days) )
    }

    private func removeSavedCredentials(_ completion: @escaping () -> Void) {
        self.delegate?.requestInput(name: "The login failed. Do you want to remove the saved credentials", type: .bool) {
            guard let bool = Bool($0) else {
                return false
            }
            if bool {
                for key in CredentialKey.allCases {
                    self.delegate?.saveCredential("", for: "\(Self.importerType)-\(key.rawValue)")
                }
            }
            completion()
            return true
        }
    }

    private func getCredential(key: CredentialKey, name: String, type: ImporterInputRequestType, save: Bool = true) -> String {
        var value: String!
        if save, let savedValue = self.delegate?.readCredential("\(Self.importerType)-\(key.rawValue)"), !savedValue.isEmpty {
            value = savedValue
        } else {
            let group = DispatchGroup()
            group.enter()
            delegate?.requestInput(name: name, type: type) {
                value = $0
                group.leave()
                return true
            }
            group.wait()
        }
        if save {
            self.delegate?.saveCredential(value, for: "\(Self.importerType)-\(key.rawValue)")
        }
        return value
    }

}

extension TangerineDownloadImporter: TangerineDownloaderDelegate {

    public func getOTPCode() -> String {
        getCredential(key: .otp, name: "SMS Security Code", type: .otp, save: false)
    }

    #if canImport(UIKit)

    public func view() -> UIView? {
        self.delegate?.view()
    }

    #else

    public func view() -> NSView? {
        self.delegate?.view()
    }

    #endif
}

extension SwiftBeanCountTangerineMapperProvider {
    func createBalances(accounts: [[String: Any]]) throws -> [Balance] {
        try createBalances(accounts: accounts, date: Date())
    }
}

extension TangerineDownloader: TangerineDownloaderProvider {
}

extension SwiftBeanCountTangerineMapper: SwiftBeanCountTangerineMapperProvider {
}

#endif
