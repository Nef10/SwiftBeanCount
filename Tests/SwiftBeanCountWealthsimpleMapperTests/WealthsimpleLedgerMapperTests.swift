import SwiftBeanCountModel
@testable import SwiftBeanCountWealthsimpleMapper
import Wealthsimple
import XCTest

struct TestAsset: AssetProvider {
    var symbol = ""
    var type: Asset.AssetType = .currency
}

struct TestPositon: PositionProvider {
    var accountId = ""
    var asset = TestAsset()
    var assetObject: AssetProvider { asset }
    var priceAmount = ""
    var positionDate = Date()
    var priceCurrency = ""
    var quantity = ""
}

struct TestTransaction: TransactionProvider {
    var id = ""
    var accountId = ""
    var transactionType: Wealthsimple.Transaction.TransactionType = .buy
    var description = ""
    var symbol = ""
    var quantity = ""
    var marketPriceAmount = ""
    var marketPriceCurrency = ""
    var marketValueAmount = ""
    var marketValueCurrency = ""
    var netCashAmount = ""
    var netCashCurrency = ""
    var fxRate = ""
    var effectiveDate = Date()
    var processDate = Date()
}

// swiftlint:disable:next type_body_length
final class WealthsimpleLedgerMapperTests: XCTestCase {

    private typealias SAccount = SwiftBeanCountModel.Account

    private let transactionId = "id23"
    private let accountId = "abc123"
    private let accountNumber = "A1B2C3"
    private let fxRate = "2"
    private let cashAccountName = try! AccountName("Assets:W:Cash")

    private var testAccounts = [TestAccount]()
    private var ledger = Ledger()

    private var mapper: WealthsimpleLedgerMapper {
        var wealthsimpleLedgerMapper = WealthsimpleLedgerMapper(ledger: ledger)
        wealthsimpleLedgerMapper.accounts = testAccounts
        return wealthsimpleLedgerMapper
    }

    private var testTransactionPrice: Price {
        try! Price(date: testTransaction.processDate, commoditySymbol: "ETF", amount: Amount(number: Decimal(string: "2.24")!, commoditySymbol: "CAD", decimalDigits: 2))
    }

    private var testTransaction: TestTransaction {
        TestTransaction(id: transactionId,
                        accountId: accountId,
                        symbol: "ETF",
                        quantity: "5.25",
                        marketPriceAmount: "2.24",
                        marketPriceCurrency: "CAD",
                        marketValueCurrency: "CAD",
                        netCashAmount: "-11.76",
                        netCashCurrency: "CAD",
                        processDate: Date(timeIntervalSinceReferenceDate: 5_645_145_697))
    }

    override func setUpWithError() throws {
        ledger = Ledger()
        try? ledger.add(SAccount(name: cashAccountName, metaData: [MetaDataKeys.importerType: MetaData.importerType, MetaDataKeys.number: accountNumber]))
        try? ledger.add(Commodity(symbol: "ETF"))
        try? ledger.add(Commodity(symbol: "CAD"))
        testAccounts = [TestAccount(number: accountNumber, id: accountId, currency: "CAD")]
        try super.setUpWithError()
    }

    func testMapPositionsErrors() {
        // empty the data setup by default
        ledger = Ledger()
        testAccounts = []

        // empty
        let (prices, balances) = try! mapper.mapPositionsToPriceAndBalance([])
        XCTAssert(prices.isEmpty)
        XCTAssert(balances.isEmpty)

        // no account set on mapper
        var position = TestPositon(accountId: accountId)
        assert(try mapper.mapPositionsToPriceAndBalance([position]), throws: WealthsimpleConversionError.accountNotFound(accountId))

        // missing commodity
        testAccounts = [TestAccount(number: accountNumber, id: accountId)]
        position.priceAmount = "1234"
        position.priceCurrency = "EUR"
        position.asset.symbol = "CAD"
        assert(try mapper.mapPositionsToPriceAndBalance([position]), throws: WealthsimpleConversionError.missingCommodity("CAD"))

        // missing account in ledger
        try! ledger.add(Commodity(symbol: "CAD"))
        position.quantity = "9.871"
        assert(try mapper.mapPositionsToPriceAndBalance([position]), throws: WealthsimpleConversionError.missingWealthsimpleAccount(accountNumber))
    }

