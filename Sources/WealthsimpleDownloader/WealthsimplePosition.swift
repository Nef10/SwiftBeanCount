//
//  Position.swift
//
//
//  Created by Steffen Kötte on 2020-07-12.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Errors which can happen when retrieving a Position
public enum PositionError: Error, Equatable {
    /// When no data is received from the HTTP request
    case noDataReceived
    /// When an HTTP error occurs
    case httpError(error: String)
    /// When the received data is not valid JSON
    case invalidJson(json: Data)
    /// When the received JSON does not have all expected values
    case missingResultParamenter(json: String)
    /// When the received JSON does have an unexpected value
    case invalidResultParamenter(json: String)
    /// An error with the assets occured
    case assetError(_ error: AssetError)
    /// An error with the token occured
    case tokenError(_ error: TokenError)
    /// An error with the request parameters occured
    case invalidRequestParameter(error: String)
}

/// A Position, like certain amount of a stock or a currency held in an account
public protocol Position {
    /// Wealthsimple identifier of the account in which this position is held
    var accountId: String { get }
    /// Asset which is held
    var asset: Asset { get }
    /// Number of units of the asset held
    var quantity: String { get }
    /// Price per pice of the asset on `priceDate`
    var priceAmount: String { get }
    /// Currency of the price
    var priceCurrency: String { get }
    /// Date of the positon
    var positionDate: Date { get }
}

struct WealthsimplePosition: Position {

    private static var baseUrl: URLComponents { URLConfiguration.shared.urlComponents(for: "positions")! }

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    private static let creditCardGraphQLQuery = """
        query FetchCreditCardAccountSummary($id: ID!) { \
            creditCardAccount(id: $id) { \
                ...CreditCardAccountSummary \
                __typename \
            } \
        } \
        fragment CreditCardAccountSummary on CreditCardAccount { \
            id \
            balance { \
                current \
                __typename \
            } \
            __typename \
        }
        """

    let accountId: String
    let asset: Asset
    let quantity: String
    let priceAmount: String
    let priceCurrency: String
    let positionDate: Date

