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

private final class MockHTTPClient: HTTPClient {
    var requests: [URLRequest] = []
    let handler: (URLRequest, Int) throws -> (Data, Int)

    init(handler: @escaping (URLRequest, Int) throws -> (Data, Int)) { self.handler = handler }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let (body, status) = try handler(request, requests.count)
        return (body, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

private actor SleepProbe {
    private var activeSleeps = 0
    private var durations: [UInt64] = []
    private var maximumActiveSleeps = 0
    private var time: TimeInterval = 0

    func now() async -> TimeInterval {
        time
    }

    func sleep(_ duration: UInt64) async {
        durations.append(duration)
        activeSleeps += 1
        maximumActiveSleeps = max(maximumActiveSleeps, activeSleeps)
        await Task.yield()
        time += TimeInterval(duration) / 1_000_000_000
        activeSleeps -= 1
    }

    func advance(by interval: TimeInterval) {
        time += interval
    }

    func result() -> ([UInt64], Int) {
        (durations, maximumActiveSleeps)
    }
}

private func fixture(_ name: String) throws -> Data { try Data(contentsOf: Bundle.module.resourceURL!.appendingPathComponent("Fixtures/" + name)) }

private func deviceContext() throws -> RitualDeviceContext {
    let client = ProtoMessage(fields: [.string(1, "synthetic-device"), .string(4, "synthetic-user"), .bytes(8, Data([8, 1])), .string(300, "unknown 😀")])
    return try RitualDeviceContext(clientContext: client.encoded, capabilities: ProtoMessage(fields: [.varint(1, 4)]).encoded, userAgent: "Ritual/test")
}

private struct StoredAuthorization: Encodable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    let userID: String
    let context: RitualDeviceContext
}

private func authorization(
    accessToken: String = "saved-access",
    refreshToken: String = "seed",
    expiresAt: Date = Date(timeIntervalSince1970: 0),
    context: RitualDeviceContext? = nil
) throws -> RitualAuthorization {
    let resolvedContext = try context ?? deviceContext()
    let stored = StoredAuthorization(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt,
        userID: String(repeating: "a", count: 32),
        context: resolvedContext
    )
    return try JSONDecoder().decode(RitualAuthorization.self, from: JSONEncoder().encode(stored))
}

private final class StoredSessionDelegate: RitualDownloaderDelegate {
    var credentials: [String: String]

    init(authorization: RitualAuthorization) throws {
        credentials = ["ritual-authorization": String(data: try JSONEncoder().encode(authorization), encoding: .utf8)!]
    }

    func readCredential(_ key: String) -> String? { credentials[key] }
    func saveCredential(_ value: String, for key: String) { credentials[key] = value }
    func requestPhoneNumber(callingCode _: String, completion _: (String) -> Bool) { Issue.record("Saved session should not request a phone number") }
    func requestVerificationCode(destination _: RitualOTPDestination, completion _: (String) -> Bool) {
        Issue.record("Saved session should not request a verification code")
    }
    #if canImport(UIKit)
    func view() -> UIView? { nil }
    #elseif canImport(AppKit)
    func view() -> NSView? { nil }
    #endif
    func removeView() { Issue.record("Saved session should not present verification") }
}

private func token(_ number: Int) -> Data { Data("{\"access_token\":\"access-\(number)\",\"refresh_token\":\"refresh-\(number)\",\"expires_in\":3600}".utf8) }

private func ignore(_: String) { /* Progress is deliberately ignored by these mocks. */ }
private func noWait(_: UInt64) async { /* Tests assert pacing separately without sleeping. */ }

@Suite(.serialized)
struct RitualDownloaderTests {
    @Test
    func decodeReceiptFixture() throws {
        let id = String(repeating: "a", count: 32)
        let receipt = try RitualResponseDecoder.receipt(fixture("receipt-a.pb"), receiptID: id)
        #expect(receipt.merchantName == "Test Café")
        #expect(receipt.items[0].quantity == 2)
        #expect(receipt.items[0].variants == ["Extra sauce"])
        #expect(receipt.totals.filter { $0.label == "Voucher" }.count == 2)
        #expect(throws: RitualDownloadError.self) { try RitualResponseDecoder.receipt(fixture("receipt-a.pb"), receiptID: String(repeating: "b", count: 32)) }
        #expect(throws: RitualDownloadError.self) { try RitualResponseDecoder.history(fixture("receipt-a.pb")) }
        #expect(throws: RitualDownloadError.self) { try RitualResponseDecoder.receipt(Data([0x1f, 0x8b]), receiptID: id) }
    }

