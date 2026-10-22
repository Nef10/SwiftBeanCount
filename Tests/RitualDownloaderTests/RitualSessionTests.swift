import Foundation
import Testing
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@testable import RitualDownloader

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private let sessionUserID = String(repeating: "b", count: 32)

private struct AuthorizationSnapshot: Decodable {
    let refreshToken: String
    let context: RitualDeviceContext
}

private func testAuthorization(deviceID: String, refreshToken: String = "initial-token", expiresIn: Double = 3_600) throws -> RitualAuthorization {
    let payload = try JSONSerialization.data(withJSONObject: ["sub": "f:provider:" + sessionUserID])
        .base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    let token = Token(accessToken: "header.\(payload).signature", refreshToken: refreshToken, expiresIn: expiresIn)
    return try RitualAuthorization(token: token, deviceID: deviceID)
}

private func encoded(_ authorization: RitualAuthorization) throws -> String {
    String(data: try JSONEncoder().encode(authorization), encoding: .utf8)!
}

private final class TestRitualAuthenticator: RitualAuthenticatorProvider {
    var calls = 0
    var devices: [String] = []
    var phone: RitualPhoneNumber?
    var error: Error?
    var challenge: RitualOTPDestination = .sms(phoneLastFour: "1234")

    func login(
        phone: RitualPhoneNumber,
        deviceID: String,
        getCaptchaHandler: () async throws -> String,
        getOTPHandler: (RitualOTPDestination) async throws -> String
    ) async throws -> RitualAuthorization {
        calls += 1
        devices.append(deviceID)
        self.phone = phone
        #expect(UUID(uuidString: deviceID) != nil)
        #expect(try await getCaptchaHandler() == "mock-verification")
        #expect(try await getOTPHandler(challenge) == "123456")
        if let error { throw error }
        return try testAuthorization(deviceID: deviceID)
    }
}

