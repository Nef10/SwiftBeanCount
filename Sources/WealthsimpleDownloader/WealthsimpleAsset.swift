//
//  Asset.swift
//
//
//  Created by Steffen Kötte on 2020-07-12.
//

import Foundation

/// Errors which can happen when retrieving an Asset
public enum AssetError: Error, Equatable {
    /// When the received JSON does not have all expected values
    case missingResultParamenter(json: String)
    /// When the received JSON does have an unexpected value
    case invalidResultParamenter(json: String)
}

/// Type of the asset
public enum AssetType: String {
    /// Cash
    case currency
    /// Equity
    case equity
    /// Mutal Funds
    case mutualFund = "mutual_fund"
    /// Bonds
    case bond
    /// ETFs
    case exchangeTradedFund = "exchange_traded_fund"
}

/// An asset, like a stock or a currency
public protocol Asset {
    /// Symbol of the asset, e.g. currency or ticker symbol
    var symbol: String { get }
    /// Full name of the asset
    var name: String { get }
    /// Currency the asset is held in
    var currency: String { get }
    /// Type of the asset, e.g. currency or ETF
    var type: AssetType { get }
}

struct WealthsimpleAsset: Asset {

    let symbol: String
    let name: String
    let currency: String
    let type: AssetType
    let id: String

    init(json: [String: Any]) throws {
        guard let id = json["security_id"] as? String,
              let symbol = json["symbol"] as? String,
              let currency = json["currency"] as? String,
              let name = json["name"] as? String,
              let typeString = json["type"] as? String else {
            throw AssetError.missingResultParamenter(json: String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
        }
        guard let type = AssetType(rawValue: typeString) else {
            throw AssetError.invalidResultParamenter(json: String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
        }
        self.id = id
        self.symbol = symbol
        self.currency = currency
        self.name = name
        self.type = type
    }

    init(currency: String) {
        self.id = currency
        self.symbol = currency
        self.currency = currency
        self.name = currency
        self.type = .currency
    }

}
