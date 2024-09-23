import CSV
import Foundation
import SwiftBeanCountModel
import SwiftBeanCountParserUtils

/// Mapper to map downloaded accounts and transactions to BeanCoutModel objects
public struct SwiftBeanCountCompassCardMapper {

    private struct TransactionRow: Decodable {
        let date: Date
        let transaction: String
        let amount: String
        let journeyId: String?
        let orderNumber: Int?

        private enum CodingKeys: String, CodingKey { // swiftlint:disable:this nesting
            case date = "DateTime"
            case transaction = "Transaction"
            case amount = "Amount"
            case journeyId = "JourneyId"
            case orderNumber = "OrderNumber"
        }
    }

    private enum MetaDataKey {
        static let importerType = "importer-type"
        static let importerTypeValue = "compass-card"
        static let cardNumber = "card-number"
        static let journeyId = "journey-id"
        static let expense = "compass-card-expense"
        static let load = "compass-card-load"
    }

    private static var dateFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM-dd-yyyy hh:mm a"
        dateFormatter.timeZone = TimeZone(abbreviation: "PST")
        return dateFormatter
    }()

    private static var dateFormatterLoadId: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm"
        dateFormatter.timeZone = TimeZone(abbreviation: "PST")
        return dateFormatter
    }()

    /// AccountName for the other leg of a transaction
    public let defaultExpenseAccountName = try! AccountName("Expenses:TODO") // swiftlint:disable:this force_try
    /// AccountName for the other leg of a load transaction
    public let defaultAssetAccountName = try! AccountName("Assets:TODO") // swiftlint:disable:this force_try

    /// String in CSV
    private let autoLoadTransaction = "AutoLoaded"
    /// String in CSV
    private let webLoadTransactions = "Web Order"
    /// String in CSV
    private let loadTransaction = "Loaded at"
    /// Strings in CSV
    private let removeTransactionDescriptions = ["Tap in at", "Tap out at", "Transfer at", "Stn"]

    private let payee = "TransLink"
    private let commodity = "CAD"

    private let ledger: Ledger

    /// Creates a mapper
    /// - Parameter ledger: Ledger which will be used to look up things like account names
    public init(ledger: Ledger) {
        self.ledger = ledger
    }

    /// Creates a balance assertions from the downloaded string
    /// - Parameters:
    ///   - cardNumber: String with the compass card number
    ///   - balance: String with the balance
    ///   - date: Date to balance assertion should use, if nil defaults to tomorrow
    /// - Returns: Array of Balances
    public func createBalance(cardNumber: String, balance: String, date inputDate: Date? = nil) throws -> Balance {
        let date = inputDate ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let number = cardNumber.components(separatedBy: .whitespacesAndNewlines).joined()
        let balanceString = balance.replacingOccurrences(of: "$", with: "").components(separatedBy: .whitespacesAndNewlines).joined()
        let (decimal, _) = balanceString.amountDecimal()
        let amount = Amount(number: decimal, commoditySymbol: commodity, decimalDigits: 2)
        return try Balance(date: date, accountName: ledgerCardAccountName(cardNumber: number), amount: amount)
    }

    /// Creates Transactions from the downloaded CSV String
    ///
    /// Note: This method filters out transactions already existing in the ledger
    ///
    /// - Parameters:
    ///   - cardNumber: String with the compass card number
    ///   - transactions: String of the transaction CSV
    /// - Returns: Array of transactions
    public func createTransactions(cardNumber: String, transactions: String) throws -> [Transaction] {
        let account = try ledgerCardAccountName(cardNumber: cardNumber)
        let reader = try CSVReader(string: transactions, hasHeaderRow: true)
        return try createTransactions(getRows(reader), cardNumber: cardNumber, account: account)
    }

    /// Creates Transactions from a provided CSVReader
    ///
    /// Note: This method filters out transactions already existing in the ledger
    ///
    /// - Parameters:
    ///   - account: AccountName of asset account in the ledger
    ///   - reader: CSVReader with the transaction CSV
    /// - Returns: Array of transactions
    public func createTransactions(account: AccountName, reader: CSVReader) throws -> [Transaction] {
        try createTransactions(getRows(reader), cardNumber: nil, account: account)
    }

    /// Gets the correct account for the Compass Card from the ledger based on the card number
    /// - Parameter cardNumber: Compass Card Number
    /// - Returns: AccountName from the ledger
    public func ledgerCardAccountName(cardNumber: String) throws -> AccountName {
        guard let accountName = ledger.accounts.first(where: {
            $0.metaData[MetaDataKey.importerType] == MetaDataKey.importerTypeValue && $0.metaData[MetaDataKey.cardNumber] == cardNumber
        })?.name else {
            throw SwiftBeanCountCompassCardMapperError.missingAccount(cardNumber: cardNumber)
        }
        return accountName
    }

    private func getRows(_ reader: CSVReader) throws -> [TransactionRow] {
        var rows = [TransactionRow]()
        let decoder = CSVRowDecoder()
        decoder.dateDecodingStrategy = .formatted(Self.dateFormatter)
        while reader.next() != nil {
            let row = try decoder.decode(TransactionRow.self, from: reader)
            rows.append(row)
        }
        return rows
    }

    // swiftlint:disable:next function_body_length
    private func createTransactions(_ transactions: [TransactionRow], cardNumber: String?, account: AccountName) throws -> [Transaction] {
        var result = [Transaction]()

        var currentJourney = ""
        var currentTransactions = [TransactionRow](), currentLoad = [TransactionRow]()

        for transaction in transactions {
            if transaction.transaction == autoLoadTransaction || transaction.transaction.contains(webLoadTransactions) {
                if transaction.transaction.contains(webLoadTransactions), let activeLoad = currentLoad.first, activeLoad.amount == transaction.amount {
                    // Web transactions are loaded when tapping the next time.
                    // This creates a second entry. Ignoring it here.
                    currentLoad = []
                }
                result.append(createLoadTransaction(transaction, cardNumber: cardNumber, account: account))
            } else if transaction.transaction.contains(loadTransaction) {
                if let activeLoad = currentLoad.first {
                    result.append(createLoadTransaction(activeLoad, cardNumber: cardNumber, account: account))
                }
                currentLoad = [transaction]
            } else {
                if currentJourney == transaction.journeyId {
                    currentTransactions.append(transaction)
                } else {
                    if !currentTransactions.isEmpty {
                        if let transaction = createTransaction(currentTransactions, cardNumber: cardNumber, account: account) {
                            result.append(transaction)
                        }
                    }
                    currentJourney = transaction.journeyId ?? ""
                    currentTransactions = [transaction]
                }
            }
        }
        if !currentTransactions.isEmpty, let transaction = createTransaction(currentTransactions, cardNumber: cardNumber, account: account) {
            result.append(transaction)
        }
        if let activeLoad = currentLoad.first {
            result.append(createLoadTransaction(activeLoad, cardNumber: cardNumber, account: account))
        }

        return result.filter { !doesTransactionExistInLedger($0.metaData.metaData["journey-id"] ?? "") }
    }

    private func createTransaction(_ transactions: [TransactionRow], cardNumber: String?, account: AccountName) -> Transaction? {
        var transactionRows = transactions
        transactionRows.sort { $0.date < $1.date }

        var amount: MultiCurrencyAmount = Amount(number: Decimal(), commoditySymbol: commodity, decimalDigits: 2).multiCurrencyAmount
        var narration = ""

        for transaction in transactionRows {
            let balanceString = transaction.amount.replacingOccurrences(of: "$", with: "").components(separatedBy: .whitespacesAndNewlines).joined()
            let (decimal, _) = balanceString.amountDecimal()
            amount += Amount(number: decimal, commoditySymbol: commodity, decimalDigits: 2)
            let stop = removeTransactionDescriptions.reduce(transaction.transaction) {
                $0.replacingOccurrences(of: $1, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if narration.isEmpty {
                narration = stop
            } else if !narration.hasSuffix(" -> \(stop)") {
                narration.append(contentsOf: " -> \(stop)")
            }
        }

        if amount.amountFor(symbol: commodity).number == Decimal() {
            return nil
        }

        let expenseAccount = ledgerExpenseAccountName(cardNumber: cardNumber)
        let posting = Posting(accountName: account, amount: amount.amountFor(symbol: commodity))
        let posting2 = Posting(accountName: expenseAccount, amount: Amount(number: -amount.amountFor(symbol: commodity).number, commoditySymbol: commodity, decimalDigits: 2))
        let id = transactions.first!.journeyId!
        let metaData = TransactionMetaData(date: transactions.first!.date, payee: payee, narration: narration, metaData: [MetaDataKey.journeyId: id])
        return Transaction(metaData: metaData, postings: [posting, posting2])
    }

    private func createLoadTransaction(_ transaction: TransactionRow, cardNumber: String?, account: AccountName) -> Transaction {
        let expenseAccount = ledgerLoadAccountName(cardNumber: cardNumber)
        let balanceString = transaction.amount.replacingOccurrences(of: "$", with: "").components(separatedBy: .whitespacesAndNewlines).joined()
        let (decimal, _) = balanceString.amountDecimal()
        let posting = Posting(accountName: account, amount: Amount(number: decimal, commoditySymbol: commodity, decimalDigits: 2))
        let posting2 = Posting(accountName: expenseAccount, amount: Amount(number: -decimal, commoditySymbol: commodity, decimalDigits: 2))
        let id = "\(MetaDataKey.load)-\(transaction.orderNumber.flatMap(String.init) ?? Self.dateFormatterLoadId.string(from: transaction.date))"
        let metaData = TransactionMetaData(date: transaction.date, narration: "", metaData: [MetaDataKey.journeyId: id])
        return Transaction(metaData: metaData, postings: [posting, posting2])
    }

    /// Gets the correct account from the ledger for an expense based on the card number
    /// - Parameter cardNumber: Compass Card Number
    /// - Returns: AccountName from the ledger, or fallback if not found
    private func ledgerExpenseAccountName(cardNumber: String?) -> AccountName {
        guard let cardNumber else {
            return defaultExpenseAccountName
        }
        guard let accountName = ledger.accounts.first(where: {
            $0.metaData[MetaDataKey.expense]?.contains(cardNumber) ?? false
        })?.name else {
            return defaultExpenseAccountName
        }
        return accountName
    }

    /// Gets the correct account from the ledger for a load of the card, based on the card number
    /// - Parameter cardNumber: Compass Card Number
    /// - Returns: AccountName from the ledger, or fallback if not found
    private func ledgerLoadAccountName(cardNumber: String?) -> AccountName {
        guard let cardNumber else {
            return defaultAssetAccountName
        }
        guard let accountName = ledger.accounts.first(where: {
            $0.metaData[MetaDataKey.load]?.contains(cardNumber) ?? false
        })?.name else {
            return defaultAssetAccountName
        }
        return accountName
    }

    /// Checks if a transaction is already in the ledger
    /// - Parameter journeyId: journeyId of the transaction to check
    /// - Returns: if the transaction with this id is already in the ledger
    private func doesTransactionExistInLedger(_ journeyId: String) -> Bool {
        ledger.transactions.contains { $0.metaData.metaData[MetaDataKey.journeyId]?.contains(journeyId) ?? false }
    }

}