    @Test
    func protobufPreservationAndMalformedData() throws {
        let data = ProtoMessage(fields: [.string(300, "Café 😀"), .varint(1, UInt64.max)]).encoded
        #expect(try ProtoMessage(data).encoded == data)
        for bytes: [UInt8] in [[0], [8, 128], [18, 255], [15], [8] + Array(repeating: 255, count: 10)] {
            #expect(throws: RitualDownloadError.self) { try ProtoMessage(Data(bytes)) }
        }
    }

    @Test
    func contextRoundTripAndRequests() throws {
        let context = try deviceContext()
        let json = String(data: try JSONEncoder().encode(context), encoding: .utf8)!
        #expect(try RitualDeviceContext.parse(json) == context)
        #expect(throws: RitualDownloadError.self) { try RitualDeviceContext.parse("{}") }
        #expect(throws: RitualDownloadError.self) { try RitualDeviceContext(clientContext: Data(), capabilities: Data(), userAgent: "x") }
        let saved = try authorization(accessToken: "test-token", context: context)
        #expect(saved.clientContext == context.clientContext)
        let fields = ProtoMessage(fields: saved.authorizationFields)
        #expect(fields.bytes(157) == context.capabilities)
        #expect(fields.string(255) == "test-token")
    }

    @Test
    func requestGateSerializesWaits() async throws {
        let gate = RequestGate()
        let probe = SleepProbe()
        async let first = gate.acquire(sleep: probe.sleep, now: probe.now)
        async let second = gate.acquire(sleep: probe.sleep, now: probe.now)
        async let third = gate.acquire(sleep: probe.sleep, now: probe.now)
        let numbers = try await [first, second, third]
        await probe.advance(by: 0.75)
        let fourth = try await gate.acquire(sleep: probe.sleep, now: probe.now)
        let (durations, maximumActiveSleeps) = await probe.result()
        #expect(Set(numbers) == [1, 2, 3])
        #expect(fourth == 4)
        #expect(durations == [500_000_000, 500_000_000])
        #expect(maximumActiveSleeps == 1)
    }

    // Exercise the complete two-page request sequence and its observable side effects.
    @Test
    func paginationKnownIDsStatusesAndPacing() async throws { // swiftlint:disable:this function_body_length
        let client = MockHTTPClient { request, number in
            if number == 1 {
                #expect(String(data: request.httpBody!, encoding: .utf8)!.contains("refresh_token=seed%2B%2F%3D"))
                return (token(number), 200)
            }
            let body = try ProtoMessage(request.httpBody!)
            #expect(body.string(255) == "access-1")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(request.value(forHTTPHeaderField: "Accept-Encoding") == "identity")
            switch number {
            case 2:
                return (try fixture("history-1.pb"), 200)
            case 3:
                #expect(try body.message(208).string(1) == String(repeating: "a", count: 32))
                return (try fixture("receipt-a.pb"), 200)
            case 4:
                #expect(try body.message(46).string(4) == "opaque-cursor")
                return (try fixture("history-2.pb"), 200)
            case 5:
                return (try fixture("receipt-b.pb"), 200)
            default:
                Issue.record("Unexpected request")
                return (Data(), 500)
            }
        }
        var waits: [UInt64] = []
        var progress: [String] = []
        let downloader = RitualDownloader(
            dependencies: DownloaderDependencies(
                client: client,
                sleep: { waits.append($0) },
                now: { Date(timeIntervalSince1970: 1_791_331_200) },
                progress: { progress.append($0) }
            )
        )
        let delegate = try StoredSessionDelegate(authorization: authorization(refreshToken: "seed+/="))
        downloader.delegate = delegate
        let result = try await downloader.download(
            since: RitualDateParser.date(from: "Aug. 8, 2026"),
            knownReceiptIDs: [String(repeating: "c", count: 32)]
        )
        #expect(client.requests.count == 5)
        #expect(waits.allSatisfy { $0 > 0 && $0 <= 500_000_000 })
        #expect(result.receipts.map(\.receiptID) == [String(repeating: "b", count: 32), String(repeating: "a", count: 32)])
        #expect(result.failures.isEmpty)
        #expect(progress.filter { $0.contains("POST ") }.count == 5)
        #expect(progress.filter { $0.contains("HTTP ") }.count == 5)
        #expect(!progress.joined().contains("seed"))
        #expect(!progress.joined().contains("access-1"))
    }

