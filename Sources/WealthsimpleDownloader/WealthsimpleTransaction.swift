//
//  Transaction.swift
//
//
//  Created by Steffen Kötte on 2020-07-12.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct WealthsimpleTransaction: Transaction { // swiftlint:disable:this type_body_length

    public typealias TransactionsCompletion = (Result<[Transaction], TransactionError>) -> Void

    private static var baseUrl: URLComponents { URLConfiguration.shared.urlComponents(for: "transactions")! }

    private static let graphQLQuery = """
        query FetchActivityFeedItems($cursor: Cursor, $condition: ActivityCondition) { \
          activityFeedItems(after: $cursor condition: $condition orderBy: OCCURRED_AT_DESC) { \
            edges { node { amount amountSign currency externalCanonicalId occurredAt spendMerchant status subType accountId } } \
            pageInfo { hasNextPage endCursor } \
          } \
        }
        """
    private static let graphQLOperation = "FetchActivityFeedItems"

    private static let graphQLQueryDetailsFragment = "fragment Activity on CreditCardActivity { originalAmount originalCurrency isForeign foreignExchangeRate settledAt }"
    private static let graphQLOperationDetails = "CreditCardActivity"

    private static var dateFormatterREST: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    private static var dateFormatterGraphQLRequest: ISO8601DateFormatter = {
        ISO8601DateFormatter()
    }()

    private static var dateFormatterGraphQLResult: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXX"
        return dateFormatter
    }()

    private static var dateFormatterGraphQLResult2: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss z"
        return dateFormatter
    }()

    let id, accountId, description: String
    let transactionType: TransactionType
    let quantity, symbol: String
    let marketPriceAmount, marketPriceCurrency: String
    let marketValueAmount, marketValueCurrency: String
    let netCashAmount, netCashCurrency: String
    let fxRate: String
    let processDate, effectiveDate: Date

    private init(json: [String: Any]) throws { // swiftlint:disable:this function_body_length
        guard let description = json["description"] as? String, let id = json["id"] as? String, let accountId = json["account_id"] as? String,
              let typeString = json["type"] as? String, let symbol = json["symbol"] as? String, let quantity = json["quantity"] as? String,
              let marketPriceDict = json["market_price"] as? [String: Any], let marketValueDict = json["market_value"] as? [String: Any],
              let netCashDict = json["net_cash"] as? [String: Any], let marketPriceAmount = marketPriceDict["amount"] as? String,
              let marketPriceCurrency = marketPriceDict["currency"] as? String, let marketValueAmount = marketValueDict["amount"] as? String,
              let marketValueCurrency = marketValueDict["currency"] as? String, let netCashAmount = netCashDict["amount"] as? String,
              let netCashCurrency = netCashDict["currency"] as? String, let processDateString = json["process_date"] as? String,
              let effectiveDateString = json["effective_date"] as? String, let fxRate = json["fx_rate"] as? String, let object = json["object"] as? String
        else {
            throw TransactionError.missingResultParameter(json: json)
        }
        guard let processDate = Self.dateFormatterREST.date(from: processDateString), let effectiveDate = Self.dateFormatterREST.date(from: effectiveDateString),
              let type = TransactionType(rawValue: typeString.camelCase), object == "transaction"
        else {
            throw TransactionError.invalidResultParameter(json: json)
        }
        self.id = id
        self.accountId = accountId
        self.description = description
        self.transactionType = type
        self.symbol = symbol
        self.quantity = quantity
        self.marketPriceAmount = marketPriceAmount
        self.marketPriceCurrency = marketPriceCurrency
        self.marketValueAmount = marketValueAmount
        self.marketValueCurrency = marketValueCurrency
        self.netCashAmount = netCashAmount
        self.netCashCurrency = netCashCurrency
        self.fxRate = fxRate
        self.effectiveDate = effectiveDate
        self.processDate = processDate
    }

    private init(graphQL json: [String: Any]) throws { // swiftlint:disable:this function_body_length
        guard let quantity = json["amount"] as? String, let amountSign = json["amountSign"] as? String, let originalAmount = json["originalAmount"] as? String,
              let currency = json["currency"] as? String, let originalCurrency = json["originalCurrency"] as? String, let id = json["externalCanonicalId"] as? String,
              let occurredAt = json["occurredAt"] as? String, let status = json["status"] as? String, let subType = json["subType"] as? String,
              let accountId = json["accountId"] as? String, let isForeign = json["isForeign"] as? Bool
        else {
            throw TransactionError.missingResultParameter(json: json)
        }
        guard let processDate = Self.dateFormatterGraphQLResult.date(from: occurredAt), let type = TransactionType(rawValue: subType.lowercased().camelCase) else {
            throw TransactionError.invalidResultParameter(json: json)
        }
        var effectiveDate = processDate
        if status == "settled" {
            guard let settledAt = json["settledAt"] as? String else {
                throw TransactionError.missingResultParameter(json: json)
            }
            guard let settlementDate = Self.dateFormatterGraphQLResult2.date(from: settledAt) else {
                throw TransactionError.invalidResultParameter(json: json)
            }
            effectiveDate = settlementDate
        }

        var foreignExchangeRate = "1.0"
        if let fxRate = json["foreignExchangeRate"] as? String {
            foreignExchangeRate = fxRate
        } else if isForeign {
            throw TransactionError.missingResultParameter(json: json)
        }

        self.id = id
        self.accountId = accountId
        self.description = json["spendMerchant"] as? String ?? ""
        self.transactionType = type
        self.symbol = originalCurrency
        self.quantity = originalAmount
        self.marketPriceAmount = "1.00"
        self.marketPriceCurrency = currency
        self.marketValueAmount = quantity
        self.marketValueCurrency = currency
        self.netCashAmount = amountSign == "negative" ? "-\(quantity)" : quantity
        self.netCashCurrency = currency
        self.fxRate = foreignExchangeRate
        self.effectiveDate = effectiveDate
        self.processDate = processDate
    }

    static func getTransactions(token: Token, account: Account, startDate: Date, completion: @escaping TransactionsCompletion) {
        // Call internal version with curser = nil. This prevents setting the curser from outside this class
        getTransactions(token: token, account: account, startDate: startDate, cursor: nil, completion: completion)
    }

    private static func getTransactions(token: Token, account: Account, startDate: Date, cursor: String? = nil, completion: @escaping TransactionsCompletion) {
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let isGraphQL = account.accountType == .creditCard
        do {
            guard isGraphQL || cursor == nil else { // Curser is only for GraphQL
               throw TransactionError.invalidParameter
            }
            let request = isGraphQL ? try getTransactionsGraphQLRequest(accountID: account.id, startDate: startDate, endDate: endDate, cursor: cursor) :
                getTransactionsRESTRequest(accountID: account.id, startDate: startDate, endDate: endDate)
            token.authenticateRequest(request) { request in
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    handleResponse(data: data, response: response, error: error) {
                        switch $0 {
                        case .success(let data):
                            if isGraphQL {
                                processGraphQLTransactions(data: data, token: token, account: account, startDate: startDate, completion: completion)
                            } else {
                                completion(parseREST(data: data))
                            }
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                }
                task.resume()
            }
        } catch {
            completion(.failure(error as! TransactionError)) // swiftlint:disable:this force_cast
            return
        }
    }

    private static func fxRequest(json: [[String: Any]]) throws -> URLRequest {
        var queryPart1 = "query CreditCardActivity(", queryPart2 = "", variables = ""
        var index = 0
        for result in json {
            guard let id = result["externalCanonicalId"] as? String else {
                throw TransactionError.missingResultParameter(json: result)
            }
            queryPart1 += "$id\(index): ID!, "
            queryPart2 += "a\(index): creditCardActivity(id: $id\(index)) { ...Activity } "
            variables += #" "id\#(index)": "\#(id)", "#
            index += 1
        }
        // remove trailing comma and space
        queryPart1.removeLast(2)
        variables.removeLast(2)
        let query = queryPart1 + ") { " + queryPart2 + "} " + Self.graphQLQueryDetailsFragment
        let requestData: String = #"{"query": "\#(query)", "operationName": "\#(Self.graphQLOperationDetails)", "variables": { \#(variables) } }"#
        guard var request = URLConfiguration.shared.graphQLURLRequest() else {
            throw TransactionError.httpError(error: "Invalid URL")
        }
        request.httpBody = Data(requestData.utf8)
        return request
    }

    private static func enrichWithFXInfo(edges: [[String: Any]], token: Token) throws -> [[String: Any]] {
        var results = [[String: Any]]() // Invididual JSON Objects, without node wrapper
        for result in edges {
            guard let node = result["node"] as? [String: Any] else {
                throw TransactionError.invalidResultParameter(json: result)
            }
            results.append(node)
        }

        let request = try fxRequest(json: results)
        var resultError: Error?, resultData: Data?

        let group = DispatchGroup()
        group.enter()
        token.authenticateRequest(request) { request in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                handleResponse(data: data, response: response, error: error) { result in
                    switch result {
                    case .failure(let failure):
                        resultError = failure
                    case .success(let data):
                        resultData = data
                    }
                    group.leave()
                }
            }
            task.resume()
        }
        group.wait()

        results = try processAndMergeFXInfo(results: results, resultError: resultError, resultData: resultData)

        return results
    }

    private static func processAndMergeFXInfo(results: [[String: Any]], resultError: Error?, resultData: Data?) throws -> [[String: Any]] {
        var result = results
        guard resultError == nil else {
            throw resultError!
        }
        guard let data = resultData else {
            throw TransactionError.noDataReceived
        }
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw TransactionError.invalidJson(json: data)
        }
        guard let fxResult = json["data"] as? [String: [String: Any]] else {
            throw TransactionError.missingResultParameter(json: json)
        }

        for (key, values) in fxResult {
            guard let index = Int(key.dropFirst()) else {
                throw TransactionError.invalidResultParameter(json: fxResult)
            }
            result[index] = result[index].merging(values) { current, _ in current }
        }
        return result
    }

    private static func loadNextPage(cursor: String, token: Token, account: Account, startDate: Date) throws -> [Transaction] {
        var nextResult: Result<[Transaction], TransactionError>!
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            getTransactions(token: token, account: account, startDate: startDate, cursor: cursor) {
                nextResult = $0
                group.leave()
            }
        }
        group.wait()
        switch nextResult {
        case .success(let nextTransactions):
            return nextTransactions
        case .failure(let error):
            throw error
        case .none:
            throw TransactionError.noDataReceived
        }
    }

    private static func processGraphQLTransactions(data: Data, token: Token, account: Account, startDate: Date, completion: TransactionsCompletion) {
        do {
            let json = try parseGraphQL(data: data)
            guard let page = json["pageInfo"] as? [String: Any], let edges = json["edges"] as? [[String: Any]],
                  let hasNextPage = page["hasNextPage"] as? Bool, let cursor = page["endCursor"] as? String
            else {
                throw TransactionError.invalidResultParameter(json: json)
            }

            let transactionInfo = try enrichWithFXInfo(edges: edges, token: token)

            var transactions = [Transaction]()
            for transaction in transactionInfo {
                transactions.append(try Self(graphQL: transaction))
            }
            if hasNextPage {
                let nextTransactions = try loadNextPage(cursor: cursor, token: token, account: account, startDate: startDate)
                transactions.append(contentsOf: nextTransactions)
            }
            completion(.success(transactions))
        } catch {
            completion(.failure(error as! TransactionError)) // swiftlint:disable:this force_cast
            return
        }
    }

    private static func getTransactionsGraphQLRequest(accountID: String, startDate: Date, endDate: Date, cursor: String?) throws -> URLRequest {
        guard var request = URLConfiguration.shared.graphQLURLRequest() else {
            throw TransactionError.httpError(error: "Invalid URL")
        }
        let startDateString = dateFormatterGraphQLRequest.string(from: startDate)
        let endDateString = dateFormatterGraphQLRequest.string(from: endDate)
        let condition = #""startDate": "\#(startDateString)", "endDate": "\#(endDateString)", "accountIds": ["\#(accountID)"]"#
        let variables = #"\#(cursor != nil ? #""cursor": "\#(cursor!)","# : "") "condition": { \#(condition) }"#
        let requestData = #"{"query": "\#(Self.graphQLQuery)", "operationName": "\#(Self.graphQLOperation)", "variables": { \#(variables) } }"#
        request.httpBody = Data(requestData.utf8)
        return request
    }

    private static func getTransactionsRESTRequest(accountID: String, startDate: Date, endDate: Date) -> URLRequest {
        var url = baseUrl
        url.queryItems = [
            URLQueryItem(name: "account_id", value: accountID),
            URLQueryItem(name: "limit", value: "250"),
            URLQueryItem(name: "effective_date_start", value: dateFormatterREST.string(from: startDate)),
            URLQueryItem(name: "process_date_start", value: dateFormatterREST.string(from: startDate)),
            URLQueryItem(name: "effective_date_end", value: dateFormatterREST.string(from: endDate))
        ]
        var request = URLRequest(url: url.url!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private static func handleResponse(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<Data, TransactionError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data else {
                if let error {
                    completion(.failure(TransactionError.httpError(error: error.localizedDescription)))
                } else {
                    completion(.failure(TransactionError.noDataReceived))
                }
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(TransactionError.httpError(error: "No HTTPURLResponse")))
                return
            }
            guard httpResponse.statusCode == 200 else {
                completion(.failure(TransactionError.httpError(error: "Status code \(httpResponse.statusCode)")))
                return
            }
            completion(.success(data))
        }
    }

    private static func parseREST(data: Data) -> Result<[Transaction], TransactionError> {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return .failure(TransactionError.invalidJson(json: data))
        }
        do {
            guard let results = json["results"] as? [[String: Any]], let object = json["object"] as? String else {
                throw TransactionError.missingResultParameter(json: json)
            }
            guard object == "transaction" else {
                throw TransactionError.invalidResultParameter(json: json)
            }
            var transactions = [Transaction]()
            for result in results {
                transactions.append(try Self(json: result))
            }
            return .success(transactions)
        } catch {
            return .failure(error as! TransactionError) // swiftlint:disable:this force_cast
        }
    }

    private static func parseGraphQL(data: Data) throws -> [String: Any] {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw TransactionError.invalidJson(json: data)
        }
        guard let data = json["data"] as? [String: Any], let results = data["activityFeedItems"] as? [String: Any] else {
            throw TransactionError.missingResultParameter(json: json)
        }
        return results
    }

}
