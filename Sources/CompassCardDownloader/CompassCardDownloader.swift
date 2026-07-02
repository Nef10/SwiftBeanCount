import Foundation
import SwiftScraper

/// Class to download the current balance and transactions from your CompassCard
///
/// This class uses a webscraper to login.
/// Your delegate needs to provide a view to add the webview to
@available(iOS 14.5, macOS 11.3, *)
public class CompassCardDownloader {

    private static var dateFormatterURL: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd hh:mm:ss a"
        return dateFormatter
    }()

    /// Delegate for the CompassCardDownloader
    public weak var delegate: CompassCardDownloaderDelegate?

    private var stepRunner: StepRunner?

    /// Creates an instance of the CompassCardDownloader
    public init() {
        // Do nothing
    }

    /// Logs into the Compass Card website and reads the current balance
    ///
    /// Note: If you want to call this function multiple times, be aware that
    ///       it will request a view every time
    ///
    /// - Parameters:
    ///   - email: email adress to login
    ///   - password: password to login
    ///   - completion: completion handler - receives result of card number and balance
    public func authorizeAndGetBalance(email: String, password: String, _ completion: @escaping (Result<(String, String), Error>) -> Void) {
        DispatchQueue.main.async {
            do {
                let steps = self.authorizeAndGetBalanceSteps(email: email, password: password)
                let stepRunner = try StepRunner(moduleName: "CompassCardDownload", steps: steps, scriptBundle: Bundle.module)
                self.stepRunner = stepRunner
                if let view = self.delegate?.view() {
                    stepRunner.insertWebViewIntoView(parent: view)
                }
                stepRunner.run {
                    if case let .failure(error) = stepRunner.state {
                        completion(.failure(error))
                    } else {
                        completion(.success((stepRunner.model["cardNumber"] as! String, stepRunner.model["balance"] as! String))) // swiftlint:disable:this force_cast
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Downloads the transactions for the card
    ///
    /// Note: you need to call this function after `authorizeAndGetBalance` as only
    ///       this one adds the webview to the view from the delegate
    ///
    /// - Parameters:
    ///   - card number: number of the compass card, can be obtained from authorizeAndGetBalance
    ///   - dateToLoadFrom: Date which will be passed to the API as start date to load transactions
    ///   - completion: completion handler which returns a string with the CSV result
    public func downloadCardTransactions(cardNumber: String, dateToLoadFrom: Date, _ completion: @escaping (Result<String, Error>) -> Void) {
        let fromDate = Self.dateFormatterURL.string(from: dateToLoadFrom)
        let toDate = Self.dateFormatterURL.string(from: Date())
        let url = "https://www.compasscard.ca/handlers/compasscardusagepdf.ashx?type=2&start=\(fromDate)&end=\(toDate)&ccsn=\(cardNumber)&csv=true"
        let downloadCSV = DownloadStep(url: URL(string: url.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!)!) { response, model in
            model["transactions"] = response as! String // swiftlint:disable:this force_cast
            return .proceed
        }
        DispatchQueue.main.async {
            guard let stepRunner = self.stepRunner else {
                return
            }
            stepRunner.run(steps: [downloadCSV]) {
                if case let .failure(error) = self.stepRunner?.state {
                    completion(.failure(error))
                } else {
                    completion(.success(stepRunner.model["transactions"] as! String)) // swiftlint:disable:this force_cast
                }
            }
        }
    }

    private func authorizeAndGetBalanceSteps(email: String, password: String) -> [Step] {
        let shortWait = WaitStep(waitTimeInSeconds: 1)
        let checkLoggedIn = ScriptStep(functionName: "getTitle") { response, _ in
            if response as? String == "Compass - My Cards" {
                return .jumpToStep(9)
            }
            return .proceed
        }
        let getCardNumber = ScriptStep(functionName: "getText", params: ".card-number span") { response, model in
            model["cardNumber"] = response
            return .proceed
        }
        let getBalance = ScriptStep(functionName: "getText", params: ".stored-values span") { response, model in
            model["balance"] = response
            return .proceed
        }
        return [
                OpenPageStep(path: "https://www.compasscard.ca/SignIn"),
                WaitForConditionStep(assertionName: "assertTitles", timeoutInSeconds: 5, params: "Compass - Sign In", "Compass - My Cards"),
                checkLoggedIn,
                ScriptStep(functionName: "enterField", params: "#Content_emailInfo_txtEmail", email) { _, _ in .proceed },
                shortWait,
                ScriptStep(functionName: "enterField", params: "#Content_passwordInfo_txtPassword", password) { _, _ in .proceed },
                shortWait,
                PageChangeStep(functionName: "clickSubmitButton"),
                WaitForConditionStep(assertionName: "assertTitle", timeoutInSeconds: 5, params: "Compass - My Cards"),
                getCardNumber,
                getBalance
        ]
    }

}
