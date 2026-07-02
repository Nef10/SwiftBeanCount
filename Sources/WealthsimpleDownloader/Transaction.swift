//
//  Transaction.swift
//  WealthsimpleDownloader
//
//  Created by Steffen Kötte on 2025-11-09.
//

import Foundation

/// Errors which can happen when retrieving a Transaction
public enum TransactionError: Error, Equatable {
    /// When no data is received from the HTTP request
    case noDataReceived
    /// When an HTTP error occurs
    case httpError(error: String)
    /// When the received data is not valid JSON
    case invalidJson(json: Data)
    /// When the received JSON does not have all expected values
    case missingResultParameter(json: [String: Any])
    /// When the received JSON does have an unexpected value
    case invalidResultParameter(json: [String: Any])
    /// An error with the token occured
    case tokenError(_ error: TokenError)
    /// Invalid Parameter
    case invalidParameter

    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.noDataReceived, .noDataReceived):
            return true

        case let (.httpError(lhs), .httpError(rhs)):
            return lhs == rhs

        case let (.invalidJson(lhs), .invalidJson(rhs)):
            return lhs == rhs

        case let (.missingResultParameter(lhs), .missingResultParameter(rhs)):
            return jsonEquals(lhs, rhs)

        case let (.invalidResultParameter(lhs), .invalidResultParameter(rhs)):
            return jsonEquals(lhs, rhs)

        case let (.tokenError(lhs), .tokenError(rhs)):
            return lhs == rhs

        case (.invalidParameter, .invalidParameter):
            return true

        default:
            return false
        }
    }

    private static func jsonEquals(_ lhs: [String: Any], _ rhs: [String: Any]) -> Bool {
        guard JSONSerialization.isValidJSONObject(lhs),
              JSONSerialization.isValidJSONObject(rhs),
              let lhsJson = try? JSONSerialization.data(withJSONObject: lhs, options: [.sortedKeys]),
              let rhsJson = try? JSONSerialization.data(withJSONObject: rhs, options: [.sortedKeys]) else {
            return false
        }
        return lhsJson == rhsJson
    }
}

/// Type for the transaction, e.g. buying or selling
public enum TransactionType: String {
    /// buying a Stock, ETF, ...
    case buy
    /// depositing cash in a registered account
    case contribution
    /// receiving a cash dividend
    case dividend
    /// custodian fee
    case custodianFee
    /// depositing cash in an unregistered account
    case deposit
    /// wealthsimple management fee
    case fee
    /// forex
    case forex
    /// grant
    case grant
    /// home buyers plan
    case homeBuyersPlan
    /// hst
    case hst
    /// charged interest
    case chargedInterest
    /// journal
    case journal
    /// US non resident withholding tax on dividend payments
    case nonResidentWithholdingTax
    /// redemption
    case redemption
    /// risk exposure fee
    case riskExposureFee
    /// refund
    case refund
    /// reimbursements, e.g. ETF Fee Rebates
    case reimbursement
    /// selling a Stock, ETF, ...
    case sell
    /// stock distribution
    case stockDistribution
    /// stock dividend
    case stockDividend
    /// transfer in
    case transferIn
    /// transfer out
    case transferOut
    /// withholding tax
    case withholdingTax
    /// withdrawal of cash
    case withdrawal
    /// Cash transfer into cash account
    case paymentTransferIn = "wealthsimplePaymentsTransferIn"
    /// Cash withdrawl from cash account
    case paymentTransferOut = "wealthsimplePaymentsTransferOut"
    /// Referral Bonus
    case referralBonus
    /// Interest paid in saving accounts
    case interest
    /// Wealthsimple Cash Card payments
    case paymentSpend = "wealthsimplePaymentsSpend"
    /// Wealthsimple Cash Cashback
    case giveawayBonus
    /// Wealthsimple Cash Cashback
    case cashbackBonus
    /// Online Bill Payment
    case onlineBillPayment
    /// Loaning out stock to a third party
    case stockLoanBorrow = "fPLLoanedSecurities"
    /// Returning stock which was borrowed from a third party
    case stockLoanReturn = "fPLRecalledSecurities"
    /// Manufactured dividend, which is paid out from the third party who borrowed the stock
    case manufacturedDividend
    /// Return of Capital (Adjusted Cost Base entry only)
    case returnOfCapital
    /// Non-cash Distribution (Adjusted Cost Base entry only)
    case nonCashDistribution
    /// Credit Card Purchase
    case purchase
    /// Credit Card Payment
    case payment
    /// Buy side of a currency conversion
    case currencyConversionBuy = "currencyConversionBuySide"
    /// Sell side of a currency conversion
    case currencyConversionSell = "currencyConversionSellSide"
}

/// A Transaction, like buying or selling stock
public protocol Transaction {
    /// Wealthsimples identifier of this transaction
    var id: String { get }
    /// Wealthsimple identifier of the account in which this transaction happend
    var accountId: String { get }
    /// type of the transaction, like buy or sell
    var transactionType: TransactionType { get }
    /// description of the transaction
    var description: String { get }
    /// symbol of the asset which is bought, sold, ...
    var symbol: String { get }
    /// Number of units of the asset bought, sold, ...
    var quantity: String { get }
    /// market pice of the asset
    var marketPriceAmount: String { get }
    /// Currency of the market price
    var marketPriceCurrency: String { get }
    /// market value of the assets
    var marketValueAmount: String { get }
    /// Currency of the market value
    var marketValueCurrency: String { get }
    /// Net cash change in the account
    var netCashAmount: String { get }
    /// Currency of the net cash change
    var netCashCurrency: String { get }
    /// Foreign exchange rate applied
    var fxRate: String { get }
    /// Date when the trade was settled
    var effectiveDate: Date { get }
    /// Date when the trade was processed
    var processDate: Date { get }
}

extension TransactionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noDataReceived:
            return "No Data was received from the server"
        case let .httpError(error):
            return "An HTTP error occurred: \(error)"
        case let .invalidJson(error):
            return "The server response contained invalid JSON: \(error)"
        case let .missingResultParameter(json):
            let string = String(data: ((try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])) ?? Data()), encoding: .utf8) ?? ""
            return "The server response JSON was missing expected parameters: \(string)"
        case let .invalidResultParameter(json):
            let string = String(data: ((try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])) ?? Data()), encoding: .utf8) ?? ""
            return "The server response JSON contained invalid parameters: \(string)"
        case let .tokenError(error):
            return error.localizedDescription
        case .invalidParameter:
            return "Invalid paramter passed in"
        }
    }
}
