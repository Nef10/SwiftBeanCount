import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A credit card account
public protocol Account {
    /// Customer
    var customer: Customer { get }
    /// Internal ID
    var accountId: String { get }
    /// Account type, e.g. Personal
    var accountType: String { get }
    /// Payment status, e.g. Paid
    var paymentStatus: String { get }
    /// Product Name, e.g. World Elite
    var productName: String { get }
    /// Code for product
    var productExternalCode: String { get }
    /// ISO symbol of account currency
    var accountCurrency: String { get }
    /// Brand name, e.g. ROGERSBRAND
    var brandId: String { get }
    /// Date the Account was opend
    var openedDate: Date { get }
    /// Date of the last statement
    var previousStatementDate: Date { get }
    /// Date the payment of the current statement is due (might be in the past)
    var paymentDueDate: Date { get }
    /// Date of the last payment
    var lastPaymentDate: Date { get }
    /// List of past statement dates
    var cycleDates: [Date] { get }
    /// Current balance
    var currentBalance: Amount { get }
    /// Balance on the last Statement
    var statementBalance: Amount { get }
    /// Amount which is still due for the statement
    var statementDueAmount: Amount { get }
    /// Credit limit
    var creditLimit: Amount { get }
    /// Amount charged since the last statement
    var purchasesSinceLastCycle: Amount? { get }
    /// Amount of the last payment
    var lastPayment: Amount { get }
    /// Remaining credit limit
    var realtimeBalance: Amount { get }
    /// Cash Advance available
    var cashAvailable: Amount { get }
    /// Cash Advance limit
    var cashLimit: Amount { get }
    /// Multi Card
    var multiCard: Bool { get }

    /// Download a statement
    /// - Parameters:
    ///   - statement: the statement to download
    ///   - completion: completion handler, called with either a temporary URL to the downloaded file or a DownloadError
    func downloadStatement(statement: Statement, completion: @escaping (Result<URL, DownloadError>) -> Void)

    /// Search Statements
    /// - Parameters:
    ///   - completion: completion handler, called with either the Statements or a DownloadError
    func searchStatements(completion: @escaping (Result<[Statement], DownloadError>) -> Void)

    /// Downloads the transactions
    /// - Parameters:
    ///   - statementNumber: number of the statement for which the transactions should be downloaded, with 0 mean current period, 1 means last statement, ...
    ///   - completion: completion handler, called with either the Transactions or a DownloadError
    func downloadActivities(statementNumber: Int, completion: @escaping (Result<[Activity], DownloadError>) -> Void)
}

/// A Rogers credit card account
public struct RogersAccount: Account, Codable {

