import SwiftBeanCountModel
@testable import SwiftBeanCountTangerineMapper
import XCTest

final class SwiftBeanCountTangerineMapperTests: XCTestCase {

    private let creditCard: [String: Any] = ["type": "CREDIT_CARD", "account_balance": 10.50, "currency_type": "CAD", "display_name": "1234 XXXX YYYY 1583"]
    private let chequing: [String: Any] = ["type": "CHEQUING", "display_name": "123456", "account_balance": 150.30]
    private let loan: [String: Any] = ["type": "LOAN", "account_balance": 15.25, "currency_type": "EUR", "display_name": "654321"]
    private let savings: [String: Any] = ["type": "SAVINGS", "display_name": "9876543", "account_balance": 19.10]

    private let mapper = SwiftBeanCountTangerineMapper(ledger: Ledger())

    func testDefaultAccountName() throws {
        XCTAssertEqual(mapper.defaultAccountName, try AccountName("Expenses:TODO"))
    }

    func testCreateBalances() throws {
        let accounts = [creditCard, chequing, loan, savings, ["type": "SAVINGS", "display_name": "1001"]]
        let ledger = Ledger()
        let date = Date()
        let creditCardAccountName = try AccountName("Liabilities:CreditCard:Tangerine")
        try ledger.add(Account(name: creditCardAccountName, metaData: ["last-four": "1583", "importer-type": "tangerine-card"]))
        let checkingAccountName = try AccountName("Assets:Checking:Tangerine")
        try ledger.add(Account(name: checkingAccountName, metaData: ["number": "123456", "importer-type": "tangerine-account"]))
        let loanAccountName = try AccountName("Liabilities:LOC:Tangerine")
        try ledger.add(Account(name: loanAccountName, metaData: ["number": "654321", "importer-type": "tangerine-account"]))
        let savingsAccountName = try AccountName("Assets:Savings:Tangerine")
        try ledger.add(Account(name: savingsAccountName, commoditySymbol: "USD", metaData: ["number": "9876543", "importer-type": "tangerine-account"]))
        let emptyAccountName = try AccountName("Assets:Savings:Tangerine2")
        try ledger.add(Account(name: emptyAccountName, metaData: ["number": "1001", "importer-type": "tangerine-account"]))
        let mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        let result = try mapper.createBalances(accounts: accounts, date: date)
        XCTAssertEqual(result.count, 5)
        var amount = Amount(number: Decimal(-10.50), commoditySymbol: "CAD", decimalDigits: 2)
        XCTAssertEqual(result[0], Balance(date: date, accountName: creditCardAccountName, amount: amount))
        amount = Amount(number: Decimal(150.30), commoditySymbol: "CAD", decimalDigits: 2) // fallback currency
        XCTAssertEqual(result[1], Balance(date: date, accountName: checkingAccountName, amount: amount))
        amount = Amount(number: Decimal(-15.25), commoditySymbol: "EUR", decimalDigits: 2)
        XCTAssertEqual(result[2], Balance(date: date, accountName: loanAccountName, amount: amount))
        amount = Amount(number: Decimal(19.10), commoditySymbol: "USD", decimalDigits: 2) // account currency
        XCTAssertEqual(result[3], Balance(date: date, accountName: savingsAccountName, amount: amount))
        amount = Amount(number: Decimal(0.00), commoditySymbol: "CAD", decimalDigits: 2) // no amount in JSON
        XCTAssertEqual(result[4], Balance(date: date, accountName: emptyAccountName, amount: amount))
    }

