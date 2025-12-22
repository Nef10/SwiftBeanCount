import CSV
@testable import SwiftBeanCountCompassCardMapper
import SwiftBeanCountModel
import XCTest

final class SwiftBeanCountCompassCardMapperTests: XCTestCase {

    // swiftlint:disable line_length
    private enum CSV {
        static let header = "DateTime,Transaction,Product,LineItem,Amount,BalanceDetails,JourneyId,LocationDisplay,TransactonTime,OrderDate,Payment,OrderNumber,AuthCode,Total\n"
        static let autoLoad = "Dec-01-2022 09:26 AM,AutoLoaded,Stored Value,,$20.00,$22.00,,\"AutoLoaded\nStored Value\",09:26 AM,,,,,\n"
        static let transaction1 = "Nov-17-2022 08:39 PM,Tap in at Bus Stop 60572,Stored Value,,-$2.50,$7.45,2022-11-18T04:39:00.0000000Z,\"Tap in at Bus Stop 60572 Stored Value\",08:39 PM,,,,,\n"
        static let transaction2 = "Dec-06-2022 05:22 PM,Tap out at Edmonds Stn,Stored Value,,$1.05,$12.10,2022-12-07T00:59:00.0000000Z,\"Tap out at Edmonds Stn\nStored Value\",05:22 PM,,,,,\nDec-06-2022 05:11 PM,Transfer at Waterfront Stn,Stored Value,,-$1.05,$22.90,2022-12-07T00:59:00.0000000Z,\"Transfer at Waterfront Stn\nStored Value\",08:44 AM,,,,,\nDec-06-2022 05:09 PM,Tap out at Waterfront Stn,Stored Value,,$1.05,$23.95,2022-12-07T00:59:00.0000000Z,\"Tap out at Waterfront Stn\nStored Value\",08:43 AM,,,,,\nDec-06-2022 04:59 PM,Tap in at Stadium Stn,Stored Value,,-$4.70,$11.05,2022-12-07T00:59:00.0000000Z,\"Tap in at Stadium Stn\nStored Value\",04:59 PM,,,,,\n"
        static let refund = "Dec-01-2022 06:07 PM,Refund at Stadium Stn,Stored Value,,$4.70,$23.05,2022-12-02T02:05:00.0000000Z,\"Refund at Stadium Stn\nStored Value\",06:07 PM,,,,,\nDec-01-2022 06:05 PM,Tap in at Stadium Stn,Stored Value,,-$4.70,$18.35,2022-12-02T02:05:00.0000000Z,\"Tap in at Stadium Stn\nStored Value\",06:05 PM,,,,,\n"
        static let webLoad = "Dec-01-2022 09:26 AM,\"#43926965\nWeb Order\",Transit value or product load,Add Stored Value,$20.00,,,\"#43926965 Transit value or product load\",02:48 PM,Aug-30-2024 02:48 PM,MasterCard,43926965,05724E,$20.00\n"
        static let load = "Dec-01-2022 09:26 AM,Loaded at Edmonds Stn,Stored Value,,$20.00,$30.70,,\"Loaded at Edmonds Stn\nStored Value\",09:15 AM,,,,,\n"
    }
    // swiftlint:enable line_length

    private let emptyMapper = SwiftBeanCountCompassCardMapper(ledger: Ledger())
    private let accountName = "Assets:CompassCard"
    private let cardNumber = "987654321"

    private lazy var mapper: SwiftBeanCountCompassCardMapper = {
        let ledger = Ledger()
         // swiftlint:disable:next force_try
        try! ledger.add(Account(name: try! AccountName(accountName), metaData: ["card-number": cardNumber, "importer-type": "compass-card"]))
        return SwiftBeanCountCompassCardMapper(ledger: ledger)
    }()

    func testDefaultExpenseAccountName() throws {
        XCTAssertEqual(emptyMapper.defaultExpenseAccountName, try AccountName("Expenses:TODO"))
    }

