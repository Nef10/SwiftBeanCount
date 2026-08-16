import Foundation
#if canImport(FoundationNetworking)
@preconcurrency import FoundationNetworking
#endif

protocol HTTPClient {
    func send(
        _ request: URLRequest,
        body: Data?,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    )
}

private final class HTTPCompletionBox: @unchecked Sendable {
    let completion: (Data?, URLResponse?, Error?) -> Void

    init(_ completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        self.completion = completion
    }
}

struct URLSessionHTTPClient: HTTPClient {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(
        _ request: URLRequest,
        body: Data?,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    ) {
        var request = request
        request.httpBody = body
        let completionBox = HTTPCompletionBox(completion)
        session.dataTask(with: request) { data, response, error in
            completionBox.completion(data, response, error)
        }
        .resume()
    }
}

struct DownloaderDependencies {
    static let live = Self(httpClient: URLSessionHTTPClient(), configuration: URLConfiguration())

    let httpClient: HTTPClient
    let configuration: URLConfiguration
}