private final class SessionHTTPClient: HTTPClient {
    var failures: [Error] = []
    var tokens: [String] = []
    var requests = 0

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests += 1
        if request.url!.path.hasSuffix("/token") {
            var form = URLComponents()
            form.percentEncodedQuery = String(data: request.httpBody!, encoding: .utf8)
            tokens.append(form.queryItems!.first { $0.name == "refresh_token" }!.value!)
        }
        if !failures.isEmpty {
            let error = failures.removeFirst()
            if error as? RitualAuthenticationError == .sessionExpired {
                if request.url!.path.hasSuffix("/token") {
                    return response(Data(#"{"error":"invalid_grant"}"#.utf8), request: request, status: 400)
                }
                return response(Data(), request: request, status: 401)
            }
            throw error
        }
        if request.url!.path.hasSuffix("/token") {
            return response(Data(#"{"access_token":"access","refresh_token":"rotated-token","expires_in":3600}"#.utf8), request: request)
        }
        let data = try Data(contentsOf: Bundle.module.resourceURL!.appendingPathComponent("Fixtures/history-old.pb"))
        return response(data, request: request)
    }

    private func response(_ data: Data, request: URLRequest, status: Int = 200) -> (Data, HTTPURLResponse) {
        (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

private final class SessionDelegate: RitualDownloaderDelegate {
    var credentials: [String: String] = [:]
    var inputs: [String] = []
    var codePrompt = "SMS code (phone ending 1234)"

    func readCredential(_ key: String) -> String? { credentials[key] }
    func saveCredential(_ value: String, for key: String) { credentials[key] = value }

    func requestPhoneNumber(callingCode: String, completion: (String) -> Bool) {
        inputs.append("Phone number (\(callingCode))")
        #expect(!completion("invalid phone"))
        #expect(completion("+1 (555) 555-0123"))
        #expect(!completion("+1 (555) 555-0123"))
    }

    func requestVerificationCode(destination: RitualOTPDestination, completion: (String) -> Bool) {
        inputs.append(destination.prompt)
        #expect(destination.prompt == codePrompt)
        #expect(!completion("123"))
        #expect(completion("123456"))
        #expect(!completion("123456"))
    }

    #if canImport(UIKit)
    func view() -> UIView? { nil }
    #elseif canImport(AppKit)
    func view() -> NSView? { nil }
    #endif
    func removeView() { Issue.record("Tests use injected verification and never open a browser") }
}

private func ignoreSessionProgress(_: String) { /* Offline tests do not log. */ }

private func sessionDownloader(
    client: SessionHTTPClient,
    authenticator: TestRitualAuthenticator,
    delegate: SessionDelegate,
    getCaptchaHandler: @escaping () async throws -> String = { "mock-verification" }
) -> RitualDownloader {
    let downloader = RitualDownloader(
        dependencies: DownloaderDependencies(client: client, sleep: { _ in /* Offline tests do not sleep. */ }, now: Date.init, progress: ignoreSessionProgress),
        authenticator: authenticator,
        overwriteGetCaptchaHandler: getCaptchaHandler
    )
    downloader.delegate = delegate
    return downloader
}

@Suite(.serialized)
struct RitualSessionTests {
    @Test
    func signInSavesAuthorizationAndDownloads() async throws {
        let client = SessionHTTPClient()
        let authenticator = TestRitualAuthenticator()
        let delegate = SessionDelegate()
        var waits: [UInt64] = []
        let downloader = RitualDownloader(
            dependencies: DownloaderDependencies(client: client, sleep: { waits.append($0) }, now: Date.init, progress: ignoreSessionProgress),
            authenticator: authenticator
        ) { "mock-verification" }
        downloader.delegate = delegate
        _ = try await downloader.download(since: Date(), knownReceiptIDs: [])
        #expect(delegate.inputs == ["Phone number (+1)", delegate.codePrompt])
        let savedJSON = try #require(delegate.credentials["ritual-authorization"])
        let saved = try JSONDecoder().decode(AuthorizationSnapshot.self, from: Data(savedJSON.utf8))
        #expect(saved.refreshToken == "initial-token")
        #expect(try ProtoMessage(saved.context.clientContext).string(1) == delegate.credentials["ritual-device-id"])
        #expect(authenticator.phone?.nationalNumber == "5555550123")
        #expect(Set(delegate.credentials.keys) == ["ritual-device-id", "ritual-phone-number", "ritual-authorization"])
        #expect(waits.allSatisfy { $0 > 0 && $0 <= 500_000_000 })
        #expect(client.tokens.isEmpty)
    }

    @Test
    func storedSessionSkipsAllSignInPrompts() async throws {
        let client = SessionHTTPClient()
        let authenticator = TestRitualAuthenticator()
        let delegate = SessionDelegate()
        let saved = try testAuthorization(deviceID: "abcdefab-cdef-4000-8000-000000000001", refreshToken: "saved-token")
        delegate.credentials = ["ritual-authorization": try encoded(saved)]
        let downloader = sessionDownloader(client: client, authenticator: authenticator, delegate: delegate)
        _ = try await downloader.download(since: Date(), knownReceiptIDs: [])
        #expect(delegate.inputs.isEmpty)
        #expect(authenticator.calls == 0)
        #expect(client.tokens.isEmpty)
        let expected = try JSONDecoder().decode(AuthorizationSnapshot.self, from: Data(encoded(saved).utf8))
        let storedJSON = try #require(delegate.credentials["ritual-authorization"])
        let stored = try JSONDecoder().decode(AuthorizationSnapshot.self, from: Data(storedJSON.utf8))
        #expect(stored.refreshToken == expected.refreshToken)
        #expect(stored.context == expected.context)
    }

    @Test
    func expiredStoredSessionSignsInOnce() async throws {
        let client = SessionHTTPClient()
        client.failures = [RitualAuthenticationError.sessionExpired]
        let authenticator = TestRitualAuthenticator()
        let delegate = SessionDelegate()
        let downloader = sessionDownloader(client: client, authenticator: authenticator, delegate: delegate)
        let deviceID = "abcdefab-cdef-4000-8000-000000000002"
        delegate.credentials = [
            "ritual-authorization": try encoded(testAuthorization(deviceID: deviceID, refreshToken: "expired", expiresIn: -1)),
            "ritual-device-id": deviceID,
            "ritual-phone-number": "+15555550123"
        ]
        _ = try await downloader.download(since: Date(), knownReceiptIDs: [])
        #expect(client.tokens == ["expired"])
        #expect(authenticator.calls == 1)
        #expect(delegate.inputs == ["SMS code (phone ending 1234)"])
        let saved = try JSONDecoder().decode(AuthorizationSnapshot.self, from: Data(#require(delegate.credentials["ritual-authorization"]).utf8))
        #expect(saved.refreshToken == "initial-token")
    }

    @Test
    func newSessionFailureDoesNotSendAnotherSMS() async throws {
        let client = SessionHTTPClient()
        client.failures = [RitualAuthenticationError.sessionExpired, RitualAuthenticationError.sessionExpired]
        let authenticator = TestRitualAuthenticator()
        let delegate = SessionDelegate()
        let downloader = sessionDownloader(client: client, authenticator: authenticator, delegate: delegate)
        await #expect(throws: RitualAuthenticationError.sessionExpired) {
            try await downloader.download(since: Date(), knownReceiptIDs: [])
        }
        #expect(authenticator.calls == 1)
        #expect(client.tokens.count == 1)
        #expect(delegate.inputs.count == 2)
    }

    @Test
    func transportFailurePreservesSavedSession() async throws {
        let client = SessionHTTPClient()
        client.failures = [URLError(.notConnectedToInternet)]
        let authenticator = TestRitualAuthenticator()
        let delegate = SessionDelegate()
        let downloader = sessionDownloader(client: client, authenticator: authenticator, delegate: delegate)
        let saved = try testAuthorization(deviceID: "abcdefab-cdef-4000-8000-000000000003", refreshToken: "saved-token")
        let savedJSON = try encoded(saved)
        delegate.credentials = ["ritual-authorization": savedJSON]
        await #expect(throws: URLError.self) {
            try await downloader.download(since: Date(), knownReceiptIDs: [])
        }
        #expect(authenticator.calls == 0)
        #expect(delegate.inputs.isEmpty)
        #expect(delegate.credentials["ritual-authorization"] == savedJSON)
    }

    @Test
    func emailVerificationUsesReturnedDestination() async throws {
        let client = SessionHTTPClient()
        let authenticator = TestRitualAuthenticator()
        authenticator.challenge = .email(maskedAddress: "s***@example.test")
        let delegate = SessionDelegate()
        let downloader = sessionDownloader(client: client, authenticator: authenticator, delegate: delegate)
        delegate.codePrompt = "Email verification code (sent to s***@example.test)"
        _ = try await downloader.download(since: Date(), knownReceiptIDs: [])
        #expect(delegate.inputs == ["Phone number (+1)", delegate.codePrompt])
        #expect(client.tokens.isEmpty)
        #expect(authenticator.calls == 1)
        #expect(!delegate.credentials.values.contains("s***@example.test"))
    }

    @Test
    func rejectedSMSDoesNotSaveSessionOrDownload() async throws {
        let client = SessionHTTPClient()
        let authenticator = TestRitualAuthenticator()
        authenticator.error = RitualAuthenticationError.rejected(400)
        let delegate = SessionDelegate()
        let downloader = sessionDownloader(client: client, authenticator: authenticator, delegate: delegate)
        await #expect(throws: RitualAuthenticationError.rejected(400)) {
            try await downloader.download(since: Date(), knownReceiptIDs: [])
        }
        #expect(authenticator.calls == 1)
        #expect(client.tokens.isEmpty)
        #expect(delegate.credentials["ritual-authorization"] == nil)
    }

    @Test
    func cancelledVerificationDoesNotAskForCodeOrDownload() async throws {
        let client = SessionHTTPClient()
        let delegate = SessionDelegate()
        let downloader = sessionDownloader(client: client, authenticator: TestRitualAuthenticator(), delegate: delegate) {
            throw RitualAuthenticationError.cancelled
        }
        await #expect(throws: RitualAuthenticationError.cancelled) {
            try await downloader.download(since: Date(), knownReceiptIDs: [])
        }
        #expect(delegate.inputs == ["Phone number (+1)"])
        #expect(client.tokens.isEmpty)
        #expect(delegate.credentials["ritual-authorization"] == nil)
    }
}
