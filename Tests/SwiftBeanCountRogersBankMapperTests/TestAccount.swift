import Foundation
import RogersBankDownloader
@testable import SwiftBeanCountRogersBankMapper

struct TestAmount: RogersBankDownloader.Amount {
    var value: String = "1.13"
    var currency: String = "CAD"
}

struct TestForeignCurrency: ForeignCurrency {
    var exchangeFee: Amount? = TestAmount()
    var conversionMarkupRate: Float? = 0.025
    var conversionRate: Float? = 0.5
    var originalAmount: Amount = TestAmount()
}

struct TestMerchant: Merchant {
    var name: String = "Test Merchant Name"
    var categoryCode: String?
    var categoryDescription: String?
    var category: String = "cat string"
    var address: Address?
}

struct TestActivity: Activity {
    let id = UUID()
    var referenceNumber: String?
    var activityType: ActivityType = .transaction
    var amount: Amount = TestAmount()
    var activityStatus: ActivityStatus = .pending
    var activityCategory: ActivityCategory = .payment
    var activityClassification: String = "Class string"
    var cardNumber: String = "XXXX XXXX XXXX 1234"
    var merchant: Merchant = TestMerchant()
    var foreign: ForeignCurrency?
    var date = Date()
    var activityCategoryCode: String?
    var customerId: String = "customerId1"
    var postedDate: Date?
    var activityId: String?
}

struct TestCustomer: Customer {
    var customerId: String = "cid123"
    var cardLast4: String = "4862"
    var customerType: String = "primary"
    var firstName: String = "First"
    var lastName: String = "Last"
}

struct TestAccount: RogersBankDownloader.Account {
    var customer: Customer = TestCustomer()
    var accountId = "id123"
    var accountType = "CC"
    var paymentStatus = "OK"
    var productName = "Card"
    var productExternalCode = "WEMC"
    var accountCurrency = "CAD"
    var brandId = "Rogers"
    var openedDate = Date()
    var previousStatementDate = Date()
    var paymentDueDate = Date()
    var lastPaymentDate = Date()
    var cycleDates = [Date]()
    var currentBalance: RogersBankDownloader.Amount = TestAmount()
    var statementBalance: RogersBankDownloader.Amount = TestAmount()
    var statementDueAmount: RogersBankDownloader.Amount = TestAmount()
    var creditLimit: RogersBankDownloader.Amount = TestAmount()
    var purchasesSinceLastCycle: RogersBankDownloader.Amount?
    var lastPayment: RogersBankDownloader.Amount = TestAmount()
    var realtimeBalance: RogersBankDownloader.Amount = TestAmount()
    var cashAvailable: RogersBankDownloader.Amount = TestAmount()
    var cashLimit: RogersBankDownloader.Amount = TestAmount()
    var multiCard = false

    func downloadStatement(statement: Statement, completion: @escaping (Result<URL, DownloadError>) -> Void) {
    }

    func searchStatements(completion: @escaping (Result<[Statement], DownloadError>) -> Void) {
    }

    func downloadActivities(statementNumber: Int, completion: @escaping (Result<[Activity], DownloadError>) -> Void) {
    }
}
