import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol HTTPClient {
    func send(
        _ request: URLRequest,
        body: Data?,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    )
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
        session.dataTask(with: request, completionHandler: completion).resume()
    }
}

struct DownloaderDependencies {
    static let live = Self(httpClient: URLSessionHTTPClient(), configuration: URLConfiguration())

    let httpClient: HTTPClient
    let configuration: URLConfiguration
}
