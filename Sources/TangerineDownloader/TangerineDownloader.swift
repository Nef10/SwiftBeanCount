#if canImport(SwiftScraper)

import Foundation
import SwiftScraper

/// Class to download accounts and transactions from Tangerine
///
/// This class uses a webscraper to login.
/// Your delegate needs to provide a view to add the webview to, as well
/// as the otp the user received during the login attempt.
public class TangerineDownloader {

    private static var dateFormatterURL: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return dateFormatter
    }()

    /// Delegate for the TangerineDownloader
    public weak var delegate: TangerineDownloaderDelegate?

    private var stepRunner: StepRunner?

    /// Creates an instance of the TangerineDownloader
    public init() {
        // Do nothing
    }

    /// Logs into the Tangerine website and requests the accounts
    ///
    /// Note: If you want to call this function multiple times, be aware that
    ///       it will request a view every time
    ///
    /// - Parameters:
    ///   - username: Tangerine website username / Login ID
    ///   - pin: Tangerine website password
    ///   - completion: completion handler - receives Result with an array containing the account info
    public func authorizeAndGetAccounts(username: String, password: String, _ completion: @escaping (Result<[[String: Any]], Error>) -> Void) {

        DispatchQueue.main.async {
            do {
                let steps = self.authorizeAndGetAccountSteps(username: username, password: password)
                let stepRunner = try StepRunner(moduleName: "TangerineDownload", steps: steps, scriptBundle: Bundle.module)
                self.stepRunner = stepRunner
                if let view = self.delegate?.view() {
                    stepRunner.insertWebViewIntoView(parent: view)
                }
                stepRunner.run {
                    if case let .failure(error) = stepRunner.state {
                        completion(.failure(error))
                    } else {
                        completion(.success(stepRunner.model["accounts"] as! [[String: Any]])) // swiftlint:disable:this force_cast
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Downloads the transactions for accounts
    ///
    /// Note: you need to call this function after `authorizeAndGetAccounts` as only
    ///       this one adds the webview to the view from the delegate
    ///
    /// - Parameters:
    ///   - accounts: dictionary of accounts to load. Mapping from account name to the JSON received from `authorizeAndGetAccounts`
    ///   - dateToLoadFrom: Date which will be passed to the API as start date to load transactions
    /// - Returns: completion handler which returns a Result with the account names mapped to and array of transaction JSONs
    public func downloadAccountTransactions(accounts: [String: [String: Any]], dateToLoadFrom: Date) -> Result<[String: [[String: Any]]], Error> {
        var error: Error?
        var transactions = [String: [[String: Any]]]()
        accounts.forEach { accountName, account in
            let group = DispatchGroup()
            group.enter()
            self.downloadAccount(account, name: accountName, dateToLoadFrom: dateToLoadFrom) {
                switch $0 {
                case .success(let downloadedTransaction):
                    transactions = transactions.merging(downloadedTransaction) { _, new in new }
                case .failure(let accountError):
                    error = accountError
                }
                group.leave()
            }
            group.wait()
        }
        if let error {
            return .failure(error)
        }
        return .success(transactions)
    }

    private func authorizeAndGetAccountSteps(username: String, password: String) -> [Step] { // swiftlint:disable:this function_body_length
        let shortWait = WaitStep(waitTimeInSeconds: 1)
        let clickSubmit = ScriptStep(functionName: "clickSubmitButton") { _, _ in .proceed }
        let checkLoggedIn = ScriptStep(functionName: "getTitle") { response, _ in
            if response as? String == "Overview | Tangerine" {
                return .jumpToStep(19)
            }
            return .proceed
        }
        let getCode = AsyncProcessStep { model, completion in
            var model = model
            DispatchQueue.global(qos: .userInitiated).async {
                model["otpFieldSelector"] = "input[id='login-otp-input']"
                model["otp"] = self.delegate?.getOTPCode() ?? ""
                DispatchQueue.main.async {
                    completion(model, .proceed)
                }
            }
        }
        let getAccounts = ScriptStep(functionName: "getContent") { response, model in
            if let response = response as? JSON, let accounts = response["accounts"] as? [JSON] {
                model["accounts"] = accounts
                return .proceed
            }
            return .failure(TangerineDownloaderError.accountsLoadingFailed)
        }
        return [
                OpenPageStep(path: "https://www.tangerine.ca/app/#/login/login-id?locale=en_CA"),
                WaitForConditionStep(assertionName: "assertTitles", timeoutInSeconds: 5, params: "Log in | Tangerine", "Overview | Tangerine"),
                checkLoggedIn,
                shortWait,
                ScriptStep(functionName: "enterField", params: "input[aria-label='Login ID']", username) { _, _ in .proceed },
                shortWait,
                clickSubmit,
                WaitForConditionStep(assertionName: "assertTitle", timeoutInSeconds: 5, params: "Enter your Password | Tangerine"),
                shortWait,
                ScriptStep(functionName: "enterField", params: "input[id='passwordId-input']", password) { _, _ in .proceed },
                shortWait,
                clickSubmit,
                WaitForConditionStep(assertionName: "assertTitle", timeoutInSeconds: 5, params: "Enter your Security Code | Tangerine"),
                getCode,
                ScriptStep(functionName: "enterField", paramsKeys: ["otpFieldSelector", "otp"]) { _, _ in .proceed },
                shortWait,
                clickSubmit,
                shortWait,
                WaitForConditionStep(assertionName: "assertTitle", timeoutInSeconds: 5, params: "Overview | Tangerine"),
                shortWait,
                OpenPageStep(path: "https://secure.tangerine.ca/web/rest/pfm/v1/accounts"),
                getAccounts
        ]
    }

    private func downloadAccount(_ account: JSON, name accountName: String, dateToLoadFrom: Date, _ completion: @escaping (Result<[String: [[String: Any]]], Error>) -> Void) {
        let number = account["number"] as? String ?? ""
        let fromDate = Self.dateFormatterURL.string(from: dateToLoadFrom)
        let toDate = Self.dateFormatterURL.string(from: Date())
        let url = "https://secure.tangerine.ca/web/rest/pfm/v1/transactions?skip=0&accountIdentifiers=\(number)&periodFrom=\(fromDate)&periodTo=\(toDate)"
        let openAccountPage = OpenPageStep(path: url)
        let getTransactions = ScriptStep(functionName: "getContent") { response, model in
            if let response = response as? JSON, let transactions = response["transactions"] as? [JSON] {
                var savedTransactions = model["transactions"] as? [String: [[String: Any]]] ?? [String: [[String: Any]]]()
                savedTransactions[accountName] = transactions
                model["transactions"] = savedTransactions
                return .proceed
            }
            return .failure(TangerineDownloaderError.transactionLoadingFailed)
        }
        DispatchQueue.main.async {
            guard let stepRunner = self.stepRunner else {
                return
            }
            stepRunner.run(steps: [openAccountPage, getTransactions]) {
                if case let .failure(error) = self.stepRunner?.state {
                    completion(.failure(error))
                } else {
                    completion(.success(stepRunner.model["transactions"] as! [String: [[String: Any]]])) // swiftlint:disable:this force_cast
                }
            }
        }
    }

}

#endif