    enum CodingKeys: String, CodingKey {
        case accountId
        case accountType
        case paymentStatus
        case productName
        case productExternalCode
        case accountCurrency
        case brandId
        case openedDate
        case previousStatementDate
        case paymentDueDate
        case lastPaymentDate
        case cycleDates
        case multiCard
        case rogersCurrentBalance = "currentBalance"
        case rogersStatementBalance = "statementBalance"
        case rogersStatementDueAmount = "statementDueAmount"
        case rogersCreditLimit = "creditLimit"
        case rogersPurchasesSinceLastCycle = "purchasesSinceLastCycle"
        case rogersLastPayment = "lastPayment"
        case rogersRealtimeBalance = "realtimeBalance"
        case rogersCashAvailable = "cashAvailable"
        case rogersCashLimit = "cashLimit"
        case rogersCustomer = "customer"
    }

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(Self.dateFormatter)
        return decoder
    }()

    public let accountId: String
    public let accountType: String
    public let paymentStatus: String
    public let productName: String
    public let productExternalCode: String
    public let accountCurrency: String
    public let brandId: String
    public let openedDate: Date
    public let previousStatementDate: Date
    public let paymentDueDate: Date
    public let lastPaymentDate: Date
    public let cycleDates: [Date]
    public let multiCard: Bool
    private let rogersStatementBalance: RogersAmount
    private let rogersCurrentBalance: RogersAmount
    private let rogersStatementDueAmount: RogersAmount
    private let rogersCreditLimit: RogersAmount
    private let rogersPurchasesSinceLastCycle: RogersAmount?
    private let rogersLastPayment: RogersAmount
    private let rogersRealtimeBalance: RogersAmount
    private let rogersCashAvailable: RogersAmount
    private let rogersCashLimit: RogersAmount
    private let rogersCustomer: RogersCustomer

    public var customer: Customer {
        rogersCustomer
    }

    public var statementBalance: Amount {
        rogersStatementBalance
    }
    public var currentBalance: Amount {
        rogersCurrentBalance
    }
    public var statementDueAmount: Amount {
        rogersStatementDueAmount
    }
    public var creditLimit: Amount {
        rogersCreditLimit
    }
    public var purchasesSinceLastCycle: Amount? {
        rogersPurchasesSinceLastCycle
    }
    public var lastPayment: Amount {
        rogersLastPayment
    }
    public var realtimeBalance: Amount {
        rogersRealtimeBalance
    }
    public var cashLimit: Amount {
        rogersCashLimit
    }
    public var cashAvailable: Amount {
        rogersCashAvailable
    }

    private var activityURLComponents: URLComponents {
        URLComponents(string: "https://rbaccess.rogersbank.com/issuing/digital/account/\(accountId)/customer/\(customer.customerId)/activity")!
    }

    private var statementSearchURL: URL {
        URL(string: "https://rbaccess.rogersbank.com/issuing/digital/account/\(accountId)/customer/\(customer.customerId)/estatement/search")!
    }

    private func statementDownloadURL(statement: Statement) -> URL {
        URL(string: "https://rbaccess.rogersbank.com/issuing/digital/account/\(accountId)/customer/\(customer.customerId)/estatement/\(statement.statementId)/view")!
    }

    public func downloadStatement(statement: Statement, completion: @escaping (Result<URL, DownloadError>) -> Void) {
        var request = URLRequest(url: statementDownloadURL(statement: statement))
        request.httpMethod = "GET"

        let task = URLSession.shared.downloadTask(with: request) { url, response, error in
            guard let url else {
                if let error {
                    completion(.failure(DownloadError.httpError(error: error.localizedDescription)))
                } else {
                    completion(.failure(DownloadError.noDataReceived))
                }
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(DownloadError.httpError(error: "No HTTPURLResponse")))
                return
            }
            guard httpResponse.statusCode == 200 else {
                completion(.failure(DownloadError.httpError(error: "Status code \(httpResponse.statusCode)")))
                return
            }
            completion(.success(url))
        }
        task.resume()
    }

    public func searchStatements(completion: @escaping (Result<[Statement], DownloadError>) -> Void) {
        var request = URLRequest(url: statementSearchURL)
        request.httpMethod = "GET"

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data else {
                if let error {
                    completion(.failure(DownloadError.httpError(error: error.localizedDescription)))
                } else {
                    completion(.failure(DownloadError.noDataReceived))
                }
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(DownloadError.httpError(error: "No HTTPURLResponse")))
                return
            }
            guard httpResponse.statusCode == 200 else {
                completion(.failure(DownloadError.httpError(error: "Status code \(httpResponse.statusCode)")))
                return
            }
            do {
                let statements = try Self.decoder.decode(Statements.self, from: data)
                completion(.success(statements.monthlyStatements))
            } catch {
                completion(.failure(DownloadError.invalidJson(error: String(describing: error))))
                return
            }
        }
        task.resume()
    }

    public func downloadActivities(statementNumber: Int, completion: @escaping (Result<[Activity], DownloadError>) -> Void) {
        downloadActivities(statementNumber: statementNumber, retryAttempt: 0, completion: completion)
    }

    public func downloadActivities(statementNumber: Int, retryAttempt: Int, completion: @escaping (Result<[Activity], DownloadError>) -> Void) {
        guard statementNumber >= 0 && cycleDates.count >= statementNumber else {
            completion(.failure(DownloadError.invalidStatementNumber(statementNumber)))
            return
        }
        var urlComponents = activityURLComponents
        if statementNumber > 0 {
            urlComponents.queryItems = [URLQueryItem(name: "cycleStartDate", value: Self.dateFormatter.string(from: cycleDates[statementNumber - 1]))]
        }
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "GET"

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            let processedResponse = URLTaskHelper.processResponse(data: data, response: response, error: error)
            guard case let .success((data, httpResponse)) = processedResponse else {
                if case let .failure(error) = processedResponse {
                    completion(.failure(error))
                }
                return
            }
            guard httpResponse.statusCode == 200 else {
                if retryAttempt < 2 {
                    downloadActivities(statementNumber: statementNumber, retryAttempt: retryAttempt + 1, completion: completion)
                } else {
                    completion(.failure(DownloadError.httpError(error: "Status code \(httpResponse.statusCode)")))
                }
                return
            }
            completion(parseData(data))
        }
        task.resume()
    }

    private func parseData(_ data: Data) -> Result<[Activity], DownloadError> {
        do {
            let activities = try Self.decoder.decode(Activities.self, from: data)
            return .success(activities.activities ?? [])
        } catch {
            return .failure(DownloadError.invalidJson(error: String(describing: error)))
        }
    }

}