    @Test
    func unauthorizedRetriesOnceWithRotatedToken() async throws {
        let client = MockHTTPClient { request, number in
            switch number {
            case 1:
                return (token(number), 200)
            case 2:
                return (Data(), 401)
            case 3:
                #expect(String(data: request.httpBody!, encoding: .utf8)!.contains("refresh_token=refresh-1"))
                return (token(number), 200)
            case 4:
                #expect(try ProtoMessage(request.httpBody!).string(255) == "access-3")
                return (try fixture("history-old.pb"), 200)
            default:
                Issue.record("Unexpected retry")
                return (Data(), 500)
            }
        }
        var waits: [UInt64] = []
        let downloader = RitualDownloader(dependencies: DownloaderDependencies(client: client, sleep: { waits.append($0) }, now: Date.init, progress: ignore))
        let delegate = try StoredSessionDelegate(authorization: authorization())
        downloader.delegate = delegate
        let result = try await downloader.download(
            since: RitualDateParser.date(from: "Oct. 1, 2026"),
            knownReceiptIDs: []
        )
        #expect(result.receipts.isEmpty)
        #expect(client.requests.count == 4)
        #expect(!waits.isEmpty)
        #expect(waits.allSatisfy { $0 > 0 && $0 <= 500_000_000 })
    }

    @Test
    func unavailableAndMalformedReceiptsProducePartialResult() async throws {
        let client = MockHTTPClient { _, number in
            switch number {
            case 1:
                return (token(number), 200)
            case 2:
                return (try fixture("history-1.pb"), 200)
            case 3:
                return (Data(), 404)
            case 4:
                return (Data([0]), 200)
            case 5:
                return (try fixture("history-old.pb"), 200)
            default:
                Issue.record("Unexpected request")
                return (Data(), 500)
            }
        }
        let downloader = RitualDownloader(dependencies: DownloaderDependencies(client: client, sleep: noWait, now: Date.init, progress: ignore))
        let delegate = try StoredSessionDelegate(authorization: authorization())
        downloader.delegate = delegate
        let result = try await downloader.download(
            since: RitualDateParser.date(from: "Oct. 1, 2026"),
            knownReceiptIDs: []
        )
        #expect(result.receipts.isEmpty)
        #expect(result.failures.count == 2)
        #expect(result.failures[0].message.contains("404"))
    }

    @Test
    func cancellationAndRejectedRefreshStopRequests() async throws {
        let client = MockHTTPClient { _, _ in
            withUnsafeCurrentTask { $0?.cancel() }
            return (token(1), 200)
        }
        let downloader = RitualDownloader(
            dependencies: DownloaderDependencies(client: client, sleep: noWait, now: Date.init, progress: ignore)
        )
        let delegate = try StoredSessionDelegate(authorization: authorization())
        downloader.delegate = delegate
        let cancelledDownload = Task { try await downloader.download(since: Date(), knownReceiptIDs: []) }
        await #expect(throws: CancellationError.self) {
            try await cancelledDownload.value
        }
        #expect(client.requests.count == 1)
        let rejected = MockHTTPClient { _, _ in (Data(), 400) }
        let denied = RitualDownloader(dependencies: DownloaderDependencies(client: rejected, sleep: noWait, now: Date.init, progress: ignore))
        let deniedDelegate = try StoredSessionDelegate(authorization: authorization())
        denied.delegate = deniedDelegate
        await #expect(throws: RitualDownloadError.httpStatus(400)) {
            try await denied.download(since: Date(), knownReceiptIDs: [])
        }
        #expect(rejected.requests.count == 1)
    }

    @Test
    func expiredRefreshTokenRequiresSignIn() async throws {
        let client = MockHTTPClient { _, _ in (Data(#"{"error":"invalid_grant","error_description":"private detail"}"#.utf8), 400) }
        let dependencies = DownloaderDependencies(client: client, sleep: noWait, now: Date.init, progress: ignore)
        let credentials = try authorization(refreshToken: "expired")
        await #expect(throws: RitualAuthenticationError.sessionExpired) {
            try await credentials.refresh(dependencies: dependencies)
        }
        #expect(client.requests.count == 1)
        #expect(!RitualAuthenticationError.sessionExpired.localizedDescription.contains("private"))
    }

    @Test(arguments: ["Mon., Oct. 5, 2026 at 12:11 PM", "Monday, October 5, 2026 at 12:11 PM", "Oct. 5, 2026 | 12:11 PM"])
    func observedDateFormats(_ text: String) throws {
        #expect(try RitualDateParser.date(from: text) == RitualDateParser.date(from: "Oct. 5, 2026"))
    }

    @Test(arguments: ["Feb. 30, 2026", "garbage", "Oct. 0, 2026"])
    func invalidDates(_ text: String) {
        #expect(throws: RitualDownloadError.self) { try RitualDateParser.date(from: text) }
    }
}
