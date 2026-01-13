import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountTangerineMapper
import Testing

@Suite
struct SwiftBeanCountTangerineMapperTests { // swiftlint:disable:this type_body_length

    private let creditCard: [String: Any] = ["type": "CREDIT_CARD", "account_balance": 10.50, "currency_type": "CAD", "display_name": "1234 XXXX YYYY 1583"]
    private let chequing: [String: Any] = ["type": "CHEQUING", "display_name": "123456", "account_balance": 150.30]
    private let loan: [String: Any] = ["type": "LOAN", "account_balance": 15.25, "currency_type": "EUR", "display_name": "654321"]
    private let savings: [String: Any] = ["type": "SAVINGS", "display_name": "9876543", "account_balance": 19.10]

    @Test
    func defaultAccountName() throws {
        let mapper = SwiftBeanCountTangerineMapper(ledger: Ledger())
        #expect(try AccountName("Expenses:TODO") == mapper.defaultAccountName)
    }

    @Test
    func createBalances() throws {
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
        #expect(result.count == 5)
        var amount = Amount(number: Decimal(-10.50), commoditySymbol: "CAD", decimalDigits: 2)
        #expect(result[0] == Balance(date: date, accountName: creditCardAccountName, amount: amount))
        amount = Amount(number: Decimal(150.30), commoditySymbol: "CAD", decimalDigits: 2) // fallback currency
        #expect(result[1] == Balance(date: date, accountName: checkingAccountName, amount: amount))
        amount = Amount(number: Decimal(-15.25), commoditySymbol: "EUR", decimalDigits: 2)
        #expect(result[2] == Balance(date: date, accountName: loanAccountName, amount: amount))
        amount = Amount(number: Decimal(19.10), commoditySymbol: "USD", decimalDigits: 2) // account currency
        #expect(result[3] == Balance(date: date, accountName: savingsAccountName, amount: amount))
        amount = Amount(number: Decimal(0.00), commoditySymbol: "CAD", decimalDigits: 2) // no amount in JSON
        #expect(result[4] == Balance(date: date, accountName: emptyAccountName, amount: amount))
    }

    @Test
    func createBalancesExceptions() {
        let mapper = SwiftBeanCountTangerineMapper(ledger: Ledger())

        // No account
        var error = #expect(throws: (any Error).self) { try mapper.createBalances(accounts: [creditCard]) }
        expectAccountNotFound(thrownError: error, account: creditCard)

        // Invalid Date
        error = #expect(throws: (any Error).self) { try mapper.createTransactions(["Assets:Checking": [["posted_date": "2022-10-99T10:10:10"]]]) }
        #expect(error as? SwiftBeanCountTangerineMapperError == .invalidDate(date: "2022-10-99T10:10:10"))

        // No Date
        error = #expect(throws: (any Error).self) { try mapper.createTransactions(["Assets:Checking": [["a": "b"]]]) }
        #expect(error as? SwiftBeanCountTangerineMapperError == .invalidDate(date: ""))

        // Invalid Account Name
        error = #expect(throws: (any Error).self) { try mapper.createTransactions( ["InvalidName": [["posted_date": "2022-10-10T10:10:10"]]]) }
        if let error, let accountNameError = error as? AccountNameError {
            if case let AccountNameError.invalidName(name) = accountNameError {
                #expect(name == "InvalidName")
            } else {
                Issue.record("Wrong AccountNameError type: \(accountNameError)")
            }
        } else {
            Issue.record("Wrong error type or no error: \(String(describing: error))")
        }
    }

    @Test
    func createTransactionsAlreadyExists() throws {
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
        #expect(try mapper.createTransactions(transactions).isEmpty)
    }