    func testMapPositions() {
        var position = TestPositon(accountId: accountId, priceAmount: "1234", priceCurrency: "EUR", quantity: "9.871")
        position.asset.symbol = "CAD"

        // currency
        var (prices, balances) = try! mapper.mapPositionsToPriceAndBalance([position])
        XCTAssert(prices.isEmpty)
        XCTAssertEqual(balances, [Balance(date: position.positionDate, accountName: cashAccountName, amount: priceAmount(number: "9.871", decimals: 3))])

        // non currency
        position.asset.type = .exchangeTradedFund
        position.asset.symbol = "ETF"
        let price = try! Price(date: position.positionDate, commoditySymbol: "ETF", amount: Amount(number: Decimal(1_234), commoditySymbol: "EUR", decimalDigits: 2))
        let balance = Balance(date: position.positionDate, accountName: try! AccountName("Assets:W:ETF"), amount: priceAmount(number: "9.871", commodity: "ETF", decimals: 3))
        (prices, balances) = try! mapper.mapPositionsToPriceAndBalance([position])
        XCTAssertEqual(prices, [price])
        XCTAssertEqual(balances, [balance])

        // already exists
        try! ledger.add(price)
        ledger.add(balance)
        (prices, balances) = try! mapper.mapPositionsToPriceAndBalance([position])
        XCTAssert(prices.isEmpty)
        XCTAssert(balances.isEmpty)
    }

    func testMapTransactionsErrors() {
        // empty the data setup by default
        ledger = Ledger()
        testAccounts = []

        // empty
        let (prices, transactions) = try! mapper.mapTransactionsToPriceAndTransactions([])
        XCTAssert(prices.isEmpty)
        XCTAssert(transactions.isEmpty)

        // no account set on mapper
        var transaction = TestTransaction(accountId: accountId)
        assert(try mapper.mapTransactionsToPriceAndTransactions([transaction]), throws: WealthsimpleConversionError.accountNotFound(accountId))

        // missing account in ledger
        testAccounts = [TestAccount(number: accountNumber, id: accountId)]
        transaction.symbol = "CAD"
        transaction.netCashAmount = "7.53"
        assert(try mapper.mapTransactionsToPriceAndTransactions([transaction]), throws: WealthsimpleConversionError.missingWealthsimpleAccount(accountNumber) )

        // missing commodity
        try! ledger.add(SAccount(name: cashAccountName, metaData: [MetaDataKeys.importerType: MetaData.importerType, MetaDataKeys.number: accountNumber]))
        assert(try mapper.mapTransactionsToPriceAndTransactions([transaction]), throws: WealthsimpleConversionError.missingCommodity("CAD"))

        // unsupported type
        transaction.transactionType = .hst
        assert(try mapper.mapTransactionsToPriceAndTransactions([transaction]),
               throws: WealthsimpleConversionError.unsupportedTransactionType(transaction.transactionType.rawValue))

        // nrwt invalid description
        try? ledger.add(Commodity(symbol: "CAD"))
        var nrwt = testTransaction
        nrwt.transactionType = .nonResidentWithholdingTax
        nrwt.fxRate = "1.2343"
        nrwt.description = "Garbage"
        assert(try mapper.mapTransactionsToPriceAndTransactions([nrwt]), throws: WealthsimpleConversionError.unexpectedDescription(nrwt.description))

        // dividend invalid description
        var dividend = testTransaction
        dividend.transactionType = .dividend
        dividend.fxRate = "1.2343"
        dividend.description = "Garbage2"
        assert(try mapper.mapTransactionsToPriceAndTransactions([dividend]), throws: WealthsimpleConversionError.unexpectedDescription(dividend.description))
    }

