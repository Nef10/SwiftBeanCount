import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Returns response bytes after HTTP content decoding, as provided by URLSession.
protocol HTTPClient {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

final class URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 120
        session = URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw RitualDownloadError.invalidResponse("Missing HTTP response")
        }
        return (data, response)
    }

    deinit {
        session.invalidateAndCancel()
    }
}

private final class NoRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest,
        completionHandler: (URLRequest?) -> Void
    ) { completionHandler(nil) }
}

actor RequestGate {
    private var tail: Task<Void, Never>?
    private var requestNumber = 0
    private var lastRequestTime: TimeInterval?

    func acquire(
        sleep: @escaping (UInt64) async throws -> Void,
        now: @escaping () async -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) async throws -> Int {
        requestNumber += 1
        let number = requestNumber
        let previous = tail
        let turn = Task {
            if let previous {
                await previous.value
            }
            let currentTime = await now()
            if let lastRequestTime {
                let remaining = 0.5 - (currentTime - lastRequestTime)
                if remaining > 0 {
                    try await sleep(UInt64(remaining * 1_000_000_000))
                }
            }
            lastRequestTime = await now()
        }
        tail = Task { _ = try? await turn.value }
        return try await withTaskCancellationHandler {
            try await turn.value
            try Task.checkCancellation()
            return number
        } onCancel: {
            turn.cancel()
        }
    }
}

enum Request {

    private static let gate = RequestGate()

    static func sent(
        _ url: URL, values: [String: String], label: String, dependencies: DownloaderDependencies, authorization: RitualAuthorization? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        try await sent(url, body: RitualFormEncoder.encoded(values), label: label, dependencies: dependencies, authorization: authorization, isProto: false)
    }

    static func sent(
        _ url: URL, body: Data, label: String, dependencies: DownloaderDependencies, authorization: RitualAuthorization? = nil, isProto: Bool = true
    ) async throws -> (Data, HTTPURLResponse) {
        try Task.checkCancellation()
        let requestNumber = try await gate.acquire(sleep: dependencies.sleep)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue(isProto ? "application/x-protobuf" : "application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(url == RitualConstants.tokenURL || url == RitualConstants.authorizationURL ? "application/json" : "*/*", forHTTPHeaderField: "Accept")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("en-CA,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue(authorization == nil ? RitualConstants.userAgent : authorization!.userAgent, forHTTPHeaderField: "User-Agent")
        dependencies.progress("[\(requestNumber) \(label)] POST \(url.absoluteString)")
        let response: (Data, HTTPURLResponse)
        do {
            response = try await dependencies.client.send(request)
        } catch {
            dependencies.progress("[\(requestNumber)] Transport failure")
            throw error
        }
        dependencies.progress("[\(requestNumber)] HTTP \(response.1.statusCode), \(response.0.count) bytes")
        return response
    }

}

struct DownloaderDependencies {
    let client: HTTPClient
    let sleep: (UInt64) async throws -> Void
    let now: () -> Date
    let progress: (String) -> Void
}
