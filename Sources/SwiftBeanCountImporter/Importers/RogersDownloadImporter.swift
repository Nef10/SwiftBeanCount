//
//  RogersDownloadImporter.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2021-09-10.
//  Copyright © 2021 Steffen Kötte. All rights reserved.
//

import Foundation
import RogersBankDownloader
import SwiftBeanCountModel
import SwiftBeanCountRogersBankMapper

class RogersDownloadImporter: BaseImporter, DownloadImporter, RogersAuthenticatorDelegate {

    enum MetaDataKey {
        static let customsKey = "rogers-download-importer"
        static let customStatementsToLoad = "statementsToLoad"
    }

    enum CredentialKey: String, CaseIterable {
        case username
        case password
        case deviceId
    }

    override class var importerName: String { "Rogers Bank Download" }
    override class var importerType: String { "rogers" }
    override class var helpText: String {
        """
        Downloads transactions and the current balance from the Rogers Bank website.

        The importer relies on meta data in your Beancount file to find your accounts. Please add:
        * importer-type: "rogers"
        * last-four: "XXXX" with the last four digits of your Credit Card number
        to your Credit Card Liability account.

        By default transaction from the current and the last two statements are loaded. To control this, and for example only load the current statement, add a custom option to your file: YYYY-MM-DD custom "\(MetaDataKey.customsKey)" "\(MetaDataKey.customStatementsToLoad)" "1".

        """
    }

    override var importName: String { "Rogers Bank Download" }
    var authenticatorClass: Authenticator.Type = RogersAuthenticator.self

    private let existingLedger: Ledger

    private var mapper: SwiftBeanCountRogersBankMapper

    /// Results
    private var transactions = [ImportedTransaction]()
    private var balances = [Balance]()

    override required init(ledger: Ledger?) {
        existingLedger = ledger ?? Ledger()
        mapper = SwiftBeanCountRogersBankMapper(ledger: existingLedger)
        super.init(ledger: ledger)
    }

    override func load() {
        let group = DispatchGroup()
        group.enter()

        download {
            group.leave()
        }

        group.wait()
    }