    func testMapTransactionsBuy() {
        var transaction = testTransaction

        // buy
        var (prices, transactions) = try! mapper.mapTransactionsToPriceAndTransactions([transaction])
        let assetPosting = Posting(accountName: try! AccountName("Assets:W:ETF"),
                                   amount: Amount(number: Decimal(string: transaction.quantity)!, commoditySymbol: "ETF", decimalDigits: 2),
                                   cost: try! Cost(amount: testTransactionPrice.amount, date: nil, label: nil))
        var postings = [posting(), assetPosting]
        var resultTransaction = Transaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transactionId]), postings: postings)
        XCTAssertEqual(prices, [testTransactionPrice])
        XCTAssertEqual(transactions, [resultTransaction])

        // buy fx
        transaction.netCashCurrency = "EUR"
        transaction.netCashAmount = "-23.51"
        transaction.fxRate = fxRate
        (prices, transactions) = try! mapper.mapTransactionsToPriceAndTransactions([transaction])
        postings = [posting(number: transaction.netCashAmount, commodity: "EUR", price: priceAmount()), postings[1]]
        resultTransaction = Transaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transactionId]), postings: postings)
        XCTAssertEqual(prices, [testTransactionPrice])
        XCTAssertEqual(transactions, [resultTransaction])

    }

    func testMapTransactionsSell() {
        var transaction = testTransaction

        // sell
        transaction = testTransaction
        transaction.transactionType = .sell
        transaction.netCashAmount = "11.76"
        transaction.quantity = "-\(transaction.quantity)"
        var (prices, transactions) = try! mapper.mapTransactionsToPriceAndTransactions([transaction])
        let assetPosting = Posting(accountName: try! AccountName("Assets:W:ETF"),
                                   amount: Amount(number: Decimal(string: transaction.quantity)!, commoditySymbol: "ETF", decimalDigits: 2),
                                   price: testTransactionPrice.amount,
                                   cost: try! Cost(amount: nil, date: nil, label: nil))
        var postings = [posting(number: "11.76"), assetPosting]
        var resultTransaction = Transaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transactionId]), postings: postings)
        XCTAssertEqual(prices, [testTransactionPrice])
        XCTAssertEqual(transactions, [resultTransaction])

        // sell fx
        transaction.netCashCurrency = "EUR"
        transaction.netCashAmount = "23.51"
        transaction.fxRate = fxRate
        (prices, transactions) = try! mapper.mapTransactionsToPriceAndTransactions([transaction])
        postings = [posting(number: transaction.netCashAmount, commodity: "EUR", price: priceAmount()), postings[1]]
        resultTransaction = Transaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transactionId]), postings: postings)
        XCTAssertEqual(prices, [testTransactionPrice])
        XCTAssertEqual(transactions, [resultTransaction])
    }

    func testMapTransactionsAlreadyExisting() {
        ledger.add(Transaction(metaData: TransactionMetaData(date: Date(), metaData: [MetaDataKeys.id: transactionId]), postings: []))

        // transaction exists
        var (prices, transactions) = try! mapper.mapTransactionsToPriceAndTransactions([testTransaction])
        XCTAssertEqual(prices, [testTransactionPrice])
        XCTAssert(transactions.isEmpty)

        // price exists as well
        try! ledger.add(testTransactionPrice)
        (prices, transactions) = try! mapper.mapTransactionsToPriceAndTransactions([testTransaction])
        XCTAssert(prices.isEmpty)
        XCTAssert(transactions.isEmpty)

        // non merged nrwt transaction already exists
        var nrwt = testTransaction
        nrwt.transactionType = .nonResidentWithholdingTax
        nrwt.id = "tid2"
        nrwt.fxRate = fxRate
        nrwt.description = "VTI - Vanguard Index STK MKT ETF: Non-resident tax withheld at source (2.43 USD, convert to CAD @ 1.2343)"
        ledger.add(Transaction(metaData: TransactionMetaData(date: Date(), metaData: [MetaDataKeys.nrwtId: "tid2"]), postings: []))
        try! ledger.add(SAccount(name: try! AccountName("Expenses:t"), metaData: ["\(MetaDataKeys.prefix)\("\(nrwt.transactionType)".camelCaseToKebabCase())": accountNumber]))
        (prices, transactions) = try! mapper.mapTransactionsToPriceAndTransactions([nrwt])
        XCTAssert(prices.isEmpty)
        XCTAssert(transactions.isEmpty)
    }

    func testMapTransactionsDividendAndNRWT() {
        var nrwt = testTransaction
        nrwt.transactionType = .nonResidentWithholdingTax
        nrwt.fxRate = fxRate
        nrwt.netCashAmount = "-4.86"
        nrwt.description = "VTI - Vanguard Index STK MKT ETF: Non-resident tax withheld at source (2.43 USD, convert to CAD @ 2.00)"
        try? ledger.add(SAccount(name: try! AccountName("Expenses:t"), metaData: ["\(MetaDataKeys.prefix)\("\(nrwt.transactionType)".camelCaseToKebabCase())": accountNumber]))

        // nrwt not merged
        var (prices, transactions) = try! mapper.mapTransactionsToPriceAndTransactions([nrwt])
        var transaction = Transaction(metaData: TransactionMetaData(date: nrwt.processDate, metaData: [MetaDataKeys.id: transactionId]), postings: [
            posting(number: nrwt.netCashAmount, price: priceAmount(commodity: "USD")), posting(account: "Expenses:t", number: "2.43", commodity: "USD")
        ])
        XCTAssert(prices.isEmpty)
        XCTAssertEqual(transactions, [transaction])

        // nrwt merged
        try! ledger.add(SAccount(name: try! AccountName("Income:t"), metaData: ["\(MetaDataKeys.dividendPrefix)ETF": accountNumber]))
        var dividend = nrwt
        dividend.transactionType = .dividend
        dividend.netCashAmount = "32.42"
        dividend.id = "NewID1"
        dividend.description = "VTI - Vanguard Index STK MKT ETF: 25-JUN-21 (record date) 24.0020 shares, gross 16.21 USD, convert to CAD @ – – 2.00"
        (prices, transactions) = try! mapper.mapTransactionsToPriceAndTransactions([nrwt, dividend])
        var meta = [MetaDataKeys.dividendShares: "24.0020", MetaDataKeys.dividendRecordDate: "2021-06-25", MetaDataKeys.id: dividend.id, MetaDataKeys.nrwtId: transactionId]
        transaction = Transaction(metaData: TransactionMetaData(date: nrwt.processDate, metaData: meta), postings: [
            Posting(accountName: try! AccountName("Income:t"), amount: Amount(number: Decimal(string: "-16.21")!, commoditySymbol: "USD", decimalDigits: 2)),
            transaction.postings[1], posting(number: "27.56", price: priceAmount(commodity: "USD"))
        ])
        XCTAssert(prices.isEmpty)
        XCTAssertEqual(transactions, [transaction])

        // dividend
        (prices, transactions) = try! mapper.mapTransactionsToPriceAndTransactions([dividend])
        meta[MetaDataKeys.nrwtId] = nil
        transaction = Transaction(metaData: TransactionMetaData(date: nrwt.processDate, metaData: meta), postings: [
            posting(number: dividend.netCashAmount, price: priceAmount(commodity: "USD")), transaction.postings[0]
        ])
        XCTAssertEqual(transactions, [transaction])
        XCTAssert(prices.isEmpty)
    }

    func testMapTransactionsTransfers() {
        var count = 1
        let types: [SwiftBeanCountModel.AccountType: [Wealthsimple.Transaction.TransactionType]] = [
            .asset: [.deposit, .withdrawal, .paymentTransferOut, .transferIn, .transferOut, .paymentTransferIn, .referralBonus, .giveawayBonus, .refund],
            .income: [.paymentTransferIn, .referralBonus, .giveawayBonus, .refund, .fee, .reimbursement, .interest],
            .expense: [.paymentSpend, .fee, .reimbursement, .interest]
        ]
        for (accountType, transactionTypes) in types {
            for transactionType in transactionTypes {
                let accountName = try! AccountName("\(accountType.rawValue):Test\(count)")
                try? ledger.add(SAccount(name: accountName, metaData: ["\(MetaDataKeys.prefix)\("\(transactionType)".camelCaseToKebabCase())": accountNumber]))
                var transaction = testTransaction
                transaction.transactionType = transactionType
                transaction.symbol = "CAD"
                transaction.netCashAmount = transaction.quantity
                transaction.marketPriceAmount = "1.00"

                let (prices, transactions) = try! mapper.mapTransactionsToPriceAndTransactions([transaction])
                let assetPosting = Posting(accountName: accountName, amount: priceAmount(number: "-\(transaction.netCashAmount )"))
                let payee = [.fee, .reimbursement, .interest].contains(transactionType) ? "Wealthsimple" : ""
                let resultTransaction = Transaction(metaData: TransactionMetaData(date: transaction.processDate, payee: payee, metaData: [MetaDataKeys.id: transactionId]),
                                                    postings: [posting(number: transaction.netCashAmount), assetPosting])
                XCTAssert(prices.isEmpty)
                XCTAssertEqual(transactions, [resultTransaction])

                count += 1
            }
            ledger = Ledger()
            try! ledger.add(SAccount(name: cashAccountName, metaData: [MetaDataKeys.importerType: MetaData.importerType, MetaDataKeys.number: accountNumber]))
            try! ledger.add(Commodity(symbol: "ETF"))
            try! ledger.add(Commodity(symbol: "CAD"))
        }
    }

    private func posting(account: String = "Assets:W:Cash", number: String = "-11.76", commodity: String = "CAD", decimals: Int = 2, price: Amount? = nil) -> Posting {
        Posting(accountName: try! AccountName(account), amount: Amount(number: Decimal(string: number)!, commoditySymbol: commodity, decimalDigits: decimals), price: price)
    }

    private func priceAmount(number: String = "0.50", commodity: CommoditySymbol = "CAD", decimals: Int = 2) -> Amount {
        Amount(number: Decimal(string: number)!, commoditySymbol: commodity, decimalDigits: decimals)
    }

}
