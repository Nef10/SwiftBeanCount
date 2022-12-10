import RogersBankDownloader
import SwiftBeanCountModel
@testable import SwiftBeanCountRogersBankMapper
import XCTest

final class SwiftBeanCountRogersBankMapperTests: XCTestCase {

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    private var ledger = Ledger()
    private var mapper: SwiftBeanCountRogersBankMapper!

    override func setUpWithError() throws {
        ledger = Ledger()
        mapper = SwiftBeanCountRogersBankMapper(ledger: ledger)
        try super.setUpWithError()
    }

    func testMapAccount() throws {
        let accountName = try AccountName("Liabilities:CC:Rogers")
        try ledger.add(Account(name: accountName, metaData: ["last-four": "4862", "importer-type": "rogers"]))
        let mapper = SwiftBeanCountRogersBankMapper(ledger: ledger)
        var account = TestAccount()
        var balance = TestAmount()
        balance.value = "205.25"
        balance.currency = "USD"
        account.currentBalance = balance
        let result = try mapper.mapAccountToBalance(account: account)
        XCTAssertEqual(Calendar.current.compare(result.date, to: Date(), toGranularity: .minute), .orderedSame)
        XCTAssertEqual(result.accountName, accountName)
        XCTAssertEqual(result.amount.number, Decimal(string: "-\(balance.value)")!)
        XCTAssertEqual(result.amount.commoditySymbol, balance.currency)
        XCTAssertEqual(result.amount.decimalDigits, 2)
    }

    func testMapAccountMissingAccount() throws {
        assert(try mapper.mapAccountToBalance(account: TestAccount()), throws: RogersBankMappingError.missingAccount(lastFour: "4862"))
    }

    func testMapActivitiesEmpty() throws {
        XCTAssert(try mapper.mapActivitiesToTransactions(activities: []).isEmpty)
    }

    func testMapActivitiesNotPosted() throws {
        var activity = TestActivity()
        activity.activityStatus = .approved
        activity.activityType = .authorization
        XCTAssert(try mapper.mapActivitiesToTransactions(activities: [TestActivity(), activity]).isEmpty)
    }

    func testMapActivitiesMissingPostingDate() throws {
        var activity = TestActivity()
        activity.activityStatus = .approved
        assert(try mapper.mapActivitiesToTransactions(activities: [activity]), throws: RogersBankMappingError.missingActivityData(activity: activity, key: "postedDate"))
    }

    func testMapActivitiesMissingReferenceNumber() throws {
        var activity = TestActivity()
        activity.activityStatus = .approved
        activity.postedDate = Date()
        activity.activityCategory = .purchase
        let mapper = SwiftBeanCountRogersBankMapper(ledger: Ledger())
        assert(try mapper.mapActivitiesToTransactions(activities: [activity]), throws: RogersBankMappingError.missingActivityData(activity: activity, key: "referenceNumber"))
    }

    func testMapActivitiesMissingAccount() throws {
        var activity = TestActivity()
        activity.activityStatus = .approved
        activity.postedDate = Date()
        let mapper = SwiftBeanCountRogersBankMapper(ledger: ledger)
        assert(try mapper.mapActivitiesToTransactions(activities: [activity]), throws: RogersBankMappingError.missingAccount(lastFour: "1234"))
        // different number
        try ledger.add(Account(name: try AccountName("Liabilities:CC:Rogers"), metaData: ["last-four": "4862", "importer-type": "rogers"]))
        assert(try mapper.mapActivitiesToTransactions(activities: [activity]), throws: RogersBankMappingError.missingAccount(lastFour: "1234"))
        // wrong type
        try ledger.add(Account(name: try AccountName("Liabilities:CC:Rogers1"), metaData: ["last-four": "1234", "importer-type": "rogers1"]))
        assert(try mapper.mapActivitiesToTransactions(activities: [activity]), throws: RogersBankMappingError.missingAccount(lastFour: "1234"))
        // no type
        try ledger.add(Account(name: try AccountName("Liabilities:CC:Rogers2"), metaData: ["last-four": "1234"]))
        assert(try mapper.mapActivitiesToTransactions(activities: [activity]), throws: RogersBankMappingError.missingAccount(lastFour: "1234"))
        // no number
        try ledger.add(Account(name: try AccountName("Liabilities:CC:Rogers3"), metaData: ["importer-type": "rogers1"]))
        assert(try mapper.mapActivitiesToTransactions(activities: [activity]), throws: RogersBankMappingError.missingAccount(lastFour: "1234"))
    }

