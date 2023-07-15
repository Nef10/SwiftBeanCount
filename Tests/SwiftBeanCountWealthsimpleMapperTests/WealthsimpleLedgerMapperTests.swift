import SwiftBeanCountModel
@testable import SwiftBeanCountWealthsimpleMapper
import Wealthsimple
import XCTest

// swiftlint:disable:next type_body_length
final class WealthsimpleLedgerMapperTests: XCTestCase {

    private typealias SAccount = SwiftBeanCountModel.Account

    private let transactionId = "id23"
    private let accountId = "abc123"
    private let accountNumber = "A1B2C3"
    private let fxRate = "2"
    private let cashAccountName = try! AccountName("Assets:W:Cash") // swiftlint:disable:this force_try

    private var testAccounts = [Wealthsimple.Account]()
    private var ledger = Ledger()

    private var mapper: WealthsimpleLedgerMapper {
        var wealthsimpleLedgerMapper = WealthsimpleLedgerMapper(ledger: ledger)
        wealthsimpleLedgerMapper.accounts = testAccounts
        return wealthsimpleLedgerMapper
    }

    private var testTransactionPrice: Price { // swiftlint:disable:next force_try
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

    func testMapPositionsErrors() throws {
        // empty the data setup by default
        ledger = Ledger()
        testAccounts = []

        // empty
        let (prices, balances) = try mapper.mapPositionsToPriceAndBalance([])
        XCTAssert(prices.isEmpty)
        XCTAssert(balances.isEmpty)

        // no account set on mapper
        var position = TestPositon(accountId: accountId)
        assert(try mapper.mapPositionsToPriceAndBalance([position]), throws: WealthsimpleConversionError.accountNotFound(accountId))

        // missing commodity
        testAccounts = [TestAccount(number: accountNumber, id: accountId)]
        position.priceAmount = "1234"
        position.priceCurrency = "EUR"
        position.assetSymbol = "CAD"
        assert(try mapper.mapPositionsToPriceAndBalance([position]), throws: WealthsimpleConversionError.missingCommodity("CAD"))

        // missing account in ledger
        try ledger.add(Commodity(symbol: "CAD"))
        position.quantity = "9.871"
        assert(try mapper.mapPositionsToPriceAndBalance([position]), throws: WealthsimpleConversionError.missingWealthsimpleAccount(accountNumber))
    }

    func testMapPositions() throws {
        var position = TestPositon(accountId: accountId, priceAmount: "1234", priceCurrency: "EUR", quantity: "9.871")
        position.assetSymbol = "CAD"

        // currency
        var (prices, balances) = try mapper.mapPositionsToPriceAndBalance([position])
        XCTAssert(prices.isEmpty)
        XCTAssertEqual(balances, [Balance(date: position.positionDate, accountName: cashAccountName, amount: priceAmount(number: "9.871", decimals: 3))])

        // non currency
        position.assetType = .exchangeTradedFund
        position.assetSymbol = "ETF"
        let price = try Price(date: position.positionDate, commoditySymbol: "ETF", amount: Amount(number: Decimal(1_234), commoditySymbol: "EUR", decimalDigits: 2))
        let balance = Balance(date: position.positionDate, accountName: try AccountName("Assets:W:ETF"), amount: priceAmount(number: "9.871", commodity: "ETF", decimals: 3))
        (prices, balances) = try mapper.mapPositionsToPriceAndBalance([position])
        XCTAssertEqual(prices, [price])
        XCTAssertEqual(balances, [balance])

        // already exists
        try ledger.add(price)
        ledger.add(balance)
        (prices, balances) = try mapper.mapPositionsToPriceAndBalance([position])
        XCTAssert(prices.isEmpty)
        XCTAssert(balances.isEmpty)
    }

    func testMapTransactionsErrors() throws {
        // empty the data setup by default
        ledger = Ledger()
        testAccounts = []

        // empty
        let (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([])
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
        try ledger.add(SAccount(name: cashAccountName, metaData: [MetaDataKeys.importerType: MetaData.importerType, MetaDataKeys.number: accountNumber]))
        assert(try mapper.mapTransactionsToPriceAndTransactions([transaction]), throws: WealthsimpleConversionError.missingCommodity("CAD"))

        // unsupported type
        transaction.transactionType = .hst
        assert(try mapper.mapTransactionsToPriceAndTransactions([transaction]),
               throws: WealthsimpleConversionError.unsupportedTransactionType(transaction.transactionType.rawValue))
    }

    func testMapSpecialTransactionsErrors() throws {
        var transaction = TestTransaction(accountId: accountId)

        // nrwt invalid description
        try? ledger.add(Commodity(symbol: "CAD"))
        var nrwt = testTransaction
        nrwt.transactionType = .nonResidentWithholdingTax
        nrwt.fxRate = "1.2343"
        nrwt.description = "Garbage"
        assert(try mapper.mapTransactionsToPriceAndTransactions([nrwt]), throws: WealthsimpleConversionError.unexpectedDescription(nrwt.description))

        // only one transaction for stock split
        transaction.transactionType = .stockDistribution
        assert(try mapper.mapTransactionsToPriceAndTransactions([transaction]), throws: WealthsimpleConversionError.unexpectedStockSplit(transaction.description))

        // two buy transactions for stock split
        var split = TestTransaction(accountId: accountId)
        split.transactionType = .stockDistribution
        assert(try mapper.mapTransactionsToPriceAndTransactions([transaction, split]), throws: WealthsimpleConversionError.unexpectedStockSplit(split.description))
    }

    func testMapTransactionsBuy() throws {
        var transaction = testTransaction

        // buy
        var (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction])
        let assetPosting = Posting(accountName: try AccountName("Assets:W:ETF"),
                                   amount: Amount(number: Decimal(string: transaction.quantity)!, commoditySymbol: "ETF", decimalDigits: 2),
                                   cost: try Cost(amount: testTransactionPrice.amount, date: nil, label: nil))
        var postings = [try posting(), assetPosting]
        var resultTransaction = Transaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transactionId]), postings: postings)
        XCTAssertEqual(prices, [testTransactionPrice])
        XCTAssertEqual(transactions, [resultTransaction])

        // buy fx
        transaction.netCashCurrency = "EUR"
        transaction.netCashAmount = "-23.51"
        transaction.fxRate = fxRate
        (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction])
        postings = [try posting(number: transaction.netCashAmount, commodity: "EUR", price: priceAmount()), postings[1]]
        resultTransaction = Transaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transactionId]), postings: postings)
        XCTAssertEqual(prices, [testTransactionPrice])
        XCTAssertEqual(transactions, [resultTransaction])

    }

    func testMapTransactionsSell() throws {
        var transaction = testTransaction

        // sell
        transaction = testTransaction
        transaction.transactionType = .sell
        transaction.netCashAmount = "11.76"
        transaction.quantity = "-\(transaction.quantity)"
        var (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction])
        let assetPosting = Posting(accountName: try AccountName("Assets:W:ETF"),
                                   amount: Amount(number: Decimal(string: transaction.quantity)!, commoditySymbol: "ETF", decimalDigits: 2),
                                   price: testTransactionPrice.amount,
                                   cost: try Cost(amount: nil, date: nil, label: nil))
        var postings = [try posting(number: "11.76"), assetPosting]
        var resultTransaction = Transaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transactionId]), postings: postings)
        XCTAssertEqual(prices, [testTransactionPrice])
        XCTAssertEqual(transactions, [resultTransaction])

        // sell fx
        transaction.netCashCurrency = "EUR"
        transaction.netCashAmount = "23.51"
        transaction.fxRate = fxRate
        (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction])
        postings = [try posting(number: transaction.netCashAmount, commodity: "EUR", price: priceAmount()), postings[1]]
        resultTransaction = Transaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transactionId]), postings: postings)
        XCTAssertEqual(prices, [testTransactionPrice])
        XCTAssertEqual(transactions, [resultTransaction])
    }

    func testMapTransactionsAlreadyExisting() throws {
        ledger.add(Transaction(metaData: TransactionMetaData(date: Date(), metaData: [MetaDataKeys.id: transactionId]), postings: []))

        // transaction exists
        var (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([testTransaction])
        XCTAssertEqual(prices, [testTransactionPrice])
        XCTAssert(transactions.isEmpty)

        // price exists as well
        try ledger.add(testTransactionPrice)
        (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([testTransaction])
        XCTAssert(prices.isEmpty)
        XCTAssert(transactions.isEmpty)

        // non merged nrwt transaction already exists
        var nrwt = testTransaction
        nrwt.transactionType = .nonResidentWithholdingTax
        nrwt.id = "tid2"
        nrwt.fxRate = fxRate
        nrwt.description = "VTI - Vanguard Index STK MKT ETF: Non-resident tax withheld at source (2.43 USD, convert to CAD @ 1.2343)"
        ledger.add(Transaction(metaData: TransactionMetaData(date: Date(), metaData: [MetaDataKeys.nrwtId: "tid2"]), postings: []))
        try ledger.add(SAccount(name: try AccountName("Expenses:t"), metaData: ["\(MetaDataKeys.prefix)\("\(nrwt.transactionType)".camelCaseToKebabCase())": accountNumber]))
        (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([nrwt])
        XCTAssert(prices.isEmpty)
        XCTAssert(transactions.isEmpty)
    }

    func testMapTransactionsNRWT() throws {
        var nrwt = testTransaction
        nrwt.transactionType = .nonResidentWithholdingTax
        nrwt.fxRate = fxRate
        nrwt.netCashAmount = "-4.86"
        nrwt.description = "VTI - Vanguard Index STK MKT ETF: Non-resident tax withheld at source (2.43 USD, convert to CAD @ 2.00)"
        try? ledger.add(SAccount(name: try AccountName("Expenses:t"), metaData: ["\(MetaDataKeys.prefix)\("\(nrwt.transactionType)".camelCaseToKebabCase())": accountNumber]))

        // nrwt not merged
        var (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([nrwt])
        var transaction = Transaction(metaData: TransactionMetaData(date: nrwt.processDate, metaData: [MetaDataKeys.id: transactionId]), postings: [
            try posting(number: nrwt.netCashAmount, price: priceAmount(commodity: "USD")), try posting(account: "Expenses:t", number: "2.43", commodity: "USD")
        ])
        XCTAssert(prices.isEmpty)
        XCTAssertEqual(transactions, [transaction])

        // nrwt merged
        try ledger.add(SAccount(name: try AccountName("Income:t"), metaData: ["\(MetaDataKeys.dividendPrefix)ETF": accountNumber]))
        var dividend = nrwt
        dividend.transactionType = .dividend
        dividend.netCashAmount = "32.42"
        dividend.id = "NewID1"
        dividend.description = "VTI - Vanguard Index STK MKT ETF: 25-JUN-21 (record date) 24.0020 shares, gross 16.21 USD, convert to CAD @ – – 2.00"
        (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([nrwt, dividend])
        let meta = [MetaDataKeys.dividendShares: "24.0020", MetaDataKeys.dividendRecordDate: "2021-06-25", MetaDataKeys.id: dividend.id, MetaDataKeys.nrwtId: transactionId]
        transaction = Transaction(metaData: TransactionMetaData(date: nrwt.processDate, metaData: meta), postings: [
            try posting(account: "Income:t", number: "-16.21", commodity: "USD"),
            transaction.postings[1], try posting(number: "27.56", price: priceAmount(commodity: "USD"))
        ])
        XCTAssert(prices.isEmpty)
        XCTAssertEqual(transactions, [transaction])
    }

    func testMapTransactionsDividend() throws {
        try ledger.add(SAccount(name: try AccountName("Income:t"), metaData: ["\(MetaDataKeys.dividendPrefix)ETF": accountNumber]))
        var dividend = testTransaction
        dividend.transactionType = .dividend
        dividend.netCashAmount = "32.42"
        dividend.fxRate = fxRate
        dividend.description = "VTI - Vanguard Index STK MKT ETF: 25-JUN-21 (record date) 24.0020 shares, gross 16.21 USD, convert to CAD @ – – 2.00"

        // dividend fx
        var (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([dividend])
        var meta = [MetaDataKeys.dividendShares: "24.0020", MetaDataKeys.dividendRecordDate: "2021-06-25", MetaDataKeys.id: transactionId]
        var transaction = Transaction(metaData: TransactionMetaData(date: dividend.processDate, metaData: meta), postings: [
            try posting(number: dividend.netCashAmount, price: priceAmount(commodity: "USD")), try posting(account: "Income:t", number: "-16.21", commodity: "USD")
        ])
        XCTAssertEqual(transactions, [transaction])
        XCTAssert(prices.isEmpty)

        // dividend without fx
        dividend.description = "ZFL-BMO Long Federal Bond ETF: 25-JUN-21 (record date) 24.0020 shares"
        (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([dividend])
        transaction = Transaction(metaData: TransactionMetaData(date: dividend.processDate, metaData: meta), postings: [
            try posting(number: dividend.netCashAmount), try posting(account: "Income:t", number: "-32.42")
        ])
        XCTAssertEqual(transactions, [transaction])
        XCTAssert(prices.isEmpty)

        // dividend simple description
        dividend.description = "Dividend 123.10 CAD WSE100"
        (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([dividend])
        meta[MetaDataKeys.dividendShares] = nil
        meta[MetaDataKeys.dividendRecordDate] = nil
        transaction = Transaction(metaData: TransactionMetaData(date: dividend.processDate, metaData: meta), postings: [
            try posting(number: dividend.netCashAmount), try posting(account: "Income:t", number: "-32.42")
        ])
        XCTAssertEqual(transactions, [transaction])
        XCTAssert(prices.isEmpty)
    }

    func testMapTransactionsTransfers() throws {
        var count = 1
        let types: [SwiftBeanCountModel.AccountType: [Wealthsimple.TransactionType]] = [
            .asset: [.deposit, .withdrawal, .paymentTransferOut, .transferIn, .transferOut, .paymentTransferIn, .referralBonus, .giveawayBonus, .refund, .contribution],
            .income: [.paymentTransferIn, .referralBonus, .giveawayBonus, .refund, .cashbackBonus, .fee, .reimbursement, .interest],
            .expense: [.paymentSpend, .fee, .reimbursement, .interest]
        ]
        for (accountType, transactionTypes) in types {
            for transactionType in transactionTypes {
                let accountName = try AccountName("\(accountType.rawValue):Test\(count)")
                try? ledger.add(SAccount(name: accountName, metaData: ["\(MetaDataKeys.prefix)\("\(transactionType)".camelCaseToKebabCase())": accountNumber]))
                var transaction = testTransaction
                transaction.transactionType = transactionType
                transaction.symbol = "CAD"
                transaction.netCashAmount = transaction.quantity
                transaction.marketPriceAmount = "1.00"

                let (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction])
                let assetPosting = Posting(accountName: accountName, amount: priceAmount(number: "-\(transaction.netCashAmount )"))
                let payee = [.fee, .reimbursement, .interest].contains(transactionType) ? "Wealthsimple" : ""
                let resultTransaction = Transaction(metaData: TransactionMetaData(date: transaction.processDate, payee: payee, metaData: [MetaDataKeys.id: transactionId]),
                                                    postings: [try posting(number: transaction.netCashAmount), assetPosting])
                XCTAssert(prices.isEmpty)
                XCTAssertEqual(transactions, [resultTransaction])

                count += 1
            }
            ledger = Ledger()
            try ledger.add(SAccount(name: cashAccountName, metaData: [MetaDataKeys.importerType: MetaData.importerType, MetaDataKeys.number: accountNumber]))
            try ledger.add(Commodity(symbol: "ETF"))
            try ledger.add(Commodity(symbol: "CAD"))
        }
    }

    func testMapTransactionsContributionRoom() throws {
        let roomCommodity = "TFSA.ROOM"
        let assetAccountName = try AccountName("Assets:ContributionRoom")
        let expenseAccountName = try AccountName("Expenses:ContributionRoom")
        var transaction = testTransaction
        transaction.transactionType = .contribution
        transaction.symbol = "CAD"
        transaction.netCashAmount = transaction.quantity
        transaction.marketPriceAmount = "1.00"
        try? ledger.add(SAccount(name: try AccountName("Assets:Cash"),
                                 metaData: ["\(MetaDataKeys.prefix)\("\(transaction.transactionType)".camelCaseToKebabCase())": accountNumber]))
        try? ledger.add(SAccount(name: assetAccountName, commoditySymbol: roomCommodity, metaData: ["\(MetaDataKeys.contributionRoom)": accountNumber]))
        try? ledger.add(SAccount(name: expenseAccountName, commoditySymbol: roomCommodity, metaData: ["\(MetaDataKeys.contributionRoom)": accountNumber]))

        let (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction])
        let resultTransaction = Transaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transactionId]),
                                            postings: [
                                                try posting(number: transaction.netCashAmount),
                                                try posting(account: "Assets:Cash", number: "-\(transaction.netCashAmount)"),
                                                Posting(accountName: assetAccountName, amount: priceAmount(number: "-\(transaction.quantity)", commodity: roomCommodity)),
                                                Posting(accountName: expenseAccountName, amount: priceAmount(number: transaction.quantity, commodity: roomCommodity)),
                                            ])
        XCTAssert(prices.isEmpty)
        XCTAssertEqual(transactions, [resultTransaction])
    }

    func testSplitTransactions() throws {
        var transaction1 = testTransaction
        transaction1.transactionType = .stockDistribution
        var transaction2 = testTransaction
        transaction2.transactionType = .stockDistribution
        transaction2.quantity = "-\(transaction2.quantity)"

        let emptyCost = try Cost(amount: nil, date: nil, label: nil)
        let resultTransaction = Transaction(metaData: TransactionMetaData(date: transaction1.processDate, metaData: [MetaDataKeys.id: transaction1.id]),
                                            postings: [
                                                try posting(account: "Assets:W:ETF", number: transaction2.quantity, commodity: transaction2.symbol, cost: emptyCost),
                                                try posting(account: "Assets:W:ETF", number: transaction1.quantity, commodity: transaction1.symbol, cost: emptyCost),
                                            ])

        let (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction1, transaction2])
        XCTAssert(prices.isEmpty)
        XCTAssertEqual(transactions, [resultTransaction])
    }

    // swiftlint:disable line_length
    private func posting(account: String = "Assets:W:Cash", number: String = "-11.76", commodity: String = "CAD", decimals: Int = 2, price: Amount? = nil, cost: Cost? = nil) throws -> Posting {
        Posting(accountName: try AccountName(account), amount: Amount(number: Decimal(string: number)!, commoditySymbol: commodity, decimalDigits: decimals), price: price, cost: cost)
    }
    // swiftlint:enable line_length

    private func priceAmount(number: String = "0.50", commodity: CommoditySymbol = "CAD", decimals: Int = 2) -> Amount {
        Amount(number: Decimal(string: number)!, commoditySymbol: commodity, decimalDigits: decimals)
    }

}
