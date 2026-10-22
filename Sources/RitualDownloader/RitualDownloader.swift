import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Failure while authenticating, decoding or downloading Ritual receipts.
public enum RitualDownloadError: LocalizedError, Equatable {
    /// Invalid request context or importer configuration.
    case invalidContext(String)
    /// Invalid or incomplete server payload.
    case invalidResponse(String)
    /// A server rejected a request; response bodies are deliberately not retained.
    case httpStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidContext(let message):
            return "Invalid Ritual device context: \(message)"
        case .invalidResponse(let message):
            return "Invalid Ritual response: \(message)"
        case .httpStatus(let status):
            return "Ritual request failed with HTTP \(status)."
        }
    }
}

/// Parsed downloads and failures, without retained network response bodies.
public struct RitualDownloadResult {
    /// Decoded receipts in chronological order.
    public let receipts: [RitualReceipt]
    /// Receipts which could not be downloaded or decoded.
    public let failures: [RitualReceiptFailure]

    /// Creates a download result
    public init(receipts: [RitualReceipt], failures: [RitualReceiptFailure] = []) {
        self.receipts = receipts
        self.failures = failures
    }
}

/// Supplies host input, protected credential storage and a container for browser verification.
public protocol RitualDownloaderDelegate: AnyObject {
    /// Reads a saved credential by its Ritual-prefixed key.
    func readCredential(_ key: String) -> String?

    /// Persists a credential immediately, including rotated refresh tokens.
    func saveCredential(_ value: String, for key: String)

    /// Requests a phone number. Keep the input open when completion returns false.
    func requestPhoneNumber(callingCode: String, completion: @escaping (String) -> Bool)

    /// Requests the code from the server-selected destination. Keep the input open when completion returns false.
    func requestVerificationCode(destination: RitualOTPDestination, completion: @escaping (String) -> Bool)

    #if canImport(UIKit)
    /// Returns the container for verification. Called on the main actor.
    func view() -> UIView?
    #elseif canImport(AppKit)
    /// Returns the container for verification. Called on the main actor.
    func view() -> NSView?
    #endif

    #if canImport(UIKit) || canImport(AppKit)
    /// Releases the host's verification container after the browser has been removed. Called on the main actor.
    func removeView()
    #endif
}

/// Signs in to Ritual, maintains the saved session and downloads detailed receipts.
public final class RitualDownloader {

    private enum Operation: UInt64 {
        case orderHistoryPage = 43
        case detailedReceipt = 201
    }

    /// Host input, credential storage and verification view callbacks.
    public weak var delegate: RitualDownloaderDelegate?

    private let dependencies: DownloaderDependencies
    private let authenticator: RitualAuthenticatorProvider
    private let overwriteGetCaptchaHandler: (() async throws -> String)?
    private var credentials: RitualAuthorization?

    /// Creates a downloader
    public convenience init() {
        self.init(dependencies: DownloaderDependencies(
            client: URLSessionHTTPClient(),
            sleep: { try await Task.sleep(nanoseconds: $0) },
            now: Date.init,
            progress: { _ in // swiftlint:disable:this trailing_closure
                // no-op
            }
        ))
    }

    /// Creates a downloader with dependencies and optional overrides.
    /// This is only for testing purposes; only the convenience initializer is public.
    init(
        dependencies: DownloaderDependencies,
        authenticator: RitualAuthenticatorProvider? = nil,
        overwriteGetCaptchaHandler: (() async throws -> String)? = nil
    ) {
        self.dependencies = dependencies
        self.authenticator = authenticator ?? RitualAuthenticator(dependencies: dependencies)
        self.overwriteGetCaptchaHandler = overwriteGetCaptchaHandler
    }

    /// Reuses saved credentials or signs in through the delegate, then downloads unimported receipts.
    /// A rejected saved session triggers one sign-in attempt; transport errors retain the saved session.
    /// - Parameters:
    ///   - since: Inclusive cutoff at the start of a local calendar day.
    ///   - knownReceiptIDs: Receipt IDs already imported by the caller.
    public func download(
        since: Date,
        knownReceiptIDs: Set<String>
    ) async throws -> RitualDownloadResult {
        let login = RitualLogin(
            delegate: delegate,
            authenticator: authenticator,
            overwriteGetCaptchaHandler: overwriteGetCaptchaHandler,
        )
        credentials = try await login.credentials()
        do {
            return try await fetch(since: since, knownReceiptIDs: knownReceiptIDs)
        } catch RitualAuthenticationError.sessionExpired where !login.signedIn {
            // if we are re-using saved credentials, clear the session and try again after a short delay
            login.clearSession()
            try await dependencies.sleep(500_000_000)
            credentials = try await login.credentials()
            return try await fetch(since: since, knownReceiptIDs: knownReceiptIDs)
        }
    }

