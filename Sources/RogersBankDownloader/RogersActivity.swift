import Foundation

/// Customer of the bank
public protocol Customer {
    /// Internal ID
    var customerId: String { get }
    /// Last 4 digits of the credit card
    var cardLast4: String { get }
    /// Customer Type, e.g. Primary
    var customerType: String { get }
    /// First name
    var firstName: String { get }
    /// Last name
    var lastName: String { get }
}

/// Merchant
public protocol Merchant {
    /// Name
    var name: String { get }
    /// 4 digit Merchant Category Code from the payment network
    var categoryCode: String? { get }
    /// Description for the Merchant Category from the payment network
    var categoryDescription: String? { get }
    /// Broad category name, used for the icons on the site
    var category: String { get }
    /// Address of the merchant
    var address: Address? { get }
}

/// An Address
public protocol Address {
    /// City - for online transactions often not a city
    var city: String { get }
    /// State or Province
    var stateProvince: String? { get }
    /// Postal / ZIP Code
    var postalCode: String? { get }
    /// ISO Country code
    var countryCode: String { get }
}

/// Info about a transaction in an foreign currency
public protocol ForeignCurrency {
    /// Amount of fee paid
    var exchangeFee: Amount? { get }
    /// Conversion rate after embedding the exchange fee
    var conversionMarkupRate: Float? { get }
    /// Official conversion rate
    var conversionRate: Float? { get }
    /// Amount in foreign currency
    var originalAmount: Amount { get }
}

/// An amount of money
public protocol Amount {
    /// Numeric value
    var value: String { get }
    /// ISO Currency code
    var currency: String { get }
}

/// An activity on the credit card, like a authorization, transactions or payment
public protocol Activity {
    /// Reference number for posted transactions
    var referenceNumber: String? { get }
    /// Activity type, e.g. Transaction or Authorization
    var activityType: ActivityType { get }
    /// Amount charged - if transaction was in foreign currency, see foreign for the original amount
    var amount: Amount { get }
    /// Status of the transaction, e.g. approved or pending
    var activityStatus: ActivityStatus { get }
    /// Category, e.g. Purchase, Payment for Authorization
    var activityCategory: ActivityCategory { get }
    /// Activity classification
    var activityClassification: String { get }
    /// Card Number with all but the last 4 digits replaced with *
    var cardNumber: String { get }
    /// Merchant
    var merchant: Merchant { get }
    /// Foreign currency information if the transaction was in one
    var foreign: ForeignCurrency? { get }
    /// Date of the transaction
    var date: Date { get }
    /// Activity Category Code
    var activityCategoryCode: String? { get }
    /// Customer ID, see Customer.customerId
    var customerId: String { get }
    /// If the transaction is posted, the date of the posting
    var postedDate: Date? { get }
    /// Activity Id for pending transactions
    var activityId: String? { get }
}

/// Type of a credit card activity
public enum ActivityType: String, Codable {
    /// A transaction which has been posted
    case transaction = "TRANS"
    /// A pre authorization which has not been posted
    case authorization = "AUTH"
}

/// Status of a credit card transaction
public enum ActivityStatus: String, Codable {
    /// The transaction has been approved and posted
    case approved = "APPROVED"
    /// The transaction is still pending
    case pending = "PENDING"
}

/// Categorization for a credit card transaction
public enum ActivityCategory: String {
    /// A Purchase, including a refund
    case purchase = "purchase"
    /// A Payment towards the balance
    case payment = "payment"
    /// A pre authorization for a purchase
    case tokenAuthRequest = "token auth request"
    /// An authorization for an mail or phone order
    case mailOrPhoneOrder = "mail or phone order"
    /// Fee for going over the credit limit
    case overlimitFee = "overlimit fee"
    /// Return, but different from refund
    case merchantReturn = "merchant return"
}

struct RogersCustomer: Customer, Codable, Equatable {
    let customerId: String
    let cardLast4: String
    let customerType: String
    let firstName: String
    let lastName: String
}

struct RogersMerchant: Merchant, Codable, Equatable {

    enum CodingKeys: String, CodingKey {
        case name
        case categoryCode
        case categoryDescription
        case category
        case rogersAddress = "address"
    }

    let name: String
    let categoryCode: String?
    let categoryDescription: String?
    let category: String
    private let rogersAddress: RogersAddress?

    var address: Address? {
        rogersAddress
    }
}

struct RogersAddress: Address, Codable, Equatable {
    let city: String
    let stateProvince: String?
    let postalCode: String?
    let countryCode: String
}

struct RogersForeignCurrency: ForeignCurrency, Codable, Equatable {

    enum CodingKeys: String, CodingKey {
        case rogersExchangeFee = "exchangeFee"
        case conversionMarkupRate
        case conversionRate
        case rogersOriginalAmount = "originalAmount"
    }

    let conversionMarkupRate: Float?
    let conversionRate: Float?
    private let rogersExchangeFee: RogersAmount?
    private let rogersOriginalAmount: RogersAmount

    var exchangeFee: Amount? {
        rogersExchangeFee
    }
    var originalAmount: Amount {
        rogersOriginalAmount
    }
}

struct RogersAmount: Amount, Codable, Equatable {
    let value: String
    let currency: String
}

struct Activities: Codable, Equatable {
    let activities: [RogersActivity]? // swiftlint:disable:this discouraged_optional_collection
}

struct RogersActivity: Activity, Codable, Equatable {

    enum CodingKeys: String, CodingKey {
        case referenceNumber
        case activityType
        case rogersAmount = "amount"
        case activityStatus
        case activityCategory
        case activityClassification
        case cardNumber
        case rogersMerchant = "merchant"
        case rogersForeignCurrency = "foreign"
        case date
        case activityCategoryCode
        case customerId
        case postedDate
        case activityId
    }

    let referenceNumber: String?
    let activityType: ActivityType
    let activityStatus: ActivityStatus
    let activityCategory: ActivityCategory
    let activityClassification: String
    let cardNumber: String
    let date: Date
    let activityCategoryCode: String?
    let customerId: String
    let postedDate: Date?
    let activityId: String?
    private let rogersMerchant: RogersMerchant
    private let rogersForeignCurrency: RogersForeignCurrency?
    private let rogersAmount: RogersAmount

    var amount: Amount {
        rogersAmount
    }
    var merchant: Merchant {
        rogersMerchant
    }
    var foreign: ForeignCurrency? {
        rogersForeignCurrency
    }
}

extension ActivityCategory: Codable {
    public init(from decoder: Decoder) throws {
        guard let value = try ActivityCategory(rawValue: decoder.singleValueContainer().decode(RawValue.self).lowercased()) else {
            throw try DownloadError.unkownActivityCategory(decoder.singleValueContainer().decode(RawValue.self).lowercased())
        }
        self = value
    }
}