    func testCreateBalancesExceptions() {
        // No account
        XCTAssertThrowsError(try mapper.createBalances(accounts: [creditCard])) {
             assertAccountNotFound(thrownError: $0, account: creditCard)
        }
        // Invalid Date
        XCTAssertThrowsError(try mapper.createTransactions(["Assets:Checking": [["posted_date": "2022-10-99T10:10:10"]]])) {
            XCTAssertEqual($0 as? SwiftBeanCountTangerineMapperError, .invalidDate(date: "2022-10-99T10:10:10"))
        }
        // No Date
        XCTAssertThrowsError(try mapper.createTransactions(["Assets:Checking": [["a": "b"]]])) {
            XCTAssertEqual($0 as? SwiftBeanCountTangerineMapperError, .invalidDate(date: ""))
        }
        // Invalid Account Name
        XCTAssertThrowsError(try mapper.createTransactions( ["InvalidName": [["posted_date": "2022-10-10T10:10:10"]]])) {
            if case let AccountNameError.invaildName(name) = $0 {
                XCTAssertEqual(name, "InvalidName")
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    func testCreateTransactionsAlreadyExists() throws {
        let transactions = [ "account": [["id": 12_345]]]
        let ledger = Ledger()
        let posting = Posting(accountName: try AccountName("Assets:Checking"), amount: Amount(number: Decimal(1), commoditySymbol: "CAD", decimalDigits: 2))
        let posting2 = Posting(accountName: try AccountName("Assets:Savings"), amount: Amount(number: Decimal(-1), commoditySymbol: "CAD", decimalDigits: 2))
        let metaData = TransactionMetaData(date: Date(), narration: "description", metaData: ["tangerine-id": "12345"])
        let transaction = Transaction(metaData: metaData, postings: [posting, posting2])
        let metaData2 = TransactionMetaData(date: Date(), narration: "description")
        let transaction2 = Transaction(metaData: metaData2, postings: [posting, posting2])
        ledger.add(transaction2)
        ledger.add(transaction)
        let mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        XCTAssert(try mapper.createTransactions(transactions).isEmpty)
    }

    func testCreateTransactions() throws {
        let transactions = ["Assets:Checking": [["posted_date": "2022-10-10T10:10:10", "description": "ABC", "amount": 10.50]]]
        let result = try mapper.createTransactions(transactions)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].description, """
        2022-10-10 * "" "ABC"
          tangerine-id: "0"
          Assets:Checking 10.50 CAD
          Expenses:TODO -10.50 CAD
        """)
    }

    func testCreateTransactionsCommoditySymbol() throws {
        let transactions = [ "Assets:Checking": [["posted_date": "2022-10-10T10:10:10", "description": "ABC", "amount": 10.50]]]
        let ledger = Ledger()
        try ledger.add(Account(name: try AccountName("Assets:Checking"), commoditySymbol: "USD"))
        let mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        let result = try mapper.createTransactions(transactions)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].description, """
        2022-10-10 * "" "ABC"
          tangerine-id: "0"
          Assets:Checking 10.50 USD
          Expenses:TODO -10.50 USD
        """)
    }

    func testCreateTransactionsEmpty() throws {
        let transactions = [ "Assets:Checking": [["posted_date": "2022-10-10T10:10:10"]]]
        let ledger = Ledger()
        let posting = Posting(accountName: try AccountName("Assets:Checking"), amount: Amount(number: Decimal(1), commoditySymbol: "CAD", decimalDigits: 2))
        let posting2 = Posting(accountName: try AccountName("Assets:Savings"), amount: Amount(number: Decimal(-1), commoditySymbol: "CAD", decimalDigits: 2))
        let metaData = TransactionMetaData(date: Date(), narration: "description", metaData: ["tangerine-id": "12345"])
        let transaction = Transaction(metaData: metaData, postings: [posting, posting2])
        ledger.add(transaction)

        let mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        let result = try mapper.createTransactions(transactions)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].description, """
        2022-10-10 * "" ""
          tangerine-id: "0"
          Assets:Checking 0.00 CAD
          Expenses:TODO 0.00 CAD
        """)
    }

    func testLedgerAccountNameEmptyDict() {
        XCTAssertThrowsError(try mapper.ledgerAccountName(account: [:])) {
             assertAccountNotFound(thrownError: $0, account: [:])
        }
    }

    func testLedgerAccountNameCreditCard() throws {
        // No Account
        var mapper = SwiftBeanCountTangerineMapper(ledger: Ledger())
        XCTAssertThrowsError(try mapper.ledgerAccountName(account: creditCard)) {
             assertAccountNotFound(thrownError: $0, account: creditCard)
        }

        // Asset instead of Liability
        let ledger = Ledger()
        try ledger.add(Account(name: try AccountName("Assets:CreditCard:Tangerine"), metaData: ["last-four": "1583", "importer-type": "tangerine-card"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        XCTAssertThrowsError(try mapper.ledgerAccountName(account: creditCard)) {
             assertAccountNotFound(thrownError: $0, account: creditCard)
        }

        // Wrong last four
        try ledger.add(Account(name: try AccountName("Liabilities:CreditCard:Tangerine2"), metaData: ["last-four": "1585", "importer-type": "tangerine-card"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        XCTAssertThrowsError(try mapper.ledgerAccountName(account: creditCard)) {
             assertAccountNotFound(thrownError: $0, account: creditCard)
        }

        // No importer type
        try ledger.add(Account(name: try AccountName("Liabilities:CreditCard:Tangerine3"), metaData: ["last-four": "1583"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        XCTAssertThrowsError(try mapper.ledgerAccountName(account: creditCard)) {
             assertAccountNotFound(thrownError: $0, account: creditCard)
        }

        let accountName = try AccountName("Liabilities:CreditCard:Tangerine")
        try ledger.add(Account(name: accountName, metaData: ["last-four": "1583", "importer-type": "tangerine-card"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        XCTAssertEqual(try mapper.ledgerAccountName(account: creditCard), accountName)
    }

    func testLedgerAccountNameLoan() throws {
        // No Account
        XCTAssertThrowsError(try mapper.ledgerAccountName(account: loan)) {
             assertAccountNotFound(thrownError: $0, account: loan)
        }

        // Asset instead of Liability
        let ledger = Ledger()
        try ledger.add(Account(name: try AccountName("Assets:LOC:Tangerine"), metaData: ["number": "654321", "importer-type": "tangerine-account"]))
        var mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        XCTAssertThrowsError(try mapper.ledgerAccountName(account: loan)) {
             assertAccountNotFound(thrownError: $0, account: loan)
        }

        // Wrong number
        try ledger.add(Account(name: try AccountName("Liabilities:LOC:Tangerine2"), metaData: ["number": "654322", "importer-type": "tangerine-account"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        XCTAssertThrowsError(try mapper.ledgerAccountName(account: loan)) {
             assertAccountNotFound(thrownError: $0, account: loan)
        }

        // No importer type
        try ledger.add(Account(name: try AccountName("Liabilities:LOC:Tangerine3"), metaData: ["number": "654321"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        XCTAssertThrowsError(try mapper.ledgerAccountName(account: loan)) {
             assertAccountNotFound(thrownError: $0, account: loan)
        }

        let accountName = try AccountName("Liabilities:LOC:Tangerine")
        try ledger.add(Account(name: accountName, metaData: ["number": "654321", "importer-type": "tangerine-account"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        XCTAssertEqual(try mapper.ledgerAccountName(account: loan), accountName)
    }

    func testLedgerAccountNameChequing() throws {
        // No Account
        XCTAssertThrowsError(try mapper.ledgerAccountName(account: chequing)) {
             assertAccountNotFound(thrownError: $0, account: chequing)
        }

        // Liability instead of Asset
        let ledger = Ledger()
        try ledger.add(Account(name: try AccountName("Liabilities:Checking:Tangerine"), metaData: ["number": "123456", "importer-type": "tangerine-account"]))
        var mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        XCTAssertThrowsError(try mapper.ledgerAccountName(account: chequing)) {
             assertAccountNotFound(thrownError: $0, account: chequing)
        }

        // Wrong number
        try ledger.add(Account(name: try AccountName("Assets:Checking:Tangerine2"), metaData: ["number": "1234567", "importer-type": "tangerine-account"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        XCTAssertThrowsError(try mapper.ledgerAccountName(account: chequing)) {
             assertAccountNotFound(thrownError: $0, account: chequing)
        }

        // No importer type
        try ledger.add(Account(name: try AccountName("Assets:Checking:Tangerine3"), metaData: ["number": "123456"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        XCTAssertThrowsError(try mapper.ledgerAccountName(account: chequing)) {
             assertAccountNotFound(thrownError: $0, account: chequing)
        }

        let accountName = try AccountName("Assets:Checking:Tangerine")
        try ledger.add(Account(name: accountName, metaData: ["number": "123456", "importer-type": "tangerine-account"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        XCTAssertEqual(try mapper.ledgerAccountName(account: chequing), accountName)
    }

    func testLedgerAccountNameSavings() throws {
        // No Account
        XCTAssertThrowsError(try mapper.ledgerAccountName(account: savings)) {
             assertAccountNotFound(thrownError: $0, account: savings)
        }

        // Liability instead of Asset
        let ledger = Ledger()
        try ledger.add(Account(name: try AccountName("Liabilities:Savings:Tangerine"), metaData: ["number": "9876543", "importer-type": "tangerine-account"]))
        var mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        XCTAssertThrowsError(try mapper.ledgerAccountName(account: savings)) {
             assertAccountNotFound(thrownError: $0, account: savings)
        }

        // Wrong number
        try ledger.add(Account(name: try AccountName("Assets:Savings:Tangerine2"), metaData: ["number": "98765433", "importer-type": "tangerine-account"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        XCTAssertThrowsError(try mapper.ledgerAccountName(account: savings)) {
             assertAccountNotFound(thrownError: $0, account: savings)
        }

        // No importer type
        try ledger.add(Account(name: try AccountName("Assets:Savings:Tangerine3"), metaData: ["number": "9876543"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        XCTAssertThrowsError(try mapper.ledgerAccountName(account: savings)) {
             assertAccountNotFound(thrownError: $0, account: savings)
        }

        let accountName = try AccountName("Assets:Savings:Tangerine")
        try ledger.add(Account(name: accountName, metaData: ["number": "9876543", "importer-type": "tangerine-account"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        XCTAssertEqual(try mapper.ledgerAccountName(account: savings), accountName)
    }

    private func assertAccountNotFound(thrownError: Error, account: [String: Any]) {
        guard let error = thrownError as? SwiftBeanCountTangerineMapperError else {
            XCTFail("Unexpected error type, got \(type(of: thrownError)) instead of \(SwiftBeanCountTangerineMapperError.self)")
            return
        }
        switch error {
        case let .missingAccount(missingAccount):
            for (key, value) in account {
                if let value = value as? String {
                    XCTAssert(missingAccount.contains("\"\(key)\": \"\(value)\""))
                } else {
                    XCTAssert(missingAccount.contains("\"\(key)\": \(value)"))
                }
            }
        default:
            XCTFail("Wrong error type")
        }
    }

}
