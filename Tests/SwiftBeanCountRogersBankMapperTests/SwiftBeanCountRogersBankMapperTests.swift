import Foundation
import RogersBankDownloader
@testable import SwiftBeanCountRogersBankMapper
import SwiftBeanCountModel
import Testing

@Suite
struct SwiftBeanCountRogersBankMapperTests {

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    @Test
    func MapAccount() throws {
        let ledger = Ledger()
        let accountName = try AccountName("Liabilities:CC:Rogers")
        try ledger.add(Account(name: accountName, metaData: ["last-four": "4862", "importer-type": "rogers"]))
        let mapper = SwiftBeanCountRogersBankMapper(ledger: ledger)
        var account = TestAccount()
        var balance = TestAmount()
        balance.value = "205.25"
        balance.currency = "USD"
        account.currentBalance = balance
        let result = try mapper.mapAccountToBalance(account: account)
        #expect(Calendar.current.compare(result.date == to: Date(), toGranularity: .minute), .orderedSame)
        #expect(result.accountName == accountName)
        #expect(result.amount.number == Decimal(string: "-\(balance.value)")!)
        #expect(result.amount.commoditySymbol == balance.currency)
        #expect(result.amount.decimalDigits == 2)
    }

    @Test

    func MapAccountMissingAccount() throws {
        #expect(throws: RogersBankMappingError.missingAccount(lastFour: "4862")) { try try mapper.mapAccountToBalance(account: TestAccount()) }
    }

    @Test

    func MapActivitiesEmpty() throws {
        #expect(try mapper.mapActivitiesToTransactions(activities: []).isEmpty)
    }

    @Test

    func MapActivitiesNotPosted() throws {
        var activity = TestActivity()
        activity.activityStatus = .approved
        activity.activityType = .authorization
        #expect(try mapper.mapActivitiesToTransactions(activities: [TestActivity(), activity]).isEmpty)
    }

    @Test

    func MapActivitiesMissingPostingDate() throws {
        var activity = TestActivity()
        activity.activityStatus = .approved
        #expect(throws: RogersBankMappingError.missingActivityData(activity: activity, key: "postedDate")) { try try mapper.mapActivitiesToTransactions(activities: [activity]) }
    }

    @Test

    func MapActivitiesMissingReferenceNumber() throws {
        var activity = TestActivity()
        activity.activityStatus = .approved
        activity.postedDate = Date()
        activity.activityCategory = .purchase
        let mapper = SwiftBeanCountRogersBankMapper(ledger: Ledger())
        #expect(throws: RogersBankMappingError.missingActivityData(activity: activity, key: "referenceNumber")) { try try mapper.mapActivitiesToTransactions(activities: [activity]) }
    }

    @Test

    func MapActivitiesMissingAccount() throws {
        var activity = TestActivity()
        activity.activityStatus = .approved
        activity.postedDate = Date()
        let mapper = SwiftBeanCountRogersBankMapper(ledger: ledger)
        #expect(throws: RogersBankMappingError.missingAccount(lastFour: "1234")) { try try mapper.mapActivitiesToTransactions(activities: [activity]) }
        // different number
        try ledger.add(Account(name: try AccountName("Liabilities:CC:Rogers"), metaData: ["last-four": "4862", "importer-type": "rogers"]))
        #expect(throws: RogersBankMappingError.missingAccount(lastFour: "1234")) { try try mapper.mapActivitiesToTransactions(activities: [activity]) }
        // wrong type
        try ledger.add(Account(name: try AccountName("Liabilities:CC:Rogers1"), metaData: ["last-four": "1234", "importer-type": "rogers1"]))
        #expect(throws: RogersBankMappingError.missingAccount(lastFour: "1234")) { try try mapper.mapActivitiesToTransactions(activities: [activity]) }
        // no type
        try ledger.add(Account(name: try AccountName("Liabilities:CC:Rogers2"), metaData: ["last-four": "1234"]))
        #expect(throws: RogersBankMappingError.missingAccount(lastFour: "1234")) { try try mapper.mapActivitiesToTransactions(activities: [activity]) }
        // no number
        try ledger.add(Account(name: try AccountName("Liabilities:CC:Rogers3"), metaData: ["importer-type": "rogers1"]))
        #expect(throws: RogersBankMappingError.missingAccount(lastFour: "1234")) { try try mapper.mapActivitiesToTransactions(activities: [activity]) }
    }

    @Test

