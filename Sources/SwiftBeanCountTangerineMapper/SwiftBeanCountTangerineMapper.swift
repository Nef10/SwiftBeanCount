import Foundation
import SwiftBeanCountModel
import SwiftBeanCountParserUtils

/// Mapper to map downloaded accounts and transactions to BeanCoutModel objects
public struct SwiftBeanCountTangerineMapper {

    enum MetaDataKey {
        static let importerType = "importer-type"
        static let cardImporter = "tangerine-card"
        static let accountImporter = "tangerine-account"
        static let lastFour = "last-four"
        static let number = "number"
        static let id = "tangerine-id"
        static let rewards = "tangerine-rewards"
        static let interest = "tangerine-interest"
    }

    private static var dateFormatterTransaction: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return dateFormatter
    }()

    /// AccountName for the other leg of the transaction
    public let defaultAccountName = try! AccountName("Expenses:TODO") // swiftlint:disable:this force_try

    private let fallbackCommodity = "CAD"

    private let ledger: Ledger

    /// Creates a mapper
    /// - Parameter ledger: Ledger which will be used to look up things like account names
    public init(ledger: Ledger) {
        self.ledger = ledger
    }

    /// Creates balance assertions from the downloaded account JSON
    /// - Parameters:
    ///   - accounts: JSONs downloaded from the Tangerine API
    ///   - date: Date to balance assertion should use, defaults to the current date
    /// - Returns: Array of Balances
    public func createBalances(accounts: [[String: Any]], date: Date = Date()) throws -> [Balance] {
        try accounts.map {
            var (decimal, _) = (String($0["account_balance"] as? Double ?? 0)).amountDecimal()
            if $0["type"] as? String == "CREDIT_CARD" || $0["type"] as? String == "LOAN" {
                decimal.negate()
            }
            let amount = Amount(number: decimal, commoditySymbol: try $0["currency_type"] as? String ?? commoditySymbol(for: ledgerAccountName(account: $0)), decimalDigits: 2)
            return try Balance(date: date, accountName: ledgerAccountName(account: $0), amount: amount)
        }
    }

    /// Creates Transactions from JSON objects downloaded from the API
    ///
    /// Note: This method filters out transactions already existing in the ledger, so the
    ///       count of the input and output arrays might be different
    ///
    /// - Parameter rawTransactions: Array of JSON objects
    /// - Returns: Array of transactions
    public func createTransactions(_ rawTransactions: [String: [[String: Any]]]) throws -> [Transaction] {
        try rawTransactions.flatMap { accountName, transactions in
            try createTransactions(transactions, for: accountName)
        }
    }

    /// Gets the correct account from the ledger based on the downloaded account JSON
    /// - Parameter account: JSON from the API
    /// - Returns: AccountName from the ledger
    public func ledgerAccountName(account: [String: Any]) throws -> AccountName {
        var type: AccountType
        var importerType: String
        var metaDataKey: String
        var metaDataValue: String
        switch account["type"] as? String {
        case "CREDIT_CARD":
            type = .liability
            importerType = MetaDataKey.cardImporter
            metaDataKey = MetaDataKey.lastFour
            metaDataValue = String((account["display_name"] as? String)?.suffix(4) ?? "")
        case "LOAN":
            type = .liability
            importerType = MetaDataKey.accountImporter
            metaDataKey = MetaDataKey.number
            metaDataValue = account["display_name"] as? String ?? ""
        default:
            type = .asset
            importerType = MetaDataKey.accountImporter
            metaDataKey = MetaDataKey.number
            metaDataValue = account["display_name"] as? String ?? ""
        }

        guard let accountName = ledger.accounts.first(where: {
            $0.name.accountType == type && $0.metaData[metaDataKey] == metaDataValue && $0.metaData[MetaDataKey.importerType] == importerType
        })?.name else {
            throw SwiftBeanCountTangerineMapperError.missingAccount(account: String(describing: account))
        }
        return accountName
    }

    private func createTransactions(_ transactions: [[String: Any]], for accountName: String) throws -> [Transaction] {
        try transactions.compactMap { (json: [String: Any]) -> Transaction? in
            guard !doesTransactionExistInLedger(json) else {
                return nil
            }
            guard let date = Self.dateFormatterTransaction.date(from: json["posted_date"] as? String ?? "") else {
                throw SwiftBeanCountTangerineMapperError.invalidDate(date: json["posted_date"] as? String ?? "")
            }
            let accountName = try AccountName(accountName)

            var description = json["description"] as? String ?? ""
            let (decimal, _) = (String(json["amount"] as? Double ?? 0)).amountDecimal()
            var otherAccountName = defaultAccountName
            var payee = ""
            if json["type"] as? String == "CC_RE" || json["type"] as? String == "INTEREST" {
                payee = "Tangerine"
                if json["type"] as? String == "CC_RE" {
                    otherAccountName = account(type: MetaDataKey.rewards, for: accountName)
                    description = ""
                } else {
                    otherAccountName = account(type: MetaDataKey.interest, for: accountName)
                    if description == "Interest Paid" {
                        description = ""
                    }
                }
            }
            let posting = Posting(accountName: accountName, amount: Amount(number: decimal, commoditySymbol: commoditySymbol(for: accountName), decimalDigits: 2))
            let posting2 = Posting(accountName: otherAccountName, amount: Amount(number: -decimal, commoditySymbol: commoditySymbol(for: accountName), decimalDigits: 2))
            let metaData = TransactionMetaData(date: date, payee: payee, narration: description, metaData: [MetaDataKey.id: String(json["id"] as? Int ?? 0)])
            return Transaction(metaData: metaData, postings: [posting, posting2])
        }
    }

    private func account(type: String, for account: AccountName) -> AccountName {
        guard let accountNumber = ledger.accounts.first(where: { $0.name == account })?.metaData[MetaDataKey.number] else {
            return defaultAccountName
        }
        return ledger.accounts.first { $0.metaData[type]?.contains(accountNumber) ?? false }?.name ?? defaultAccountName
    }

    private func commoditySymbol(for account: AccountName) -> CommoditySymbol {
        ledger.accounts.first { $0.name == account }?.commoditySymbol ?? fallbackCommodity
    }

    private func doesTransactionExistInLedger(_ transaction: [String: Any]) -> Bool {
        ledger.transactions.contains { $0.metaData.metaData[MetaDataKey.id]?.contains(String(transaction["id"] as? Int ?? 0)) ?? false }
    }

}