    func testMapActivities() throws {
        let accountName = try AccountName("Liabilities:CC:Rogers")
        try ledger.add(Account(name: accountName, metaData: ["last-four": "1234", "importer-type": "rogers"]))
        var activity1 = TestActivity()
        activity1.activityStatus = .approved
        activity1.postedDate = Date()
        var activity2 = TestActivity()
        activity2.activityStatus = .approved
        activity2.activityCategory = .purchase
        activity2.postedDate = Date()
        activity2.referenceNumber = "852741963"
        let amount = TestAmount(value: "2.79", currency: "USD")
        var foreign = TestForeignCurrency()
        foreign.originalAmount = amount
        activity2.foreign = foreign
        let mapper = SwiftBeanCountRogersBankMapper(ledger: ledger)
        let result = try mapper.mapActivitiesToTransactions(activities: [activity1, activity2])
        XCTAssertEqual(result.count, 2)
        var postings = [
            Posting(accountName: accountName, amount: SwiftBeanCountModel.Amount(number: Decimal(string: "-1.13")!, commoditySymbol: "CAD", decimalDigits: 2)),
            Posting(accountName: mapper.expenseAccountName, amount: SwiftBeanCountModel.Amount(number: Decimal(string: "1.13")!, commoditySymbol: "CAD", decimalDigits: 2))
        ]
        let metaData = [MetaDataKeys.activityId: "payment-\(Self.dateFormatter.string(from: activity1.postedDate!))"]
        XCTAssertEqual(result[0],
                       Transaction(metaData: TransactionMetaData(date: activity1.postedDate!, narration: "Test Merchant Name", metaData: metaData), postings: postings))
        postings[1] = Posting(accountName: mapper.expenseAccountName,
                              amount: SwiftBeanCountModel.Amount(number: Decimal(string: "2.79")!, commoditySymbol: "USD", decimalDigits: 2),
                              price: SwiftBeanCountModel.Amount(number: Decimal(string: "1.13")!, commoditySymbol: "CAD", decimalDigits: 2))
        let transactionMetaData = TransactionMetaData(date: activity2.postedDate!, narration: "Test Merchant Name", metaData: [MetaDataKeys.activityId: "852741963"])
        XCTAssertEqual(result[1], Transaction(metaData: transactionMetaData, postings: postings))
    }

    func testMapActivityDuplicate() throws {
        let accountName = try AccountName("Liabilities:CC:Rogers")
        try ledger.add(Account(name: accountName, metaData: ["last-four": "1234", "importer-type": "rogers"]))
        var activity = TestActivity()
        activity.activityStatus = .approved
        activity.activityCategory = .purchase
        activity.postedDate = Date()
        activity.referenceNumber = "852741963"
        mapper = SwiftBeanCountRogersBankMapper(ledger: ledger)
        var result = try mapper.mapActivitiesToTransactions(activities: [activity])
        XCTAssertEqual(result.count, 1)

        ledger.add(Transaction(metaData: TransactionMetaData(date: activity.postedDate!, narration: "Test Merchant Name", metaData: [MetaDataKeys.activityId: "852741963"]),
                               postings: []))
        mapper = SwiftBeanCountRogersBankMapper(ledger: ledger)
        result = try mapper.mapActivitiesToTransactions(activities: [activity])
        XCTAssertEqual(result.count, 0)
    }

}

extension RogersBankMappingError: Equatable {
    public static func == (lhs: RogersBankMappingError, rhs: RogersBankMappingError) -> Bool {
        if case let .missingAccount(lhsString) = lhs, case let .missingAccount(rhsString) = rhs {
            return lhsString == rhsString
        } else if case let .missingActivityData(lhsActivity, lhsString) = lhs, case let .missingActivityData(rhsActivity, rhsString) = rhs {
            return (lhsActivity as! TestActivity).id == (rhsActivity as! TestActivity).id && lhsString == rhsString // swiftlint:disable:this force_cast
        }
        return false
    }
}