    @Test
    func createTransactions() throws {
        let mapper = SwiftBeanCountTangerineMapper(ledger: Ledger())
        let transactions = ["Assets:Checking": [["posted_date": "2022-10-10T10:10:10", "description": "ABC", "amount": 10.50] as [String: Any]]]
        let result = try mapper.createTransactions(transactions)
        #expect(result.count == 1)
        #expect(result[0].description == """
        2022-10-10 * "" "ABC"
          tangerine-id: "0"
          Assets:Checking 10.50 CAD
          Expenses:TODO -10.50 CAD
        """)
    }

    @Test
    func createTransactionCreditCardRewardNotSetup() throws {
        let mapper = SwiftBeanCountTangerineMapper(ledger: Ledger())
        let transactions: [String: [[String: Any]]] =
            ["Assets:Savings:Tangerine": [["id": 852_254, "posted_date": "2022-10-10T10:10:10", "description": "ABC", "amount": 10.50, "type": "CC_RE"] as [String: Any]]]
        let result = try mapper.createTransactions(transactions)
        #expect(result.count == 1)
        #expect(result[0].description == """
        2022-10-10 * "Tangerine" ""
          tangerine-id: "852254"
          Assets:Savings:Tangerine 10.50 CAD
          Expenses:TODO -10.50 CAD
        """)
    }

    @Test
    func createTransactionCreditCardReward() throws {
        let ledger = Ledger()
        let accountName1 = try AccountName("Assets:Savings:Tangerine")
        try ledger.add(Account(name: accountName1, metaData: ["number": "1001"]))
        let accountName2 = try AccountName("Income:CashBack:Tangerine")
        try ledger.add(Account(name: accountName2, metaData: ["tangerine-rewards": "1001"]))
        let accountName3 = try AccountName("Income:CashBack:Tangerine1")
        try ledger.add(Account(name: accountName3, metaData: ["tangerine-rewards": "1002"]))
        let mapper = SwiftBeanCountTangerineMapper(ledger: ledger)

        let transactions: [String: [[String: Any]]] =
            ["Assets:Savings:Tangerine": [["id": 852_254, "posted_date": "2022-10-10T10:10:10", "description": "ABC", "amount": 10.50, "type": "CC_RE"] as [String: Any]]]
        let result = try mapper.createTransactions(transactions)
        #expect(result.count == 1)
        #expect(result[0].description == """
        2022-10-10 * "Tangerine" ""
          tangerine-id: "852254"
          Assets:Savings:Tangerine 10.50 CAD
          Income:CashBack:Tangerine -10.50 CAD
        """)
    }

    @Test
    func createInterestTransactionNotSetup() throws {
        let ledger = Ledger()
        let accountName1 = try AccountName("Assets:Savings:Tangerine")
        try ledger.add(Account(name: accountName1, metaData: ["number": "1001"]))
        let mapper = SwiftBeanCountTangerineMapper(ledger: ledger)

        let transactions: [String: [[String: Any]]] =
            ["Assets:Savings:Tangerine": [["posted_date": "2022-10-10T10:10:10", "description": "Interest Paid", "amount": 10.50, "type": "INTEREST"] as [String: Any]]]
        let result = try mapper.createTransactions(transactions)
        #expect(result.count == 1)
        #expect(result[0].description == """
        2022-10-10 * "Tangerine" ""
          tangerine-id: "0"
          Assets:Savings:Tangerine 10.50 CAD
          Expenses:TODO -10.50 CAD
        """)
    }

    @Test
    func createInterestTransaction() throws {
        let ledger = Ledger()
        let accountName1 = try AccountName("Assets:Savings:Tangerine")
        try ledger.add(Account(name: accountName1, metaData: ["number": "1001"]))
        let accountName2 = try AccountName("Income:Interest:Tangerine")
        try ledger.add(Account(name: accountName2, metaData: ["tangerine-interest": "1001"]))
        let accountName3 = try AccountName("Income:Interest:Tangerine1")
        try ledger.add(Account(name: accountName3, metaData: ["tangerine-interest": "1002"]))
        let mapper = SwiftBeanCountTangerineMapper(ledger: ledger)

        let transactions: [String: [[String: Any]]] =
            [
                "Assets:Savings:Tangerine":
                [["id": 786, "posted_date": "2022-10-10T10:10:10", "description": "Promotional Bonus Interest", "amount": 10.50, "type": "INTEREST"] as [String: Any]]
            ]
        let result = try mapper.createTransactions(transactions)
        #expect(result.count == 1)
        #expect(result[0].description == """
        2022-10-10 * "Tangerine" "Promotional Bonus Interest"
          tangerine-id: "786"
          Assets:Savings:Tangerine 10.50 CAD
          Income:Interest:Tangerine -10.50 CAD
        """)
    }

    @Test
    func createTransactionsCommoditySymbol() throws {
        let transactions = [ "Assets:Checking": [["posted_date": "2022-10-10T10:10:10", "description": "ABC", "amount": 10.50] as [String: Any]]]
        let ledger = Ledger()
        try ledger.add(Account(name: try AccountName("Assets:Checking"), commoditySymbol: "USD"))
        let mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        let result = try mapper.createTransactions(transactions)
        #expect(result.count == 1)
        #expect(result[0].description == """
        2022-10-10 * "" "ABC"
          tangerine-id: "0"
          Assets:Checking 10.50 USD
          Expenses:TODO -10.50 USD
        """)
    }

    @Test
    func createTransactionsEmpty() throws {
        let transactions = [ "Assets:Checking": [["posted_date": "2022-10-10T10:10:10"]]]
        let ledger = Ledger()
        let posting = Posting(accountName: try AccountName("Assets:Checking"), amount: Amount(number: Decimal(1), commoditySymbol: "CAD", decimalDigits: 2))
        let posting2 = Posting(accountName: try AccountName("Assets:Savings"), amount: Amount(number: Decimal(-1), commoditySymbol: "CAD", decimalDigits: 2))
        let metaData = TransactionMetaData(date: Date(), narration: "description", metaData: ["tangerine-id": "12345"])
        let transaction = Transaction(metaData: metaData, postings: [posting, posting2])
        ledger.add(transaction)

        let mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        let result = try mapper.createTransactions(transactions)
        #expect(result.count == 1)
        #expect(result[0].description == """
        2022-10-10 * "" ""
          tangerine-id: "0"
          Assets:Checking 0.00 CAD
          Expenses:TODO 0.00 CAD
        """)
    }

    @Test
    func ledgerAccountNameEmptyDict() {
        let mapper = SwiftBeanCountTangerineMapper(ledger: Ledger())
        let error = #expect(throws: (any Error).self) { try mapper.ledgerAccountName(account: [:]) }
        expectAccountNotFound(thrownError: error, account: [:])
    }

    @Test
    func ledgerAccountNameCreditCard() throws {
        // No Account
        var mapper = SwiftBeanCountTangerineMapper(ledger: Ledger())
        var error = #expect(throws: (any Error).self) { try mapper.ledgerAccountName(account: creditCard) }
        expectAccountNotFound(thrownError: error, account: creditCard)

        // Asset instead of Liability
        let ledger = Ledger()
        try ledger.add(Account(name: try AccountName("Assets:CreditCard:Tangerine"), metaData: ["last-four": "1583", "importer-type": "tangerine-card"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        error = #expect(throws: (any Error).self) { try mapper.ledgerAccountName(account: creditCard) }
        expectAccountNotFound(thrownError: error, account: creditCard)

        // Wrong last four
        try ledger.add(Account(name: try AccountName("Liabilities:CreditCard:Tangerine2"), metaData: ["last-four": "1585", "importer-type": "tangerine-card"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        error = #expect(throws: (any Error).self) { try mapper.ledgerAccountName(account: creditCard) }
        expectAccountNotFound(thrownError: error, account: creditCard)

        // No importer type
        try ledger.add(Account(name: try AccountName("Liabilities:CreditCard:Tangerine3"), metaData: ["last-four": "1583"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        error = #expect(throws: (any Error).self) { try mapper.ledgerAccountName(account: creditCard) }
        expectAccountNotFound(thrownError: error, account: creditCard)

        let accountName = try AccountName("Liabilities:CreditCard:Tangerine")
        try ledger.add(Account(name: accountName, metaData: ["last-four": "1583", "importer-type": "tangerine-card"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        #expect(try mapper.ledgerAccountName(account: creditCard) == accountName)
    }

    @Test
    func ledgerAccountNameLoan() throws {
        var mapper = SwiftBeanCountTangerineMapper(ledger: Ledger())

        // No Account
        var error = #expect(throws: (any Error).self) { try mapper.ledgerAccountName(account: loan) }
        expectAccountNotFound(thrownError: error, account: loan)

        // Asset instead of Liability
        let ledger = Ledger()
        try ledger.add(Account(name: try AccountName("Assets:LOC:Tangerine"), metaData: ["number": "654321", "importer-type": "tangerine-account"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        error = #expect(throws: (any Error).self) { try mapper.ledgerAccountName(account: loan) }
        expectAccountNotFound(thrownError: error, account: loan)

        // Wrong number
        try ledger.add(Account(name: try AccountName("Liabilities:LOC:Tangerine2"), metaData: ["number": "654322", "importer-type": "tangerine-account"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        error = #expect(throws: (any Error).self) { try mapper.ledgerAccountName(account: loan) }
        expectAccountNotFound(thrownError: error, account: loan)

        // No importer type
        try ledger.add(Account(name: try AccountName("Liabilities:LOC:Tangerine3"), metaData: ["number": "654321"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        error = #expect(throws: (any Error).self) { try mapper.ledgerAccountName(account: loan) }
        expectAccountNotFound(thrownError: error, account: loan)

        let accountName = try AccountName("Liabilities:LOC:Tangerine")
        try ledger.add(Account(name: accountName, metaData: ["number": "654321", "importer-type": "tangerine-account"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        #expect(try mapper.ledgerAccountName(account: loan) == accountName)
    }

    @Test
    func ledgerAccountNameChequing() throws {
        var mapper = SwiftBeanCountTangerineMapper(ledger: Ledger())
        // No Account
        var error = #expect(throws: (any Error).self) { try mapper.ledgerAccountName(account: chequing) }
        expectAccountNotFound(thrownError: error, account: chequing)

        // Liability instead of Asset
        let ledger = Ledger()
        try ledger.add(Account(name: try AccountName("Liabilities:Checking:Tangerine"), metaData: ["number": "123456", "importer-type": "tangerine-account"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        error = #expect(throws: (any Error).self) { try mapper.ledgerAccountName(account: chequing) }
        expectAccountNotFound(thrownError: error, account: chequing)

        // Wrong number
        try ledger.add(Account(name: try AccountName("Assets:Checking:Tangerine2"), metaData: ["number": "1234567", "importer-type": "tangerine-account"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        error = #expect(throws: (any Error).self) { try mapper.ledgerAccountName(account: chequing) }
        expectAccountNotFound(thrownError: error, account: chequing)

        // No importer type
        try ledger.add(Account(name: try AccountName("Assets:Checking:Tangerine3"), metaData: ["number": "123456"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        error = #expect(throws: (any Error).self) { try mapper.ledgerAccountName(account: chequing) }
        expectAccountNotFound(thrownError: error, account: chequing)

        let accountName = try AccountName("Assets:Checking:Tangerine")
        try ledger.add(Account(name: accountName, metaData: ["number": "123456", "importer-type": "tangerine-account"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        #expect(try mapper.ledgerAccountName(account: chequing) == accountName)
    }

    @Test
    func ledgerAccountNameSavings() throws {
        var mapper = SwiftBeanCountTangerineMapper(ledger: Ledger())

        // No Account
        var error = #expect(throws: (any Error).self) { try mapper.ledgerAccountName(account: savings) }
        expectAccountNotFound(thrownError: error, account: savings)

        // Liability instead of Asset
        let ledger = Ledger()
        try ledger.add(Account(name: try AccountName("Liabilities:Savings:Tangerine"), metaData: ["number": "9876543", "importer-type": "tangerine-account"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        error = #expect(throws: (any Error).self) { try mapper.ledgerAccountName(account: savings) }
        expectAccountNotFound(thrownError: error, account: savings)

        // Wrong number
        try ledger.add(Account(name: try AccountName("Assets:Savings:Tangerine2"), metaData: ["number": "98765433", "importer-type": "tangerine-account"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        error = #expect(throws: (any Error).self) { try mapper.ledgerAccountName(account: savings) }
        expectAccountNotFound(thrownError: error, account: savings)

        // No importer type
        try ledger.add(Account(name: try AccountName("Assets:Savings:Tangerine3"), metaData: ["number": "9876543"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        error = #expect(throws: (any Error).self) { try mapper.ledgerAccountName(account: savings) }
        expectAccountNotFound(thrownError: error, account: savings)

        let accountName = try AccountName("Assets:Savings:Tangerine")
        try ledger.add(Account(name: accountName, metaData: ["number": "9876543", "importer-type": "tangerine-account"]))
        mapper = SwiftBeanCountTangerineMapper(ledger: ledger)
        #expect(try mapper.ledgerAccountName(account: savings) == accountName)
    }

    private func expectAccountNotFound(thrownError: Error?, account: [String: Any], sourceLocation: SourceLocation = #_sourceLocation) {
        guard let error = thrownError as? SwiftBeanCountTangerineMapperError else {
            Issue.record("Unexpected error type, got \(type(of: thrownError)) instead of \(SwiftBeanCountTangerineMapperError.self)", sourceLocation: sourceLocation)
            return
        }
        switch error {
        case let .missingAccount(missingAccount):
            for (key, value) in account {
                if let value = value as? String {
                    #expect(missingAccount.contains("\"\(key)\": \"\(value)\""), sourceLocation: sourceLocation)
                } else {
                    #expect(missingAccount.contains("\"\(key)\": \(value)"), sourceLocation: sourceLocation)
                }
            }
        default:
            Issue.record("Wrong error type", sourceLocation: sourceLocation)
        }
    }

}