    private func download(_ completion: @escaping () -> Void) {
        getCredentials {
            var authenticator = self.authenticatorClass.init()
            authenticator.delegate = self
            authenticator.login(username: $0, password: $1, deviceId: $2) { result in
                switch result {
                case let .failure(error):
                    self.delegate?.error(error) {
                        self.removeSavedCredentials {
                            completion()
                        }
                    }
                case let .success(user):
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.downloadAllActivities(accounts: user.accounts, completion)
                    }
                }
            }
        }
    }

    private func downloadAllActivities(accounts: [RogersBankDownloader.Account], _ completion: @escaping () -> Void) { // swiftlint:disable:this function_body_length
        let group = DispatchGroup(), queue = DispatchQueue(label: "threadSafeDownloadedActivitiesArray")
        var downloadedActivities = [Activity](), errorOccurred = false

        accounts.forEach { account in
            for statementNumber in 0...statementsToLoad() - 1 {
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    account.downloadActivities(statementNumber: statementNumber) { result in
                        switch result {
                        case let .failure(error):
                            errorOccurred = true
                            self.showError(error)
                            group.leave()
                        case let .success(activities):
                            queue.async {
                                downloadedActivities.append(contentsOf: activities)
                                group.leave()
                            }
                        }
                    }
                }
            }
            do {
                self.balances.append(try self.mapper.mapAccountToBalance(account: account))
            } catch {
                showError(error)
                errorOccurred = true
            }
        }

        group.wait()
        if !errorOccurred {
            queue.sync {
                self.mapActivities(downloadedActivities, completion)
            }
        } else {
            completion()
        }
    }

    private func mapActivities(_ activities: [Activity], _ completion: @escaping () -> Void) {
        var transactions = [SwiftBeanCountModel.Transaction]()
        do {
            transactions.append(contentsOf: try self.mapper.mapActivitiesToTransactions(activities: activities))
        } catch {
            self.delegate?.error(error) {
                completion()
            }
            return
        }

        self.transactions = transactions.map {
            var expenseAccounts = [mapper.expenseAccountName]
            let (savedDescription, savedPayee) = savedDescriptionAndPayeeFor(description: $0.metaData.narration)
            let metaData = TransactionMetaData(date: $0.metaData.date,
                                               payee: savedPayee ?? $0.metaData.payee,
                                               narration: savedDescription ?? $0.metaData.narration,
                                               metaData: $0.metaData.metaData)
            var transaction = Transaction(metaData: metaData, postings: $0.postings)
            if let account = savedAccountNameFor(payee: transaction.metaData.payee),
                let posting = transaction.postings.first(where: { $0.accountName == mapper.expenseAccountName }) {
                expenseAccounts.append(account)
                var postings: [Posting] = transaction.postings.filter { $0 != posting }
                postings.append(Posting(accountName: account, amount: posting.amount, price: posting.price, cost: posting.cost))
                transaction = Transaction(metaData: transaction.metaData, postings: postings)
            }

            return ImportedTransaction(transaction,
                                       originalDescription: $0.metaData.narration,
                                       shouldAllowUserToEdit: true,
                                       accountName: transaction.postings.first { !expenseAccounts.contains($0.accountName) }!.accountName)
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

    func selectTwoFactorPreference(_ preferences: [RogersBankDownloader.TwoFactorPreference]) -> RogersBankDownloader.TwoFactorPreference {
        if preferences.count == 1 {
            return preferences.first!
        }
        let group = DispatchGroup()
        group.enter()
        var result: String!
        self.delegate?.requestInput(name: "prefered One Time Password option", type: .choice(preferences.map(\.value))) {
            guard preferences.map(\.value).contains($0) else {
                return false
            }
            result = $0
            group.leave()
            return true
        }
        group.wait()
        return preferences.first { $0.value == result }!
    }

    func getTwoFactorCode() -> String {
        var value: String!
        let group = DispatchGroup()
        group.enter()
        delegate?.requestInput(name: "One Time Password", type: .otp) {
            value = $0
            group.leave()
            return true
        }
        group.wait()
        return value
    }

    func saveDeviceId(_ deviceId: String) {
        self.delegate?.saveCredential(deviceId, for: "\(Self.importerType)-\(CredentialKey.deviceId.rawValue)")
    }

    private func showError(_ error: Error) {
        let group = DispatchGroup()
        group.enter()
        self.delegate?.error(error) {
            group.leave()
        }
        group.wait()
    }

    private func statementsToLoad() -> Int {
        let statements = Int(existingLedger.custom.filter { $0.name == MetaDataKey.customsKey && $0.values.first == MetaDataKey.customStatementsToLoad }
                                                  .max { $0.date < $1.date }?
                                                  .values[1] ?? "")
        return statements ?? 3
    }

    private func getCredentials(callback: @escaping ((String, String, String) -> Void)) {
        let username = getCredential(key: .username, name: "Username", type: .text([]))
        let password = getCredential(key: .password, name: "Password", type: .secret)
        let deviceId = self.delegate?.readCredential("\(Self.importerType)-\(CredentialKey.deviceId.rawValue)") ?? ""
        callback(username, password, deviceId)
    }

    private func removeSavedCredentials(_ completion: @escaping () -> Void) {
        self.delegate?.requestInput(name: "The login failed. Do you want to remove the saved credentials", type: .bool) {
            guard let delete = Bool($0) else {
                return false
            }
            if delete {
                for key in CredentialKey.allCases {
                    self.delegate?.saveCredential("", for: "\(Self.importerType)-\(key.rawValue)")
                }
            }
            completion()
            return true
        }
    }

    private func getCredential(key: CredentialKey, name: String, type: ImporterInputRequestType) -> String {
        var value: String!
        if let savedValue = self.delegate?.readCredential("\(Self.importerType)-\(key.rawValue)"), !savedValue.isEmpty {
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
            self.delegate?.saveCredential(value, for: "\(Self.importerType)-\(key.rawValue)")
        }
        return value
    }

}