    func MapActivities() throws {
        let accountName = try AccountName("Liabilities:CC:Rogers")
        try ledger.add(Account(name: accountName, metaData: ["last-four": "1234", "importer-type": "rogers"]))
        var activity = TestActivity()
        activity.activityStatus = .approved
        activity.activityCategory = .purchase
        activity.postedDate = Date()
        activity.referenceNumber = "852741963"
        let amount = TestAmount(value: "2.79", currency: "USD")
        var foreign = TestForeignCurrency()
        foreign.originalAmount = amount
        activity.foreign = foreign
        let mapper = SwiftBeanCountRogersBankMapper(ledger: ledger)
        let result = try mapper.mapActivitiesToTransactions(activities: [activity])
        #expect(result.count == 1)
        let postings = [
            Posting(accountName: accountName, amount: SwiftBeanCountModel.Amount(number: Decimal(string: "-1.13")!, commoditySymbol: "CAD", decimalDigits: 2)),
            Posting(accountName: mapper.expenseAccountName,
                    amount: SwiftBeanCountModel.Amount(number: Decimal(string: "2.79")!, commoditySymbol: "USD", decimalDigits: 2),
                    price: SwiftBeanCountModel.Amount(number: Decimal(string: "1.13")!, commoditySymbol: "CAD", decimalDigits: 2))
        ]
        let transactionMetaData = TransactionMetaData(date: activity.postedDate!, narration: "Test Merchant Name", metaData: [MetaDataKeys.activityId: "852741963"])
        #expect(result[0] == Transaction(metaData: transactionMetaData, postings: postings))
    }

    @Test

    func MapActivitiesPayment() throws {
        let accountName = try AccountName("Liabilities:CC:Rogers")
        try ledger.add(Account(name: accountName, metaData: ["last-four": "1234", "importer-type": "rogers"]))
        var activity = TestActivity()
        activity.activityStatus = .approved
        activity.postedDate = Date()
        let mapper = SwiftBeanCountRogersBankMapper(ledger: ledger)
        let result = try mapper.mapActivitiesToTransactions(activities: [activity])
        #expect(result.count == 1)
        let postings = [
            Posting(accountName: accountName, amount: SwiftBeanCountModel.Amount(number: Decimal(string: "-1.13")!, commoditySymbol: "CAD", decimalDigits: 2)),
            Posting(accountName: mapper.expenseAccountName, amount: SwiftBeanCountModel.Amount(number: Decimal(string: "1.13")!, commoditySymbol: "CAD", decimalDigits: 2))
        ]
        let metaData = [MetaDataKeys.activityId: "payment-\(Self.dateFormatter.string(from: activity.postedDate!))"]
        XCTAssertEqual(result[0],
                       Transaction(metaData: TransactionMetaData(date: activity.postedDate!, narration: "Test Merchant Name", metaData: metaData), postings: postings))
    }

    @Test

    func MapActivitiesOverLimitFee() throws {
        let accountName = try AccountName("Liabilities:CC:Rogers")
        try ledger.add(Account(name: accountName, metaData: ["last-four": "1234", "importer-type": "rogers"]))
        var activity = TestActivity()
        activity.activityStatus = .approved
        activity.activityCategory = .overlimitFee
        activity.postedDate = Date()
        let mapper = SwiftBeanCountRogersBankMapper(ledger: ledger)
        let result = try mapper.mapActivitiesToTransactions(activities: [activity])
        #expect(result.count == 1)
        let postings = [
            Posting(accountName: accountName, amount: SwiftBeanCountModel.Amount(number: Decimal(string: "-1.13")!, commoditySymbol: "CAD", decimalDigits: 2)),
            Posting(accountName: mapper.expenseAccountName, amount: SwiftBeanCountModel.Amount(number: Decimal(string: "1.13")!, commoditySymbol: "CAD", decimalDigits: 2))
        ]
        let metaData: [String: String] = [MetaDataKeys.activityId: "overlimit-fee-\(Self.dateFormatter.string(from: activity.postedDate!))"]
        XCTAssertEqual(result[0],
                       Transaction(metaData: TransactionMetaData(date: activity.postedDate!, narration: "Test Merchant Name", metaData: metaData), postings: postings))
    }

    @Test

    func MapActivityDuplicate() throws {
        let accountName = try AccountName("Liabilities:CC:Rogers")
        try ledger.add(Account(name: accountName, metaData: ["last-four": "1234", "importer-type": "rogers"]))
        var activity = TestActivity()
        activity.activityStatus = .approved
        activity.activityCategory = .purchase
        activity.postedDate = Date()
        activity.referenceNumber = "852741963"
        mapper = SwiftBeanCountRogersBankMapper(ledger: ledger)
        var result = try mapper.mapActivitiesToTransactions(activities: [activity])
        #expect(result.count == 1)

        ledger.add(Transaction(metaData: TransactionMetaData(date: activity.postedDate!, narration: "Test Merchant Name", metaData: [MetaDataKeys.activityId: "852741963"]),
                               postings: []))
        mapper = SwiftBeanCountRogersBankMapper(ledger: ledger)
        result = try mapper.mapActivitiesToTransactions(activities: [activity])
        #expect(result.count == 0)
    }

}

extension RogersBankMappingError: Equatable {
    public static func == (lhs: RogersBankMappingError, rhs: RogersBankMappingError) -> Bool {
        if case let .missingAccount(lhsString) = lhs, case let .missingAccount(rhsString) = rhs {
            return lhsString == rhsString
        }
        if case let .missingActivityData(lhsActivity, lhsString) = lhs, case let .missingActivityData(rhsActivity, rhsString) = rhs {
            return (lhsActivity as! TestActivity).id == (rhsActivity as! TestActivity).id && lhsString == rhsString // swiftlint:disable:this force_cast
        }
        return false
    }
}