    private init(json: [String: Any]) throws {
        guard let quantity = json["quantity"] as? String,
              let accountId = json["account_id"] as? String,
              let assetDict = json["asset"] as? [String: Any],
              let price = json["market_price"] as? [String: Any],
              let dateString = json["position_date"] as? String,
              let priceAmount = price["amount"] as? String,
              let priceCurrency = price["currency"] as? String,
              let object = json["object"] as? String
        else {
            throw PositionError.missingResultParamenter(json: String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
        }
        guard let date = Self.dateFormatter.date(from: dateString),
              object == "position" else {
            throw PositionError.invalidResultParamenter(json: String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
        }
        do {
            self.asset = try WealthsimpleAsset(json: assetDict)
        } catch {
            throw PositionError.assetError(error as! AssetError) // swiftlint:disable:this force_cast
        }
        self.accountId = accountId
        self.quantity = quantity
        self.priceAmount = priceAmount
        self.priceCurrency = priceCurrency
        self.positionDate = date
    }

    private init(creditCardJson json: [String: Any], account: Account) throws {
        guard let data = json["data"] as? [String: Any],
              let creditCardAccount = data["creditCardAccount"] as? [String: Any],
              let balance = creditCardAccount["balance"] as? [String: Any],
              let current = balance["current"] as? String else {
            throw PositionError.missingResultParamenter(json: String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
        }
        self.accountId = account.id
        self.quantity = "-\(current)"
        self.priceAmount = "1"
        self.priceCurrency = account.currency
        self.positionDate = Date()
        self.asset = WealthsimpleAsset(currency: account.currency)
    }

    static func getPositions(token: Token, account: Account, date: Date?, completion: @escaping (Result<[Position], PositionError>) -> Void) {
        if account.accountType == .creditCard {
            if date != nil {
                // Credit card positions do not support date parameter
                completion(.failure(.invalidRequestParameter(error: "Date parameter is not supported for credit card accounts")))
                return
            }
            getCreditCardPosition(token: token, account: account, completion: completion)
        } else {
            getRESTPositions(token: token, account: account, date: date, completion: completion)
        }
    }

    private static func getRESTPositions(token: Token, account: Account, date: Date?, completion: @escaping (Result<[Position], PositionError>) -> Void) {
        var url = baseUrl
        url.queryItems = [
            URLQueryItem(name: "account_id", value: account.id),
            URLQueryItem(name: "limit", value: "250")
        ]
        if let date {
            url.queryItems?.append(URLQueryItem(name: "date", value: dateFormatter.string(from: date)))
        }
        var request = URLRequest(url: url.url!)
        let session = URLSession.shared
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        token.authenticateRequest(request) { request in
            let task = session.dataTask(with: request) { data, response, error in
                handleResponse(data: data, response: response, error: error, completion: completion)
            }
            task.resume()
        }
    }

    private static func getCreditCardPosition(token: Token, account: Account, completion: @escaping (Result<[Position], PositionError>) -> Void) {
        guard var request = URLConfiguration.shared.graphQLURLRequest() else {
            completion(.failure(PositionError.httpError(error: "Invalid GraphQL URL")))
            return
        }
        let body: [String: Any] = [
            "operationName": "FetchCreditCardAccountSummary",
            "variables": ["id": account.id],
            "query": creditCardGraphQLQuery
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            completion(.failure(PositionError.httpError(error: "Failed to serialize GraphQL request")))
            return
        }
        request.httpBody = jsonData
        let session = URLSession.shared
        token.authenticateRequest(request) { request in
            let task = session.dataTask(with: request) { data, response, error in
                handleCreditCardResponse(data: data, response: response, error: error, account: account, completion: completion)
            }
            task.resume()
        }
    }

    private static func handleResponse(data: Data?, response: URLResponse?, error: Error?, completion: (Result<[Position], PositionError>) -> Void) {
        guard let data else {
            if let error {
                completion(.failure(PositionError.httpError(error: error.localizedDescription)))
            } else {
                completion(.failure(PositionError.noDataReceived))
            }
            return
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(PositionError.httpError(error: "No HTTPURLResponse")))
            return
        }
        guard httpResponse.statusCode == 200 else {
            completion(.failure(PositionError.httpError(error: "Status code \(httpResponse.statusCode)")))
            return
        }
        completion(parse(data: data))
    }

    private static func handleCreditCardResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        account: Account,
        completion: (Result<[Position], PositionError>) -> Void
    ) {
        guard let data else {
            if let error {
                completion(.failure(PositionError.httpError(error: error.localizedDescription)))
            } else {
                completion(.failure(PositionError.noDataReceived))
            }
            return
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(PositionError.httpError(error: "No HTTPURLResponse")))
            return
        }
        guard httpResponse.statusCode == 200 else {
            completion(.failure(PositionError.httpError(error: "Status code \(httpResponse.statusCode)")))
            return
        }
        completion(parseCreditCard(data: data, account: account))
    }

    private static func parse(data: Data) -> Result<[Position], PositionError> {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return .failure(PositionError.invalidJson(json: data))
        }
        do {
            guard let results = json["results"] as? [[String: Any]], let object = json["object"] as? String else {
                throw PositionError.missingResultParamenter(json:
                    String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
            }
            guard object == "position" else {
                throw PositionError.invalidResultParamenter(json:
                    String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
            }
            var positions = [Position]()
            for result in results {
                positions.append(try Self(json: result))
            }
            return .success(positions)
        } catch {
            return .failure(error as! PositionError) // swiftlint:disable:this force_cast
        }
    }

    private static func parseCreditCard(data: Data, account: Account) -> Result<[Position], PositionError> {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return .failure(PositionError.invalidJson(json: data))
        }
        do {
            let position = try Self(creditCardJson: json, account: account)
            return .success([position])
        } catch {
            return .failure(error as! PositionError) // swiftlint:disable:this force_cast
        }
    }

}
