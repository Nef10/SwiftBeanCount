import SwiftBeanCountModel
@testable import SwiftBeanCountTax
import XCTest

final class TaxCalculatorTaxableSalesTests: XCTestCase {

    func testGetTaxableSaleEmpty() throws {
        let ledger = try basicLedger()
        let sales = try TaxCalculator.getTaxableSales(from: ledger, for: 2_022)
        XCTAssert(sales.isEmpty)
    }

    func testGetTaxableSales() throws {
        let ledger = try basicLedger()
        let date = Date(timeIntervalSince1970: 1_650_013_015)

        let account = Account(name: try AccountName("Assets:Broker:Stock"), metaData: [MetaDataKeys.sales: "Broker"])
        try ledger.add(account)

        let posting1 = Posting(accountName: account.name,
                               amount: Amount(number: -1.1, commoditySymbol: "STOCK", decimalDigits: 1),
                               price: nil,
                               cost: try Cost(amount: Amount(number: 7, commoditySymbol: "CAD"), date: nil, label: nil))
        let posting2 = Posting(accountName: try AccountName("Assets:Account2"),
                               amount: Amount(number: 7.7, commoditySymbol: "CAD", decimalDigits: 1),
                               price: nil,
                               cost: nil)
        let posting3 = Posting(accountName: try AccountName("Income:Gain"),
                               amount: Amount(number: -2.2, commoditySymbol: "CAD", decimalDigits: 1),
                               price: nil,
                               cost: nil)
        let transaction = Transaction(metaData: TransactionMetaData(date: date, payee: "", narration: "", flag: .complete, tags: []), postings: [posting1, posting2, posting3])
        ledger.add(transaction)

        let sales = try TaxCalculator.getTaxableSales(from: ledger, for: 2_022)
        XCTAssertEqual(sales.count, 1)

        XCTAssertEqual(sales[0].date, date)
        XCTAssertEqual(sales[0].symbol, "STOCK")
        XCTAssertNil(sales[0].name)
        XCTAssertEqual(sales[0].quantity, Decimal(1.1))
        XCTAssertEqual(sales[0].proceeds.fullString, "7.70 CAD")
        XCTAssertEqual(sales[0].gain.fullString, "2.20 CAD")
        XCTAssertEqual(sales[0].provider, "Broker")
    }

    func testGetTaxableSalesIgnoreSplit() throws {
        let ledger = try basicLedger()
        let date = Date(timeIntervalSince1970: 1_650_013_015)

        let account = Account(name: try AccountName("Assets:Broker:Stock"), metaData: [MetaDataKeys.sales: "Broker"])
        try ledger.add(account)

        let posting1 = Posting(accountName: account.name,
                               amount: Amount(number: -1.1, commoditySymbol: "STOCK", decimalDigits: 1),
                               price: nil,
                               cost: try Cost(amount: Amount(number: 7, commoditySymbol: "CAD"), date: nil, label: nil))
        let posting2 = Posting(accountName: try AccountName("Assets:Account2"),
                               amount: Amount(number: 2.2, commoditySymbol: "STOCK", decimalDigits: 1),
                               price: nil,
                               cost: try Cost(amount: Amount(number: 3.5, commoditySymbol: "CAD"), date: nil, label: nil))
        let transaction = Transaction(metaData: TransactionMetaData(date: date, payee: "", narration: "", flag: .complete, tags: []), postings: [posting1, posting2])
        ledger.add(transaction)

        let sales = try TaxCalculator.getTaxableSales(from: ledger, for: 2_022)
        XCTAssertEqual(sales.count, 0)
    }
}
