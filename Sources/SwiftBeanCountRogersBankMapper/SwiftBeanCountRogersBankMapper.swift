import Foundation
import RogersBankDownloader
import SwiftBeanCountModel
import SwiftBeanCountParserUtils

/// Mapper to map downloaded accounts and activities to BeanCoutModel objects
public struct SwiftBeanCountRogersBankMapper {

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    /// Account name to which the expenses are posted
    public let expenseAccountName = try! AccountName("Expenses:TODO") // swiftlint:disable:this force_try

    private let ledger: Ledger

    /// Creates a mapper
    /// - Parameter ledger: Ledger which will be used to look up account names
    public init(ledger: Ledger) {
        self.ledger = ledger
    }

    /// Maps an account to a balance assertion
    /// - Parameter account: account to map
    /// - Throws: RogersBankMappingError if no matching account was found
    /// - Returns: balance assertion with the current balance form the credit card account
    public func mapAccountToBalance(account: RogersBankDownloader.Account) throws -> Balance {
        let (number, decimalDigits) = account.currentBalance.value.amountDecimal()
        let amount = Amount(number: -number, commoditySymbol: account.currentBalance.currency, decimalDigits: decimalDigits)
        let accountName = try ledgerAccountName(lastFour: account.customer.cardLast4)
        return Balance(date: Date(), accountName: accountName, amount: amount)
    }

    /// Maps activities to transactions
    /// - Parameter activities: Activities to map
    /// - Throws: RogersBankMappingError
    /// - Returns: Transactions
    public func mapActivitiesToTransactions(activities: [Activity]) throws -> [Transaction] {
        var transactions = [Transaction]()
        for activity in activities {
            guard activity.activityStatus == .approved && activity.activityType == .transaction else {
                continue
            }
            guard let postedDate = activity.postedDate else {
                throw RogersBankMappingError.missingActivityData(activity: activity, key: "postedDate")
            }
            let referenceNumber: String
            if activity.activityCategory == .payment {
                referenceNumber = "payment-\(Self.dateFormatter.string(from: postedDate))"
            } else {
                guard let number = activity.referenceNumber else {
                    throw RogersBankMappingError.missingActivityData(activity: activity, key: "referenceNumber")
                }
                referenceNumber = number
            }
            let accountName = try ledgerAccountName(lastFour: String(activity.cardNumber.suffix(4)))

            let metaData = TransactionMetaData(date: postedDate, payee: activity.merchant.name, metaData: [MetaDataKeys.activityId: referenceNumber])
            let (number, decimalDigits) = activity.amount.value.amountDecimal()
            let amount = Amount(number: number, commoditySymbol: activity.amount.currency, decimalDigits: decimalDigits)
            let negatedAmount = Amount(number: -number, commoditySymbol: activity.amount.currency, decimalDigits: decimalDigits)
            var postings = [Posting(accountName: accountName, amount: negatedAmount)]
            if let foreign = activity.foreign {
                let (number, decimalDigits) = foreign.originalAmount.value.amountDecimal()
                let foreignAmount = Amount(number: number, commoditySymbol: foreign.originalAmount.currency, decimalDigits: decimalDigits)
                postings.append(Posting(accountName: expenseAccountName, amount: foreignAmount, price: amount))
            } else {
                postings.append(Posting(accountName: expenseAccountName, amount: amount))
            }
            transactions.append(Transaction(metaData: metaData, postings: postings))
        }
        return transactions
    }

    private func ledgerAccountName(lastFour: String) throws -> AccountName {
        guard let accountName = ledger.accounts.first(where: { $0.name.accountType == .liability && $0.metaData[MetaDataKeys.account] == lastFour })?.name else {
            throw RogersBankMappingError.missingAccount(lastFour: lastFour)
        }
        return accountName
    }

}