    func testDefaultAssetAccountName() throws {
        XCTAssertEqual(emptyMapper.defaultAssetAccountName, try AccountName("Assets:TODO"))
    }

    func testCreateBalanceNoAccount() {
        XCTAssertThrowsError(try emptyMapper.createBalance(cardNumber: cardNumber, balance: " $ 14.55 ")) {
            XCTAssertEqual($0 as? SwiftBeanCountCompassCardMapperError, .missingAccount(cardNumber: cardNumber))
        }
    }

    func testCreateBalance() throws {
        let date = Date()
        let result = try mapper.createBalance(cardNumber: "987654321", balance: " $ 14.55 ", date: date)
        let (decimal, _) = "14.55".amountDecimal()
        XCTAssertEqual(result.accountName.fullName, accountName)
        XCTAssertEqual(result.amount, Amount(number: decimal, commoditySymbol: "CAD", decimalDigits: 2))
        XCTAssertEqual(result.date, date)
    }

    func testCreateTransactionsEmpty() throws {
        let result = try mapper.createTransactions(cardNumber: cardNumber, transactions: CSV.header)
        XCTAssertEqual(result, [])
    }

    func testAutoLoadTransaction() throws {
        let result = try mapper.createTransactions(cardNumber: cardNumber, transactions: "\(CSV.header)\(CSV.autoLoad)")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first!.metaData.narration, "")
        XCTAssertEqual(result.first!.metaData.metaData["journey-id"], "compass-card-load-2022-12-01-09-26")
        XCTAssertEqual(result.first!.metaData.date, Date(timeIntervalSince1970: 1_669_915_560))
        XCTAssert(result.first!.postings.contains {
            $0.accountName.fullName == accountName && $0.amount.description == "20.00 CAD"
        })
        XCTAssert(result.first!.postings.contains {
            $0.accountName == mapper.defaultAssetAccountName && $0.amount.description == "-20.00 CAD"
        })
    }

    func testWebLoadTransaction() throws {
        let result = try mapper.createTransactions(cardNumber: cardNumber, transactions: "\(CSV.header)\(CSV.webLoad)")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first!.metaData.narration, "")
        XCTAssertEqual(result.first!.metaData.metaData["journey-id"], "compass-card-load-43926965")
        XCTAssertEqual(result.first!.metaData.date, Date(timeIntervalSince1970: 1_669_915_560))
        XCTAssert(result.first!.postings.contains {
            $0.accountName.fullName == accountName && $0.amount.description == "20.00 CAD"
        })
        XCTAssert(result.first!.postings.contains {
            $0.accountName == mapper.defaultAssetAccountName && $0.amount.description == "-20.00 CAD"
        })
    }

    func testWebLoadAndLoadTransaction() throws {
        let result = try mapper.createTransactions(cardNumber: cardNumber, transactions: "\(CSV.header)\(CSV.load)\(CSV.webLoad)")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first!.metaData.narration, "")
        XCTAssertEqual(result.first!.metaData.metaData["journey-id"], "compass-card-load-43926965")
        XCTAssertEqual(result.first!.metaData.date, Date(timeIntervalSince1970: 1_669_915_560))
        XCTAssert(result.first!.postings.contains {
            $0.accountName.fullName == accountName && $0.amount.description == "20.00 CAD"
        })
        XCTAssert(result.first!.postings.contains {
            $0.accountName == mapper.defaultAssetAccountName && $0.amount.description == "-20.00 CAD"
        })
    }

    func testTwoLoadTransaction() throws {
        let result = try mapper.createTransactions(cardNumber: cardNumber, transactions: "\(CSV.header)\(CSV.load)\(CSV.load)")
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], result[1])
        XCTAssertEqual(result.first!.metaData.narration, "")
        XCTAssertEqual(result.first!.metaData.metaData["journey-id"], "compass-card-load-2022-12-01-09-26")
        XCTAssertEqual(result.first!.metaData.date, Date(timeIntervalSince1970: 1_669_915_560))
        XCTAssert(result.first!.postings.contains {
            $0.accountName.fullName == accountName && $0.amount.description == "20.00 CAD"
        })
        XCTAssert(result.first!.postings.contains {
            $0.accountName == mapper.defaultAssetAccountName && $0.amount.description == "-20.00 CAD"
        })
    }

    func testAutoLoadTransactionCSVReader() throws {
        let reader = try CSVReader(string: "\(CSV.header)\(CSV.autoLoad)", hasHeaderRow: true)
        let result = try mapper.createTransactions(account: try AccountName(accountName), reader: reader)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first!.metaData.narration, "")
        XCTAssertEqual(result.first!.metaData.metaData["journey-id"], "compass-card-load-2022-12-01-09-26")
        XCTAssertEqual(result.first!.metaData.date, Date(timeIntervalSince1970: 1_669_915_560))
        XCTAssert(result.first!.postings.contains {
            $0.accountName.fullName == accountName && $0.amount.description == "20.00 CAD"
        })
        XCTAssert(result.first!.postings.contains {
            $0.accountName == mapper.defaultAssetAccountName && $0.amount.description == "-20.00 CAD"
        })
    }

    func testAutoLoadTransactionNonDefaultAccount() throws {
        let loadAccountName = "Assets:Checking"
        let ledger = Ledger()
        try ledger.add(Account(name: try AccountName(accountName), metaData: ["card-number": cardNumber, "importer-type": "compass-card"]))
        try ledger.add(Account(name: try AccountName(loadAccountName), metaData: ["compass-card-load": cardNumber]))
        try ledger.add(Account(name: try AccountName("Assets:WrongAccount"), metaData: ["compass-card-load": "123456789"]))
        let mapper = SwiftBeanCountCompassCardMapper(ledger: ledger)

        let result = try mapper.createTransactions(cardNumber: cardNumber, transactions: "\(CSV.header)\(CSV.autoLoad)")
        XCTAssertEqual(result.count, 1)
        XCTAssert(result.first!.postings.contains {
            $0.accountName.fullName == accountName && $0.amount.description == "20.00 CAD"
        })
        XCTAssert(result.first!.postings.contains {
            $0.accountName.fullName == loadAccountName && $0.amount.description == "-20.00 CAD"
        })
    }

    func testCreateTransaction() throws {
        let result = try mapper.createTransactions(cardNumber: cardNumber, transactions: "\(CSV.header)\(CSV.transaction1)")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first!.metaData.narration, "Bus Stop 60572")
        XCTAssertEqual(result.first!.metaData.metaData["journey-id"], "2022-11-18T04:39:00.0000000Z")
        XCTAssertEqual(result.first!.metaData.date, Date(timeIntervalSince1970: 1_668_746_340))
        XCTAssert(result.first!.postings.contains {
            $0.accountName.fullName == accountName && $0.amount.description == "-2.50 CAD"
        })
        XCTAssert(result.first!.postings.contains {
            $0.accountName == mapper.defaultExpenseAccountName && $0.amount.description == "2.50 CAD"
        })
    }

    func testCreateTransactionCSVReader() throws {
        let reader = try CSVReader(string: "\(CSV.header)\(CSV.transaction1)", hasHeaderRow: true)
        let result = try mapper.createTransactions(account: try AccountName(accountName), reader: reader)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first!.metaData.narration, "Bus Stop 60572")
        XCTAssertEqual(result.first!.metaData.metaData["journey-id"], "2022-11-18T04:39:00.0000000Z")
        XCTAssertEqual(result.first!.metaData.date, Date(timeIntervalSince1970: 1_668_746_340))
        XCTAssert(result.first!.postings.contains {
            $0.accountName.fullName == accountName && $0.amount.description == "-2.50 CAD"
        })
        XCTAssert(result.first!.postings.contains {
            $0.accountName == mapper.defaultExpenseAccountName && $0.amount.description == "2.50 CAD"
        })
    }

    func testCreateTransactionNonDefaultAccount() throws {
        let expenseAccountName = "Expenses:Transit"
        let ledger = Ledger()
        try ledger.add(Account(name: try AccountName(accountName), metaData: ["card-number": cardNumber, "importer-type": "compass-card"]))
        try ledger.add(Account(name: try AccountName(expenseAccountName), metaData: ["compass-card-expense": cardNumber]))
        try ledger.add(Account(name: try AccountName("Assets:WrongAccount"), metaData: ["compass-card-expense": "123456789"]))
        let mapper = SwiftBeanCountCompassCardMapper(ledger: ledger)

        let result = try mapper.createTransactions(cardNumber: cardNumber, transactions: "\(CSV.header)\(CSV.transaction1)")
        XCTAssertEqual(result.count, 1)
        XCTAssert(result.first!.postings.contains {
            $0.accountName.fullName == accountName && $0.amount.description == "-2.50 CAD"
        })
        XCTAssert(result.first!.postings.contains {
            $0.accountName.fullName == expenseAccountName && $0.amount.description == "2.50 CAD"
        })
    }

    func testCreateTransactionAlreadyInLedger() throws {
        let expenseAccountName = "Expenses:Transit"
        let ledger = Ledger()
        try ledger.add(Account(name: try AccountName(accountName), metaData: ["card-number": cardNumber, "importer-type": "compass-card"]))
        try ledger.add(Account(name: try AccountName(expenseAccountName), metaData: ["compass-card-expense": cardNumber]))

        let posting = Posting(accountName: try AccountName(expenseAccountName), amount: Amount(number: Decimal(2), commoditySymbol: "CAD", decimalDigits: 2))
        let posting2 = Posting(accountName: try AccountName(accountName), amount: Amount(number: -Decimal(2), commoditySymbol: "CAD", decimalDigits: 2))
        let metaData = TransactionMetaData(date: Date(), narration: "", metaData: ["journey-id": "2022-11-18T04:39:00.0000000Z"])
        ledger.add(Transaction(metaData: metaData, postings: [posting, posting2]))

        let mapper = SwiftBeanCountCompassCardMapper(ledger: ledger)

        let result = try mapper.createTransactions(cardNumber: cardNumber, transactions: "\(CSV.header)\(CSV.transaction1)")
        XCTAssertEqual(result.count, 0)
    }

    func testCreateTransactionTransfer() throws {
        let result = try mapper.createTransactions(cardNumber: cardNumber, transactions: "\(CSV.header)\(CSV.transaction2)")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first!.metaData.narration, "Stadium -> Waterfront -> Edmonds") // Tap in, Tap out, Transfer at, Stn and duplicate entry for Waterfront is removed
        XCTAssertEqual(result.first!.metaData.metaData["journey-id"], "2022-12-07T00:59:00.0000000Z")
        XCTAssertEqual(result.first!.metaData.date, Date(timeIntervalSince1970: 1_670_376_120))
        XCTAssert(result.first!.postings.contains {
            $0.accountName.fullName == accountName && $0.amount.description == "-3.65 CAD"
        })
        XCTAssert(result.first!.postings.contains {
            $0.accountName == mapper.defaultExpenseAccountName && $0.amount.description == "3.65 CAD"
        })
    }

    func testCreateMultipleTransactions() throws {
        let result = try mapper.createTransactions(cardNumber: cardNumber, transactions: "\(CSV.header)\(CSV.transaction1)\(CSV.transaction2)")
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].metaData.narration, "Bus Stop 60572")
        XCTAssertEqual(result[1].metaData.narration, "Stadium -> Waterfront -> Edmonds")
    }

    func testCreateTransactionRefund() throws {
        let result = try mapper.createTransactions(cardNumber: cardNumber, transactions: "\(CSV.header)\(CSV.refund)")
        XCTAssertEqual(result.count, 0)
    }

}
