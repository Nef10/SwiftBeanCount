//
//  Account.swift
//
//
//  Created by Steffen Kötte on 2020-07-12.
//

import Foundation
 #if canImport(FoundationNetworking)
 import FoundationNetworking
 #endif

/// Errors which can happen when retrieving an Account
public enum AccountError: Error, Equatable {
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
    /// An error with the token occured
    case tokenError(_ error: TokenError)
}

/// Type of the account
///
/// Note: Currently only Canadian Accounts are supported
public enum AccountType: String {
    /// Tax free savings account (CA)
    case tfsa = "ca_tfsa"
    /// Cash (chequing) account (CA)
    case chequing = "ca_cash_msb"
    /// Saving (CA)
    case saving = "ca_cash"
    /// Registered Retirement Savings Plan (CA)
    case rrsp = "ca_rrsp"
    /// Non-registered account (CA)
    case nonRegistered = "ca_non_registered"
    /// Non-registered crypto currency account (CA)
    case nonRegisteredCrypto = "ca_non_registered_crypto"
    /// Locked-in retirement account (CA)
    case lira = "ca_lira"
    /// Joint account (CA)
    case joint = "ca_joint"
    /// Registered Retirement Income Fund (CA)
    case rrif = "ca_rrif"
    /// Life Income Fund (CA)
    case lif = "ca_lif"
    /// Credit Card (CA)
    case creditCard = "ca_credit_card"
}

/// An Account at Wealthsimple
public protocol Account {

    /// Type of the account
    var accountType: AccountType { get }
    /// Operating currency of the account
    var currency: String { get }
    /// Wealthsimple id for the account
    var id: String { get }
    /// Number of the account
    var number: String { get }

}

struct WealthsimpleAccount: Account {

    private static var url: URL { URLConfiguration.shared.urlObject(for: "accounts")! }

    let accountType: AccountType
    let currency: String
    let id: String
    let number: String

    private init(json: [String: Any]) throws {
        guard let id = json["id"] as? String,
              let typeString = json["type"] as? String,
              let object = json["object"] as? String,
              let currency = json["base_currency"] as? String,
              let number = json["custodian_account_number"] as? String else {
            throw AccountError.missingResultParamenter(json: String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
        }
        guard let type = AccountType(rawValue: typeString), object == "account" else {
            throw AccountError.invalidResultParamenter(json: String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
        }
        self.id = id
        self.accountType = type
        self.currency = currency
        self.number = number
    }

    static func getAccounts(token: Token, completion: @escaping (Result<[Account], AccountError>) -> Void) {
        var request = URLRequest(url: url)
        let session = URLSession.shared
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        token.authenticateRequest(request) { request in
            let task = session.dataTask(with: request) { data, response, error in
                handleResponse(data: data, response: response, error: error, completion: completion)
            }
            task.resume()
        }
    }

    private static func handleResponse(data: Data?, response: URLResponse?, error: Error?, completion: (Result<[Account], AccountError>) -> Void) {
        guard let data else {
            if let error {
                completion(.failure(AccountError.httpError(error: error.localizedDescription)))
            } else {
                completion(.failure(AccountError.noDataReceived))
            }
            return
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(AccountError.httpError(error: "No HTTPURLResponse")))
            return
        }
        guard httpResponse.statusCode == 200 else {
            completion(.failure(AccountError.httpError(error: "Status code \(httpResponse.statusCode)")))
            return
        }
        completion(parse(data: data))
    }

    private static func parse(data: Data) -> Result<[Account], AccountError> {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return .failure(AccountError.invalidJson(json: data))
        }
        do {
            guard let results = json["results"] as? [[String: Any]], let object = json["object"] as? String else {
                throw AccountError.missingResultParamenter(json: String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
            }
            guard object == "account" else {
                throw AccountError.invalidResultParamenter(json: String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
            }
            var accounts = [Account]()
            for result in results {
                accounts.append(try Self(json: result))
            }
            return .success(accounts)
        } catch {
            return .failure(error as! AccountError) // swiftlint:disable:this force_cast
        }
    }
}