    /// Downloads unimported orders on or after the cutoff. No response files are written.
    /// - Parameters:
    ///   - since: Inclusive cutoff at the start of a local calendar day.
    ///   - knownReceiptIDs: Receipt IDs already imported into the ledger.
    func fetch(since: Date, knownReceiptIDs: Set<String>) async throws -> RitualDownloadResult {
        var receipts: [RitualReceipt] = [], failures: [RitualReceiptFailure] = []
        var attempted = Set(knownReceiptIDs.map { $0.lowercased() })
        var cursor: String?, pageNumber = 1

        while true {
            let page = try RitualResponseDecoder.history(await api(operation: .orderHistoryPage, label: "history page \(pageNumber)", cursor: cursor))
            let dates = try page.orders.map { try RitualDateParser.date(from: $0.dateTime) }

            dependencies.progress("Page \(pageNumber): \(page.orders.count) orders")
            for (order, date) in zip(page.orders, dates) where date >= since {
                guard attempted.insert(order.receiptID.lowercased()).inserted else {
                    continue // skip recipts that have already been downloaded or attempted, or are known
                }
                if let status = order.status, !status.hasPrefix("Order Completed") {
                    continue // skip orders that are not completed
                }
                if let result = try await downloadReceipt(order, since: since) {
                    switch result {
                    case .success(let receipt):
                        receipts.append(receipt)
                    case .failure(let failure):
                        failures.append(failure)
                    }
                }
            }
            if page.orders.isEmpty || dates.allSatisfy({ $0 < since }) || page.nextCursor == nil || page.nextCursor!.isEmpty {
                break
            }
            cursor = page.nextCursor!
            pageNumber += 1
        }
        return RitualDownloadResult(receipts: receipts.map { ($0.timestamp, $0) }.sorted { ($0.0, $0.1.receiptID) < ($1.0, $1.1.receiptID) }.map(\.1), failures: failures)
    }

    private func downloadReceipt(_ order: RitualOrderSummary, since: Date) async throws -> Result<RitualReceipt, RitualReceiptFailure>? {
        let body: Data
        do {
            body = try await api(operation: .detailedReceipt, label: "receipt \(order.receiptID)", receiptID: order.receiptID)
        } catch RitualDownloadError.httpStatus(let status) where status == 404 || status == 410 {
            return .failure(RitualReceiptFailure(receiptID: order.receiptID, message: "HTTP \(status): receipt unavailable"))
        }
        do {
            let receipt = try RitualResponseDecoder.receipt(body, receiptID: order.receiptID)
            if receipt.timestamp >= since {
                return .success(receipt)
            }
            return nil // Receipt is older than cutoff; ignore without recording a failure.
        } catch {
            dependencies.progress("Could not decode receipt \(order.receiptID)")
            return .failure(RitualReceiptFailure(receiptID: order.receiptID, message: error.localizedDescription))
        }
    }

    private func api(operation: Operation, label: String, receiptID: String? = nil, cursor: String? = nil) async throws -> Data {
        guard let credentials else {
            throw RitualAuthenticationError.noAuthentication
        }
        if try await credentials.refreshIfNeeded(dependencies: dependencies) {
            onCredentialRefresh()
        }
        let body = try body(operation: operation, receiptID: receiptID, cursor: cursor)
        var response = try await Request.sent(RitualConstants.apiURL, body: body, label: label, dependencies: dependencies, authorization: credentials)
        if response.1.statusCode == 401 {
            try await credentials.refresh(dependencies: dependencies)
            onCredentialRefresh()
            let refreshedBody = try self.body(operation: operation, receiptID: receiptID, cursor: cursor)
            response = try await Request.sent(RitualConstants.apiURL, body: refreshedBody, label: label + " retry", dependencies: dependencies, authorization: credentials)
        }
        guard response.1.statusCode != 401 else {
            throw RitualAuthenticationError.sessionExpired
        }
        guard (200..<300).contains(response.1.statusCode) else {
            throw RitualDownloadError.httpStatus(response.1.statusCode)
        }
        return response.0
    }

    private func body(operation: Operation, receiptID: String?, cursor: String?) throws -> Data {
        guard let credentials else {
            throw RitualAuthenticationError.noAuthentication
        }
        var fields: [ProtoField] = [.bytes(1, Data()), .bytes(2, credentials.clientContext), .varint(3, operation.rawValue)]
        if let receiptID {
            guard receiptID.count == 32, receiptID.allSatisfy({ $0.isASCII && $0.isHexDigit }) else {
                throw RitualDownloadError.invalidResponse("Receipt ID must have 32 hexadecimal characters")
            }
            fields.append(.bytes(208, ProtoMessage(fields: [.string(1, receiptID)]).encoded))
        } else {
            let context = try ProtoMessage(credentials.clientContext)
            var parameters: [ProtoField] = [.string(1, "orderreceipts"), .bytes(2, context.bytes(8)!)]
            if let cursor {
                parameters.append(.string(4, cursor))
            }
            parameters.append(.bytes(5, Data([8, 4, 16, 0, 26, 6, 8, 1, 16, 5, 24, 0])))
            fields.append(.bytes(46, ProtoMessage(fields: parameters).encoded))
        }
        fields.append(contentsOf: credentials.authorizationFields)
        return ProtoMessage(fields: fields).encoded
    }

    private func onCredentialRefresh() {
        guard let credentials, let data = try? JSONEncoder().encode(credentials) else {
            return
        }

        let json = String(data: data, encoding: .utf8)!
        delegate?.saveCredential(json, for: "ritual-authorization")
    }

}
