// swiftlint:disable type_contents_order file_length
import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountWealthsimpleMapper
import Testing
import Wealthsimple

@Suite
struct WealthsimpleLedgerMapperTests { // swiftlint:disable:this type_body_length

    private typealias SAccount = SwiftBeanCountModel.Account

    private var mapper: WealthsimpleLedgerMapper {
        var wealthsimpleLedgerMapper = WealthsimpleLedgerMapper(ledger: ledger)
        wealthsimpleLedgerMapper.accounts = [TestAccount(number: accountNumber, id: accountId, currency: "CAD")]
        return wealthsimpleLedgerMapper
    }

    private var ledger = Ledger()

    private let transactionId = "id23"
    private let accountId = "abc123"
    private let accountNumber = "A1B2C3"
    private let fxRate = "2"
    private let cashAccountName = try! AccountName("Assets:W:Cash") // swiftlint:disable:this force_try

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
                        marketValueAmount: "11.76",
                        marketValueCurrency: "CAD",
                        netCashAmount: "-11.76",
                        netCashCurrency: "CAD",
                        processDate: Date(timeIntervalSinceReferenceDate: 5_645_145_697))
    }

    init() {
        ledger = Ledger()
        try? ledger.add(SAccount(name: cashAccountName, metaData: [MetaDataKeys.importerType: MetaData.importerType, MetaDataKeys.number: accountNumber]))
        try? ledger.add(Commodity(symbol: "ETF"))
        try? ledger.add(Commodity(symbol: "CAD"))
    }

    @Test
    func mapPositionsErrors() throws {
        // empty
        let (prices, balances) = try WealthsimpleLedgerMapper(ledger: Ledger()).mapPositionsToPriceAndBalance([])
        #expect(prices.isEmpty)
        #expect(balances.isEmpty)

        // no account set on mapper
        var position = TestPositon(accountId: accountId)
        #expect(throws: WealthsimpleConversionError.accountNotFound(accountId)) { try WealthsimpleLedgerMapper(ledger: Ledger()).mapPositionsToPriceAndBalance([position]) }

        // missing commodity
        var mapper = WealthsimpleLedgerMapper(ledger: Ledger())
        mapper.accounts = [TestAccount(number: accountNumber, id: accountId)]
        position.priceAmount = "1234"
        position.priceCurrency = "EUR"
        position.assetSymbol = "CAD"
        #expect(throws: WealthsimpleConversionError.missingCommodity("CAD")) { try mapper.mapPositionsToPriceAndBalance([position]) }

        // missing account in ledger
        let ledger = Ledger()
        try ledger.add(Commodity(symbol: "CAD"))
        mapper = WealthsimpleLedgerMapper(ledger: ledger)
        mapper.accounts = [TestAccount(number: accountNumber, id: accountId)]
        position.quantity = "9.871"
        #expect(throws: WealthsimpleConversionError.missingWealthsimpleAccount(accountNumber)) { try mapper.mapPositionsToPriceAndBalance([position]) }
    }

    @Test
    func mapPositions() throws {
        var position = TestPositon(accountId: accountId, priceAmount: "1234", priceCurrency: "EUR", quantity: "9.871")
        position.assetSymbol = "CAD"

        // currency
        var (prices, balances) = try mapper.mapPositionsToPriceAndBalance([position])
        #expect(prices.isEmpty)
        #expect(balances == [Balance(date: position.positionDate, accountName: cashAccountName, amount: priceAmount(number: "9.871", decimals: 3))])

        // non currency
        position.assetType = .exchangeTradedFund
        position.assetSymbol = "ETF"
        let price = try Price(date: position.positionDate, commoditySymbol: "ETF", amount: Amount(number: Decimal(1_234), commoditySymbol: "EUR", decimalDigits: 2))
        let balance = Balance(date: position.positionDate, accountName: try AccountName("Assets:W:ETF"), amount: priceAmount(number: "9.871", commodity: "ETF", decimals: 3))
        (prices, balances) = try mapper.mapPositionsToPriceAndBalance([position])
        #expect(prices == [price])
        #expect(balances == [balance])

        // already exists
        try ledger.add(price)
        ledger.add(balance)
        (prices, balances) = try mapper.mapPositionsToPriceAndBalance([position])
        #expect(prices.isEmpty)
        #expect(balances.isEmpty)
    }

    @Test
    func mapTransactionsErrors() throws {
        // empty
        let (prices, transactions) = try WealthsimpleLedgerMapper(ledger: Ledger()).mapTransactionsToPriceAndTransactions([])
        #expect(prices.isEmpty)
        #expect(transactions.isEmpty)

        // no account set on mapper
        var transaction = TestTransaction(accountId: accountId)
        #expect(throws: WealthsimpleConversionError.accountNotFound(accountId)) {
            try WealthsimpleLedgerMapper(ledger: Ledger()).mapTransactionsToPriceAndTransactions([transaction])
        }

        // missing account in ledger
        var mapper = WealthsimpleLedgerMapper(ledger: Ledger())
        mapper.accounts = [TestAccount(number: accountNumber, id: accountId)]
        transaction.symbol = "CAD"
        transaction.netCashAmount = "7.53"
        #expect(throws: WealthsimpleConversionError.missingWealthsimpleAccount(accountNumber)) { try mapper.mapTransactionsToPriceAndTransactions([transaction]) }

        // missing commodity
        let ledger = Ledger()
        try ledger.add(SAccount(name: cashAccountName, metaData: [MetaDataKeys.importerType: MetaData.importerType, MetaDataKeys.number: accountNumber]))
        mapper = WealthsimpleLedgerMapper(ledger: ledger)
        mapper.accounts = [TestAccount(number: accountNumber, id: accountId)]
        #expect(throws: WealthsimpleConversionError.missingCommodity("CAD")) { try mapper.mapTransactionsToPriceAndTransactions([transaction]) }

        // unsupported type
        transaction.transactionType = .hst
        #expect(throws: WealthsimpleConversionError.unsupportedTransactionType(transaction.transactionType.rawValue)) {
            try mapper.mapTransactionsToPriceAndTransactions([transaction])
        }
    }

    @Test
    func mapSpecialTransactionsErrors() throws {
        var transaction = TestTransaction(accountId: accountId)

        // nrwt invalid description
        try? ledger.add(Commodity(symbol: "CAD"))
        var nrwt = testTransaction
        nrwt.transactionType = .nonResidentWithholdingTax
        nrwt.fxRate = "1.2343"
        nrwt.description = "Garbage"
        #expect(throws: WealthsimpleConversionError.unexpectedDescription(nrwt.description)) { try mapper.mapTransactionsToPriceAndTransactions([nrwt]) }

        // only one transaction for stock split
        transaction.transactionType = .stockDistribution
        #expect(throws: WealthsimpleConversionError.unexpectedStockSplit(transaction.description)) { try mapper.mapTransactionsToPriceAndTransactions([transaction]) }
        // two buy transactions for stock split
        var split = TestTransaction(accountId: accountId)
        split.transactionType = .stockDistribution
        #expect(throws: WealthsimpleConversionError.unexpectedStockSplit(split.description)) { try mapper.mapTransactionsToPriceAndTransactions([transaction, split]) }
    }

    @Test
    func mapTransactionsBuy() throws {
        var transaction = testTransaction

        // buy
        var (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction])
        let assetPosting = Posting(accountName: try AccountName("Assets:W:ETF"),
                                   amount: Amount(number: Decimal(string: transaction.quantity)!, commoditySymbol: "ETF", decimalDigits: 2),
                                   cost: try Cost(amount: testTransactionPrice.amount, date: nil, label: nil))
        var postings = [try posting(), assetPosting]
        var resultTransaction = Transaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transactionId]), postings: postings)
        #expect(prices == [testTransactionPrice])
        #expect(transactions == [resultTransaction])

        // buy fx
        transaction.netCashCurrency = "EUR"
        transaction.netCashAmount = "-23.51"
        transaction.fxRate = fxRate
        (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction])
        postings = [try posting(number: transaction.netCashAmount, commodity: "EUR", price: priceAmount()), postings[1]]
        resultTransaction = Transaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transactionId]), postings: postings)
        #expect(prices == [testTransactionPrice])
        #expect(transactions == [resultTransaction])

    }

    @Test
    func mapTransactionsSell() throws {
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
        #expect(prices == [testTransactionPrice])
        #expect(transactions == [resultTransaction])

        // sell fx
        transaction.netCashCurrency = "EUR"
        transaction.netCashAmount = "23.51"
        transaction.fxRate = fxRate
        (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction])
        postings = [try posting(number: transaction.netCashAmount, commodity: "EUR", price: priceAmount()), postings[1]]
        resultTransaction = Transaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transactionId]), postings: postings)
        #expect(prices == [testTransactionPrice])
        #expect(transactions == [resultTransaction])
    }

    @Test
    func mapTransactionsAlreadyExisting() throws {
        ledger.add(Transaction(metaData: TransactionMetaData(date: Date(), metaData: [MetaDataKeys.id: transactionId]), postings: []))

        // transaction exists
        var (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([testTransaction])
        #expect(prices == [testTransactionPrice])
        #expect(transactions.isEmpty)

        // price exists as well
        try ledger.add(testTransactionPrice)
        (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([testTransaction])
        #expect(prices.isEmpty)
        #expect(transactions.isEmpty)

        // non merged nrwt transaction already exists
        var nrwt = testTransaction
        nrwt.transactionType = .nonResidentWithholdingTax
        nrwt.id = "tid2"
        nrwt.fxRate = fxRate
        nrwt.description = "VTI - Vanguard Index STK MKT ETF: Non-resident tax withheld at source (2.43 USD, convert to CAD @ 1.2343)"
        ledger.add(Transaction(metaData: TransactionMetaData(date: Date(), metaData: [MetaDataKeys.nrwtId: "tid2"]), postings: []))
        try ledger.add(
            SAccount(name: try AccountName("Expenses:t"), metaData: ["\(MetaDataKeys.prefix)\("\(nrwt.transactionType)".camelCaseToKebabCase())": accountNumber])
        )
        (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([nrwt])
        #expect(prices.isEmpty)
        #expect(transactions.isEmpty)
    }

    @Test
    func mapTransactionsNRWT() throws {
        var nrwt = testTransaction
        nrwt.transactionType = .nonResidentWithholdingTax
        nrwt.fxRate = fxRate
        nrwt.netCashAmount = "-4.86"
        nrwt.description = "VTI - Vanguard Index STK MKT ETF: Non-resident tax withheld at source (2.43 USD, convert to CAD @ 2.00)"
        try? ledger.add(
            SAccount(name: try AccountName("Expenses:t"), metaData: ["\(MetaDataKeys.prefix)\("\(nrwt.transactionType)".camelCaseToKebabCase())": accountNumber])
        )

        // nrwt not merged
        var (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([nrwt])
        var transaction = Transaction(metaData: TransactionMetaData(date: nrwt.processDate, metaData: [MetaDataKeys.id: transactionId]), postings: [
            try posting(number: nrwt.netCashAmount, price: priceAmount(commodity: "USD")), try posting(account: "Expenses:t", number: "2.43", commodity: "USD")
        ])
        #expect(prices.isEmpty)
        #expect(transactions == [transaction])

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
        #expect(prices.isEmpty)
        #expect(transactions == [transaction])
    }

    @Test
    func mapTransactionsDividend() throws {
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
        #expect(transactions == [transaction])
        #expect(prices.isEmpty)

        // dividend without fx
        dividend.description = "ZFL-BMO Long Federal Bond ETF: 25-JUN-21 (record date) 24.0020 shares"
        (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([dividend])
        transaction = Transaction(metaData: TransactionMetaData(date: dividend.processDate, metaData: meta), postings: [
            try posting(number: dividend.netCashAmount), try posting(account: "Income:t", number: "-32.42")
        ])
        #expect(transactions == [transaction])
        #expect(prices.isEmpty)

        // dividend simple description
        dividend.description = "Dividend 123.10 CAD WSE100"
        (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([dividend])
        meta[MetaDataKeys.dividendShares] = nil
        meta[MetaDataKeys.dividendRecordDate] = nil
        transaction = Transaction(metaData: TransactionMetaData(date: dividend.processDate, metaData: meta), postings: [
            try posting(number: dividend.netCashAmount), try posting(account: "Income:t", number: "-32.42")
        ])
        #expect(transactions == [transaction])
        #expect(prices.isEmpty)
    }

    @Test
    func mapTransactionsStockDividend() throws {
        var transaction = testTransaction
        transaction.transactionType = .stockDividend

        let accountName = try AccountName("Income:Dividend:ETF")
        try ledger.add(SAccount(name: accountName, metaData: ["\(MetaDataKeys.dividendPrefix)ETF": accountNumber]))

        let (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction])
        let postings = [
            Posting(accountName: accountName, amount: Amount(number: -Decimal(string: transaction.marketValueAmount)!, commoditySymbol: "CAD", decimalDigits: 2)),
            Posting(accountName: try AccountName("Assets:W:ETF"),
                    amount: Amount(number: Decimal(string: transaction.quantity)!, commoditySymbol: "ETF", decimalDigits: 2),
                    cost: try Cost(amount: testTransactionPrice.amount, date: nil, label: nil))
        ]
        let resultTransaction = Transaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transactionId]), postings: postings)
        #expect(prices == [testTransactionPrice])
        #expect(transactions == [resultTransaction])
    }

    @Test(arguments: zip(
        [SwiftBeanCountModel.AccountType.asset, .income, .expense],
        [
            [
                Wealthsimple.TransactionType.deposit,
                .withdrawal,
                .paymentTransferOut,
                .transferIn,
                .transferOut,
                .paymentTransferIn,
                .referralBonus,
                .giveawayBonus,
                .contribution,
                .payment
            ],
            [
                .paymentTransferIn,
                .referralBonus,
                .giveawayBonus,
                .cashbackBonus,
                .fee,
                .reimbursement,
                .interest
            ],
            [
                .paymentSpend,
                .fee,
                .reimbursement,
                .interest,
                .refund,
                .purchase
            ]
        ])
    )
    func mapTransactionsTransfers(accountType: SwiftBeanCountModel.AccountType, transactionTypes: [Wealthsimple.TransactionType]) throws {
        var count = 1
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
            #expect(prices.isEmpty)
            #expect(transactions == [resultTransaction])

            count += 1
        }
    }

    @Test
    func mapTransferFX() throws {
        var transaction = testTransaction
        transaction.transactionType = .purchase
        transaction.netCashCurrency = "USD"
        transaction.netCashAmount = "-11.76"
        transaction.description = "Purchase description"

        let expenseAccount = try AccountName("Expenses:PurchaseTest")
        try ledger.add(SAccount(name: expenseAccount, metaData: ["\(MetaDataKeys.prefix)\("\(transaction.transactionType)".camelCaseToKebabCase())": accountNumber]))

        let (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction])

        let posting1 = try posting(number: transaction.netCashAmount, commodity: "USD")
        let posting2 = try Posting(accountName: expenseAccount,
                                   amount: Amount(number: Decimal(string: "-\(transaction.quantity)")!, commoditySymbol: "ETF", decimalDigits: 2),
                                   price: priceAmount(number: "11.76", commodity: "USD"),
                                   priceType: .total)
        let result = Transaction(metaData: TransactionMetaData(date: transaction.processDate, narration: transaction.description, metaData: [MetaDataKeys.id: transactionId]),
                                 postings: [posting1, posting2])
        #expect(prices.isEmpty)
        #expect(transactions == [result])
    }

    @Test
    func mapTransferAllowFXFalseButFXPresent() throws {
        var transaction = testTransaction
        transaction.transactionType = .payment
        transaction.netCashCurrency = "USD"
        transaction.netCashAmount = "-11.76"

        let assetAccount = try AccountName("Assets:PaymentTest")
        try ledger.add(SAccount(name: assetAccount, metaData: ["\(MetaDataKeys.prefix)\("\(transaction.transactionType)".camelCaseToKebabCase())": accountNumber]))

        let (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction])

        let posting1 = try posting(number: transaction.netCashAmount, commodity: "USD")
        let posting2 = Posting(accountName: assetAccount,
                               amount: Amount(number: Decimal(string: "11.76")!, commoditySymbol: "USD", decimalDigits: 2))
        let result = Transaction(metaData: TransactionMetaData(date: transaction.processDate, metaData: [MetaDataKeys.id: transactionId]),
                                 postings: [posting1, posting2])
        #expect(prices.isEmpty)
        #expect(transactions == [result])
    }

    @Test
    func mapTransactionsContributionRoom() throws {
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
        #expect(prices.isEmpty)
        #expect(transactions == [resultTransaction])
    }

    @Test
    func mapTransactionsStockLoanTypesAreIgnored() throws {
        var transaction = testTransaction

        // Test .stockLoanBorrow
        transaction.transactionType = .stockLoanBorrow
        var (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction])
        #expect(prices.isEmpty)
        #expect(transactions.isEmpty)

        // Test .stockLoanReturn
        transaction.transactionType = .stockLoanReturn
        (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction])
        #expect(prices.isEmpty)
        #expect(transactions.isEmpty)
    }

    @Test
    func splitTransactions() throws {
        var transaction1 = testTransaction
        transaction1.transactionType = .stockDistribution
        var transaction2 = testTransaction
        transaction2.transactionType = .stockDistribution
        transaction2.quantity = "-\(transaction2.quantity)"
        transaction2.marketValueAmount = "-\(transaction2.marketValueAmount)"

        let emptyCost = try Cost(amount: nil, date: nil, label: nil)
        let resultTransaction = Transaction(metaData: TransactionMetaData(date: transaction1.processDate, metaData: [MetaDataKeys.id: transaction1.id]),
                                            postings: [
                                                try posting(account: "Assets:W:ETF", number: transaction2.quantity, commodity: transaction2.symbol, cost: emptyCost),
                                                try posting(account: "Assets:W:ETF", number: transaction1.quantity, commodity: transaction1.symbol, cost: emptyCost),
                                            ])

        let (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction1, transaction2])
        #expect(prices.isEmpty)
        #expect(transactions == [resultTransaction])
    }

    @Test
    func splitTransactionsDifferentCommodities() throws {
        try? ledger.add(Commodity(symbol: "ETF2"))

        var transaction1 = testTransaction
        transaction1.transactionType = .stockDistribution
        transaction1.symbol = "ETF2"
        var transaction2 = testTransaction
        transaction2.transactionType = .stockDistribution
        transaction2.quantity = "-\(transaction2.quantity)"
        transaction2.marketValueAmount = "-\(transaction2.marketValueAmount)"

        let emptyCost = try Cost(amount: nil, date: nil, label: nil)
        let cost = try Cost(amount: transaction2.marketPrice, date: nil, label: nil)
        let resultTransaction = Transaction(metaData: TransactionMetaData(date: transaction1.processDate, metaData: [MetaDataKeys.id: transaction1.id]),
                                            postings: [
                                                try posting(account: "Assets:W:ETF", number: transaction2.quantity, commodity: transaction2.symbol, cost: emptyCost),
                                                try posting(account: "Assets:W:ETF2", number: transaction1.quantity, commodity: transaction1.symbol, cost: cost),
                                            ])

        let (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction1, transaction2])
        #expect(prices.isEmpty)
        #expect(transactions == [resultTransaction])
    }

    @Test
    func mapCashbackTransactionsMerge() throws {
        let incomeAccount = try AccountName("Income:Cashback")
        try ledger.add(SAccount(name: incomeAccount, metaData: ["\(MetaDataKeys.prefix)cashback-bonus": accountNumber]))

        let date = Date(timeIntervalSinceReferenceDate: 5_645_145_697)
        let description = "Cashback credit paid at 2026-01-26 for $12.6800"

        // Three transactions with same date and description: 2 positive (adding money) and 1 negative (removing money)
        let transaction1 = cashbackTransaction(id: "transaction-idstring1", quantity: "-12.68", netCash: "-12.68", date: date, description: description)
        let transaction2 = cashbackTransaction(id: "transaction-idstring2", quantity: "12.68", netCash: "12.68", date: date, description: description)
        let transaction3 = cashbackTransaction(id: "transaction-idstring3", quantity: "12.68", netCash: "12.68", date: date, description: description)

        let (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction1, transaction2, transaction3])

        // Should be merged into a single transaction with all three IDs space-separated
        // The result should be the positive transaction (adding money to assets)
        let mergedId = "transaction-idstring1 transaction-idstring2 transaction-idstring3"
        let expectedTransaction = Transaction(
            metaData: TransactionMetaData(date: date, metaData: [MetaDataKeys.id: mergedId]),
            postings: [
                try posting(number: "12.68"),
                Posting(accountName: incomeAccount, amount: priceAmount(number: "-12.68"))
            ]
        )

        #expect(prices.isEmpty)
        #expect(transactions.count == 1)
        #expect(transactions.first?.metaData.metaData[MetaDataKeys.id] == mergedId)
        #expect(transactions == [expectedTransaction])
    }

    @Test
    func mapCashbackTransactionsSingle() throws {
        let incomeAccount = try AccountName("Income:Cashback")
        try ledger.add(SAccount(name: incomeAccount, metaData: ["\(MetaDataKeys.prefix)cashback-bonus": accountNumber]))

        let date = Date(timeIntervalSinceReferenceDate: 5_645_145_697)
        let transaction = cashbackTransaction(id: "single-cashback-id", quantity: "10.0", netCash: "10.0", date: date, description: "Single cashback")

        let (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction])

        // Single transaction should not be merged, just have its own ID
        let expectedTransaction = Transaction(
            metaData: TransactionMetaData(date: date, metaData: [MetaDataKeys.id: "single-cashback-id"]),
            postings: [
                try posting(number: "10.0"),
                Posting(accountName: incomeAccount, amount: priceAmount(number: "-10.0"))
            ]
        )

        #expect(prices.isEmpty)
        #expect(transactions.count == 1)
        #expect(transactions.first?.metaData.metaData[MetaDataKeys.id] == "single-cashback-id")
        #expect(transactions == [expectedTransaction])
    }

    @Test
    func mapCashbackTransactionsDifferentAmounts() throws {
        let incomeAccount = try AccountName("Income:Cashback")
        try ledger.add(SAccount(name: incomeAccount, metaData: ["\(MetaDataKeys.prefix)cashback-bonus": accountNumber]))

        let date = Date(timeIntervalSinceReferenceDate: 5_645_145_697)
        // Two transactions on same day with empty description but different amounts should not be merged
        let transaction1 = cashbackTransaction(id: "cashback-id-1", quantity: "10.0", netCash: "10.0", date: date, description: "")
        let transaction2 = cashbackTransaction(id: "cashback-id-2", quantity: "15.0", netCash: "15.0", date: date, description: "")

        let (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction1, transaction2])

        // Should have two separate transactions since amounts are different
        #expect(prices.isEmpty)
        #expect(transactions.count == 2)
        let transaction1Id = transactions[0].metaData.metaData[MetaDataKeys.id]
        let transaction2Id = transactions[1].metaData.metaData[MetaDataKeys.id]
        #expect((transaction1Id == "cashback-id-1" && transaction2Id == "cashback-id-2") || (transaction1Id == "cashback-id-2" && transaction2Id == "cashback-id-1"))
    }

    @Test
    func mapCashbackTransactionsWrongPattern() throws {
        let incomeAccount = try AccountName("Income:Cashback")
        try ledger.add(SAccount(name: incomeAccount, metaData: ["\(MetaDataKeys.prefix)cashback-bonus": accountNumber]))

        let date = Date(timeIntervalSinceReferenceDate: 5_645_145_697)
        let description = "Cashback credit"
        // Three positive transactions - wrong pattern (should be 2 positive + 1 negative)
        let transaction1 = cashbackTransaction(id: "cashback-id-1", quantity: "10.0", netCash: "10.0", date: date, description: description)
        let transaction2 = cashbackTransaction(id: "cashback-id-2", quantity: "10.0", netCash: "10.0", date: date, description: description)
        let transaction3 = cashbackTransaction(id: "cashback-id-3", quantity: "10.0", netCash: "10.0", date: date, description: description)

        let (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction1, transaction2, transaction3])

        // Should NOT merge since pattern is wrong (all positive instead of 2 positive + 1 negative)
        // Should return all 3 transactions individually
        #expect(prices.isEmpty)
        #expect(transactions.count == 3)
        // Each should have its own ID, not merged
        let ids = transactions.compactMap { $0.metaData.metaData[MetaDataKeys.id] }
        #expect(ids.contains("cashback-id-1"))
        #expect(ids.contains("cashback-id-2"))
        #expect(ids.contains("cashback-id-3"))
    }

    @Test
    func mapCashbackTransactionsIDOrdering() throws {
        let incomeAccount = try AccountName("Income:Cashback")
        try ledger.add(SAccount(name: incomeAccount, metaData: ["\(MetaDataKeys.prefix)cashback-bonus": accountNumber]))

        let date = Date(timeIntervalSinceReferenceDate: 5_645_145_697)
        let description = "Cashback credit paid at 2026-01-26"

        // Three transactions with IDs in non-alphabetical order
        // IDs: "id-charlie", "id-alpha", "id-bravo"
        let transaction1 = cashbackTransaction(id: "id-charlie", quantity: "-10.0", netCash: "-10.0", date: date, description: description)
        let transaction2 = cashbackTransaction(id: "id-alpha", quantity: "10.0", netCash: "10.0", date: date, description: description)
        let transaction3 = cashbackTransaction(id: "id-bravo", quantity: "10.0", netCash: "10.0", date: date, description: description)

        let (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transaction1, transaction2, transaction3])

        // Should be merged with IDs sorted alphabetically
        #expect(prices.isEmpty)
        #expect(transactions.count == 1)
        // IDs should be sorted: "id-alpha id-bravo id-charlie"
        let mergedId = transactions.first?.metaData.metaData[MetaDataKeys.id]
        #expect(mergedId == "id-alpha id-bravo id-charlie")
    }

    @Test
    func mapTransferTransactionsMerge() throws {
        let setup = try setupCrossAccountTransfer()
        let date = Date(timeIntervalSinceReferenceDate: 5_645_145_697)
        let description = "Transfer from \(setup.outAccountNumber) to \(setup.inAccountNumber)"
        var transferIn = transferTransaction(id: "transaction-idPlaceholder1", transactionType: .transferIn, amount: "1500.0", date: date, description: description)
        transferIn.accountId = setup.inAccountId
        var transferOut = transferTransaction(id: "transaction-idPlaceholder2", transactionType: .transferOut, amount: "-1500.0", date: date, description: description)
        transferOut.accountId = setup.outAccountId
        let (prices, transactions) = try setup.mapper.mapTransactionsToPriceAndTransactions([transferIn, transferOut])
        let mergedId = "transaction-idPlaceholder1 transaction-idPlaceholder2"
        let expectedTransaction = Transaction(
            metaData: TransactionMetaData(date: date, metaData: [MetaDataKeys.id: mergedId]),
            postings: [
                try posting(account: "Assets:W:Cash:In", number: "1500.0"),
                Posting(accountName: setup.transferInAccount, amount: priceAmount(number: "-1500.0", decimals: 2))
            ]
        )
        #expect(prices.isEmpty)
        #expect(transactions.count == 1)
        #expect(transactions.first == expectedTransaction)
    }

    @Test
    func mapTransferTransactionsSingle() throws {
        let transferAccount = try AccountName("Assets:Transfer")
        try ledger.add(SAccount(name: transferAccount, metaData: ["\(MetaDataKeys.prefix)transfer-in": accountNumber]))

        let date = Date(timeIntervalSinceReferenceDate: 5_645_145_697)
        let transferIn = transferTransaction(
            id: "single-transfer-id",
            transactionType: .transferIn,
            amount: "500.0",
            date: date,
            description: "Single transfer"
        )

        let (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transferIn])

        // Single transaction should not be merged, just have its own ID
        let expectedTransaction = Transaction(
            metaData: TransactionMetaData(date: date, metaData: [MetaDataKeys.id: "single-transfer-id"]),
            postings: [
                try posting(number: "500.0"),
                Posting(accountName: transferAccount, amount: priceAmount(number: "-500.0", decimals: 2))
            ]
        )

        #expect(prices.isEmpty)
        #expect(transactions.count == 1)
        #expect(transactions.first == expectedTransaction)
    }

    @Test
    func mapTransferTransactionsDifferentDescriptions() throws {
        let transferAccount = try AccountName("Assets:Transfer")
        try ledger.add(SAccount(name: transferAccount, metaData: ["\(MetaDataKeys.prefix)transfer-in": accountNumber]))

        let date = Date(timeIntervalSinceReferenceDate: 5_645_145_697)
        // Two transactions with same amount and date but different descriptions should not be merged
        let transferIn = transferTransaction(
            id: "transfer-id-1",
            transactionType: .transferIn,
            amount: "500.0",
            date: date,
            description: "Transfer to Account A"
        )
        let transferOut = transferTransaction(
            id: "transfer-id-2",
            transactionType: .transferOut,
            amount: "-500.0",
            date: date,
            description: "Transfer to Account B"
        )

        let (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transferIn, transferOut])

        // Should have two separate transactions since descriptions are different
        #expect(prices.isEmpty)
        #expect(transactions.count == 2)
        let transaction1Id = transactions[0].metaData.metaData[MetaDataKeys.id]
        let transaction2Id = transactions[1].metaData.metaData[MetaDataKeys.id]
        #expect((transaction1Id == "transfer-id-1" && transaction2Id == "transfer-id-2") || (transaction1Id == "transfer-id-2" && transaction2Id == "transfer-id-1"))
    }

    @Test
    func mapTransferTransactionsDifferentDates() throws {
        let transferAccount = try AccountName("Assets:Transfer")
        try ledger.add(SAccount(name: transferAccount, metaData: ["\(MetaDataKeys.prefix)transfer-in": accountNumber]))

        let date1 = Date(timeIntervalSinceReferenceDate: 5_645_145_697)
        let date2 = Date(timeIntervalSinceReferenceDate: 5_645_145_798)
        let description = "Transfer from CASH_DD to NON_REGISTERED"
        // Two transactions with same description and amount but different dates should not be merged
        let transferIn = transferTransaction(id: "transfer-id-1", transactionType: .transferIn, amount: "500.0", date: date1, description: description)
        let transferOut = transferTransaction(id: "transfer-id-2", transactionType: .transferOut, amount: "-500.0", date: date2, description: description)

        let (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transferIn, transferOut])

        // Should have two separate transactions since dates are different
        #expect(prices.isEmpty)
        #expect(transactions.count == 2)
        let transaction1Id = transactions[0].metaData.metaData[MetaDataKeys.id]
        let transaction2Id = transactions[1].metaData.metaData[MetaDataKeys.id]
        #expect((transaction1Id == "transfer-id-1" && transaction2Id == "transfer-id-2") || (transaction1Id == "transfer-id-2" && transaction2Id == "transfer-id-1"))
    }

    @Test
    func mapTransferTransactionsDifferentAmounts() throws {
        let transferAccount = try AccountName("Assets:Transfer")
        try ledger.add(SAccount(name: transferAccount, metaData: ["\(MetaDataKeys.prefix)transfer-in": accountNumber]))

        let date = Date(timeIntervalSinceReferenceDate: 5_645_145_697)
        let description = "Transfer from CASH_DD to NON_REGISTERED"
        // Two transactions with same date and description but different amounts should not be merged
        let transferIn = transferTransaction(id: "transfer-id-1", transactionType: .transferIn, amount: "500.0", date: date, description: description)
        let transferOut = transferTransaction(id: "transfer-id-2", transactionType: .transferOut, amount: "-600.0", date: date, description: description)

        let (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transferIn, transferOut])

        // Should have two separate transactions since amounts are different
        #expect(prices.isEmpty)
        #expect(transactions.count == 2)
        let transaction1Id = transactions[0].metaData.metaData[MetaDataKeys.id]
        let transaction2Id = transactions[1].metaData.metaData[MetaDataKeys.id]
        #expect((transaction1Id == "transfer-id-1" && transaction2Id == "transfer-id-2") || (transaction1Id == "transfer-id-2" && transaction2Id == "transfer-id-1"))
    }

    @Test
    func mapTransferTransactionsIDOrdering() throws {
        let setup = try setupCrossAccountTransfer()
        let date = Date(timeIntervalSinceReferenceDate: 5_645_145_697)
        let description = "Transfer from \(setup.outAccountNumber) to \(setup.inAccountNumber)"
        var transferIn = transferTransaction(id: "id-zebra", transactionType: .transferIn, amount: "500.0", date: date, description: description)
        transferIn.accountId = setup.inAccountId
        var transferOut = transferTransaction(id: "id-alpha", transactionType: .transferOut, amount: "-500.0", date: date, description: description)
        transferOut.accountId = setup.outAccountId
        let (prices, transactions) = try setup.mapper.mapTransactionsToPriceAndTransactions([transferIn, transferOut])
        #expect(prices.isEmpty)
        #expect(transactions.count == 1)
        let mergedId = transactions.first?.metaData.metaData[MetaDataKeys.id]
        #expect(mergedId == "id-alpha id-zebra")
    }

    @Test
    func mapTransferTransactionsWrongPattern() throws {
        let transferAccount = try AccountName("Assets:Transfer")
        try ledger.add(SAccount(name: transferAccount, metaData: ["\(MetaDataKeys.prefix)transfer-in": accountNumber]))

        let date = Date(timeIntervalSinceReferenceDate: 5_645_145_697)
        let description = "Transfer from CASH_DD to NON_REGISTERED"
        // Two transferIn transactions - wrong pattern (should be 1 transferIn + 1 transferOut)
        let transferIn1 = transferTransaction(id: "transfer-id-1", transactionType: .transferIn, amount: "500.0", date: date, description: description)
        let transferIn2 = transferTransaction(id: "transfer-id-2", transactionType: .transferIn, amount: "500.0", date: date, description: description)

        let (prices, transactions) = try mapper.mapTransactionsToPriceAndTransactions([transferIn1, transferIn2])

        // Should NOT merge since pattern is wrong (both are transferIn instead of 1 in + 1 out)
        // Should return both transactions individually
        #expect(prices.isEmpty)
        #expect(transactions.count == 2)
        // Each should have its own ID, not merged
        let ids = transactions.compactMap { $0.metaData.metaData[MetaDataKeys.id] }
        #expect(ids.contains("transfer-id-1"))
        #expect(ids.contains("transfer-id-2"))
    }

    private struct CrossAccountSetup {
        let mapper: WealthsimpleLedgerMapper
        let inAccountId: String
        let inAccountNumber: String
        let outAccountId: String
        let outAccountNumber: String
        let transferInAccount: AccountName
    }

    private func transferTransaction(
        id: String,
        transactionType: Wealthsimple.TransactionType,
        amount: String,
        date: Date,
        description: String
    ) -> TestTransaction {
        TestTransaction(
            id: id,
            accountId: accountId,
            transactionType: transactionType,
            description: description,
            symbol: "CAD",
            quantity: amount,
            marketPriceAmount: "1.0",
            marketPriceCurrency: "CAD",
            marketValueAmount: amount.replacingOccurrences(of: "-", with: ""),
            marketValueCurrency: "CAD",
            netCashAmount: amount,
            netCashCurrency: "CAD",
            fxRate: "1.0",
            processDate: date
        )
    }

    private func cashbackTransaction(id: String, quantity: String, netCash: String, date: Date, description: String) -> TestTransaction {
        TestTransaction(
            id: id,
            accountId: accountId,
            transactionType: .cashbackBonus,
            description: description,
            symbol: "CAD",
            quantity: quantity,
            marketPriceAmount: "1.0",
            marketPriceCurrency: "CAD",
            marketValueAmount: quantity.replacingOccurrences(of: "-", with: ""),
            marketValueCurrency: "CAD",
            netCashAmount: netCash,
            netCashCurrency: "CAD",
            fxRate: "1.0",
            processDate: date
        )
    }

    private func posting(
        account: String = "Assets:W:Cash", number: String = "-11.76", commodity: String = "CAD", decimals: Int = 2, price: Amount? = nil, cost: Cost? = nil
    ) throws -> Posting {
        Posting(accountName: try AccountName(account),
                amount: Amount(number: Decimal(string: number)!, commoditySymbol: commodity, decimalDigits: decimals),
                price: price,
                cost: cost)
    }

    private func priceAmount(number: String = "0.50", commodity: CommoditySymbol = "CAD", decimals: Int = 2) -> Amount {
        Amount(number: Decimal(string: number)!, commoditySymbol: commodity, decimalDigits: decimals)
    }

    private func setupCrossAccountTransfer() throws -> CrossAccountSetup {
        let inAccountId = "account-in-id"
        let inAccountNumber = "NON_REGISTERED_123"
        let outAccountId = "account-out-id"
        let outAccountNumber = "CASH_DD_456"
        var testMapper = WealthsimpleLedgerMapper(ledger: ledger)
        testMapper.accounts = [
            TestAccount(number: inAccountNumber, id: inAccountId, currency: "CAD"),
            TestAccount(number: outAccountNumber, id: outAccountId, currency: "CAD")
        ]
        let cashInAccount = try AccountName("Assets:W:Cash:In")
        let cashOutAccount = try AccountName("Assets:W:Cash:Out")
        try ledger.add(SAccount(name: cashInAccount, metaData: [MetaDataKeys.importerType: MetaData.importerType, MetaDataKeys.number: inAccountNumber]))
        try ledger.add(SAccount(name: cashOutAccount, metaData: [MetaDataKeys.importerType: MetaData.importerType, MetaDataKeys.number: outAccountNumber]))
        let transferInAccount = try AccountName("Assets:Transfer:In")
        try ledger.add(SAccount(name: transferInAccount, metaData: ["\(MetaDataKeys.prefix)transfer-in": inAccountNumber]))
        return CrossAccountSetup(
            mapper: testMapper,
            inAccountId: inAccountId,
            inAccountNumber: inAccountNumber,
            outAccountId: outAccountId,
            outAccountNumber: outAccountNumber,
            transferInAccount: transferInAccount
        )
    }

}
// swiftlint:enable type_contents_order file_length
