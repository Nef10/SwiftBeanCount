//
//  CompassCardDownloadImporter.swift
//
//
//  Created by Steffen Kötte on 2023-03-11.
//

#if canImport(UIKit) || canImport(AppKit)

import CompassCardDownloader
import Foundation
import SwiftBeanCountCompassCardMapper
import SwiftBeanCountModel
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

protocol CompassCardDownloaderProvider: AnyObject {
    var delegate: CompassCardDownloaderDelegate? { get set }

    func authorizeAndGetBalance(email: String, password: String, _ completion: @escaping (Result<(String, String), Error>) -> Void)
    func downloadCardTransactions(cardNumber: String, dateToLoadFrom: Date, _ completion: @escaping (Result<String, Error>) -> Void)
}

protocol SwiftBeanCountCompassCardMapperProvider {
    var defaultExpenseAccountName: AccountName { get }
    var defaultAssetAccountName: AccountName { get }

    func createBalance(cardNumber: String, balance: String, date: Date?) throws -> Balance
    func createTransactions(cardNumber: String, transactions: String) throws -> [Transaction]
    func ledgerCardAccountName(cardNumber: String) throws -> AccountName
}

@available(iOS 14.5, macOS 11.3, *)
class CompassCardDownloadImporter: BaseImporter, DownloadImporter {

    enum MetaDataKey {
        static let customsKey = "compass-card-download-importer"
        static let daysSettings = "pastDaysToLoad"
    }

    enum CredentialKey: String, CaseIterable {
        case username
        case password
    }

    override class var importerName: String { "Compass Card Download" }
    override class var importerType: String { "compass-card-download" }
    override class var helpText: String { //  swiftlint:disable line_length
        """
        Downloads transactions and the current balance from the Compass Card website.

        The importer relies on meta data in your Beancount file to find your accounts.
        Please add `importer-type: "compass-card"` and `card-number: "XXXXXXXXXXXXXXXXXXXX"` to your Compass Card Asset account.

        To automatically add the expense account, add `compass-card-expense: "XXXXXXXXXXXXXXXXXXXX"` with the card number to an account - for auto load, use `compass-card-load: "XXXXXXXXXXXXXXXXXXXX"`.

        By default the last two month of data are loaded. To control this, add a custom options like this to your file: YYYY-MM-DD custom "compass-card-download-importer" "pastDaysToLoad" "5".
        """
    } //  swiftlint:enable line_length

    override var importName: String { "Compass Card Download" }

    private let existingLedger: Ledger
    private let mapper: SwiftBeanCountCompassCardMapperProvider
    private let downloader: CompassCardDownloaderProvider

    private let sixtyTwoDays = -60 * 60 * 24 * 62.0

    /// Results
    private var transactions = [ImportedTransaction]()
    private var balance: Balance?

    override required convenience init(ledger: Ledger?) {
        self.init(ledger: ledger, downloader: CompassCardDownloader())
    }

    init(ledger: Ledger?, downloader: CompassCardDownloaderProvider, mapper: SwiftBeanCountCompassCardMapper? = nil) {
        existingLedger = ledger ?? Ledger()
        self.mapper = mapper ?? SwiftBeanCountCompassCardMapper(ledger: existingLedger)
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
        let email = getCredential(key: .username, name: "Email", type: .text([]))
        let password = getCredential(key: .password, name: "Password", type: .secret)

        downloader.authorizeAndGetBalance(email: email, password: password) {
            switch $0 {
            case .success(let (cardNumber, balance)):
                do {
                    self.balance = try self.mapper.createBalance(cardNumber: cardNumber, balance: balance, date: nil)
                    self.downloadTransactions(cardNumber, completion)
                } catch {
                    self.importFinished(error: error, completion: completion)
                }
            case .failure(let error):
                self.removeSavedCredentials {
                    self.importFinished(error: error, completion: completion)
                }
            }
        }
    }

    private func downloadTransactions(_ cardNumber: String, _ completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.downloader.downloadCardTransactions(cardNumber: cardNumber, dateToLoadFrom: self.dateToLoadFrom()) { result in
                switch result {
                case .success(let transactions):
                    do {
                        let transactions = try self.mapper.createTransactions(cardNumber: cardNumber, transactions: transactions)
                        try self.mapTransactions(transactions, cardNumber: cardNumber)
                    } catch {
                        self.importFinished(error: error, completion: completion)
                        return
                    }
                    self.importFinished(completion: completion)
                case .failure(let error):
                    self.importFinished(error: error, completion: completion)
                }
            }
        }
    }

    private func importFinished(error: Error? = nil, completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.delegate?.removeView()
            DispatchQueue.global(qos: .userInitiated).async {
                if let error {
                    self.delegate?.error(error)
                }
                completion()
            }
        }
    }

    private func mapTransactions(_ importedTransactions: [Transaction], cardNumber: String) throws {
        transactions = importedTransactions.map {
            let defaultAccounts = [mapper.defaultExpenseAccountName, mapper.defaultAssetAccountName]
            let description = $0.metaData.narration
            let (savedDescription, savedPayee) = savedDescriptionAndPayeeFor(description: description)
            let metaData = TransactionMetaData(date: $0.metaData.date,
                                               payee: savedPayee ?? $0.metaData.payee,
                                               narration: savedDescription ?? description,
                                               metaData: $0.metaData.metaData)
            let transaction = Transaction(metaData: metaData, postings: $0.postings)
            let shouldAllowToEdit = (savedDescription == nil && !description.isEmpty) || transaction.postings.contains { defaultAccounts.contains($0.accountName) }
            return ImportedTransaction(transaction,
                                       originalDescription: description,
                                       shouldAllowUserToEdit: shouldAllowToEdit,
                                       accountName: shouldAllowToEdit ? try? mapper.ledgerCardAccountName(cardNumber: cardNumber) : nil)
        }
    }

    override func nextTransaction() -> ImportedTransaction? {
        guard !transactions.isEmpty else {
            return nil
        }
        return transactions.removeFirst()
    }

    override func balancesToImport() -> [Balance] {
        if let balance {
            return [balance]
        }
        return []
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

@available(iOS 14.5, macOS 11.3, *)
extension CompassCardDownloadImporter: CompassCardDownloaderDelegate {

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

@available(iOS 14.5, macOS 11.3, *)
extension CompassCardDownloader: CompassCardDownloaderProvider {
}

extension SwiftBeanCountCompassCardMapper: SwiftBeanCountCompassCardMapperProvider {
}

#endif
