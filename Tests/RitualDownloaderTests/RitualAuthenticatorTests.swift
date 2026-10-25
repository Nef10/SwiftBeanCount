import Foundation
import Testing

@testable import RitualDownloader

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private let testDeviceID = "00000000-0000-4000-8000-000000000001"
private let testUserID = String(repeating: "a", count: 32)

private struct LoginAuthorizationSnapshot: Decodable {
    let refreshToken: String
    let context: RitualDeviceContext
}

private final class LoginHTTPClient: HTTPClient {
    var requests: [URLRequest] = []
    let handler: (URLRequest, Int) throws -> (Data, Int)

    init(handler: @escaping (URLRequest, Int) throws -> (Data, Int)) { self.handler = handler }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let (data, status) = try handler(request, requests.count)
        return (data, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

private func form(_ request: URLRequest) -> [String: String] {
    var components = URLComponents()
    components.percentEncodedQuery = String(data: request.httpBody!, encoding: .utf8)!
    return Dictionary(uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value!) })
}

private func signInToken(subject: String = "f:provider:" + testUserID) throws -> Data {
    let payload = try JSONSerialization.data(withJSONObject: ["sub": subject])
        .base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    return try JSONSerialization.data(withJSONObject: ["access_token": "header." + payload + ".signature", "refresh_token": "fresh-refresh", "expires_in": 3_600])
}

private func authorization() -> Data { Data(#"{"token":"temporary +/= token","last_four":"0123"}"#.utf8) }
private func noPause(_: UInt64) async { /* The pacing test records delays instead of sleeping. */ }
private func discardProgress(_: String) { /* These tests validate errors rather than progress. */ }

@Suite(.serialized)
struct RitualAuthenticatorTests {
    @Test
    func smsSignInFormsContextAndPacing() async throws { // swiftlint:disable:this function_body_length
        let client = LoginHTTPClient { request, number in
            let values = form(request)
            #expect(values["device_id"] == testDeviceID)
            #expect(values["client_id"] == "mobile-client-ios")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            if number == 1 {
                #expect(request.url?.path.hasSuffix("otp-resource/authorization") == true)
                #expect(Set(values.keys) == ["phone_country", "phone_calling", "phone_local", "challenge", "client_id", "device_id"])
                #expect(values["phone_country"] == "CA")
                #expect(values["phone_calling"] == "+1")
                #expect(values["phone_local"] == "5555550123")
                #expect(values["challenge"] == "synthetic-verification")
                #expect(String(data: request.httpBody!, encoding: .utf8)!.contains("phone_calling=%2B1"))
                return (authorization(), 200)
            }
            #expect(number == 2)
            #expect(request.url?.path.hasSuffix("openid-connect/token") == true)
            #expect(Set(values.keys) == ["client_os", "otp_code", "nsa_token", "scope", "client_id", "device_id", "grant_type", "app_ver"])
            #expect(values["grant_type"] == "password")
            #expect(values["scope"] == "offline_access")
            #expect(values["app_ver"] == "197001")
            #expect(values["client_os"] == "27.0.1")
            #expect(values["nsa_token"] == "temporary +/= token")
            #expect(values["otp_code"] == "123456")
            return (try signInToken(), 200)
        }
        var waits: [UInt64] = []
        var progress: [String] = []
        let report: (String) -> Void = { progress.append($0) }
        let auth = RitualAuthenticator(dependencies: DownloaderDependencies(client: client, sleep: { waits.append($0) }, now: Date.init, progress: report))
        let result = try await auth.login(
            phone: RitualPhoneNumber(number: "+1 (555) 555-0123"),
            deviceID: testDeviceID,
            getCaptchaHandler: { "synthetic-verification" },
            getOTPHandler: { challenge in
                #expect(challenge == .sms(phoneLastFour: "0123"))
                return "123 456"
            }
        )
        let saved = try JSONDecoder().decode(LoginAuthorizationSnapshot.self, from: JSONEncoder().encode(result))
        #expect(saved.refreshToken == "fresh-refresh")
        let context = try ProtoMessage(result.clientContext)
        #expect(context.string(1) == testDeviceID)
        #expect(context.string(4) == testUserID)
        #expect(context.bytes(8)?.isEmpty == true)
        let requestFields = ProtoMessage(fields: result.authorizationFields)
        #expect(try requestFields.message(157).fields.contains { $0.number == 4 && $0.integer == 90 })
        #expect(!waits.isEmpty)
        #expect(waits.allSatisfy { $0 > 0 && $0 <= 500_000_000 })
        #expect(progress.filter { $0.contains("POST ") }.count == 2)
        #expect(progress.filter { $0.contains("HTTP ") }.count == 2)
        for secret in ["synthetic-verification", "123456", "temporary", "fresh-refresh", "5555550123"] {
            #expect(!progress.joined().contains(secret))
        }
    }

    @Test
    func emailMFAUsesEmailPromptAndSameCodeExchange() async throws {
        let email = "s***@example.test"
        let client = LoginHTTPClient { request, number in
            if number == 1 {
                return (Data(#"{"token":"email-authorization","last_four":"0123","mfa_email":"s***@example.test"}"#.utf8), 200)
            }
            let values = form(request)
            #expect(values["nsa_token"] == "email-authorization")
            #expect(values["otp_code"] == "123456")
            #expect(values["grant_type"] == "password")
            return (try signInToken(), 200)
        }
        var progress: [String] = []
        let report: (String) -> Void = { progress.append($0) }
        let auth = RitualAuthenticator(dependencies: DownloaderDependencies(client: client, sleep: noPause, now: Date.init, progress: report))
        let result = try await auth.login(
            phone: RitualPhoneNumber(number: "5555550123"),
            deviceID: testDeviceID,
            getCaptchaHandler: { "fresh" },
            getOTPHandler: { challenge in
                #expect(challenge == .email(maskedAddress: email))
                #expect(challenge.prompt == "Email verification code (sent to s***@example.test)")
                return "123456"
            }
        )
        let saved = try JSONDecoder().decode(LoginAuthorizationSnapshot.self, from: JSONEncoder().encode(result))
        #expect(saved.refreshToken == "fresh-refresh")
        #expect(client.requests.count == 2)
        #expect(!progress.joined().contains(email))
    }

    @Test
    func authorizationDeliverySelectionAndValidation() throws {
        let decoder = JSONDecoder()
        for emailField in ["", #", "mfa_email": null"#, #", "mfa_email": """#] {
            let data = Data((#"{"token":"temporary","last_four":"0123""# + emailField + "}").utf8)
            #expect(try decoder.decode(RitualOTPChallenge.self, from: data).destination() == .sms(phoneLastFour: "0123"))
        }
        let emailOnly = Data(#"{"token":"temporary","mfa_email":"s***@example.test"}"#.utf8)
        #expect(try decoder.decode(RitualOTPChallenge.self, from: emailOnly).destination() == .email(maskedAddress: "s***@example.test"))
        for value in [
            #"{"token":"temporary","last_four":"0123","mfa_email":"invalid"}"#,
            #"{"token":"temporary","last_four":"bad"}"#
        ] {
            #expect(throws: RitualDownloadError.self) { try decoder.decode(RitualOTPChallenge.self, from: Data(value.utf8)).destination() }
        }
    }

    @Test(arguments: ["123", "1234567", "12a456", "١٢٣٤٥٦"])
    func invalidCodesDoNotSendTokenExchange(_ code: String) async throws {
        let client = LoginHTTPClient { _, _ in (authorization(), 200) }
        let auth = RitualAuthenticator(dependencies: DownloaderDependencies(client: client, sleep: noPause, now: Date.init, progress: discardProgress))
        await #expect(throws: RitualAuthenticationError.invalidCode) {
            try await auth.login(phone: RitualPhoneNumber(number: "5555550123"), deviceID: testDeviceID, getCaptchaHandler: { "fresh" }, getOTPHandler: { _ in code })
        }
        #expect(client.requests.count == 1)
    }

    @Test
    func verificationCancellationAndEmptyResultsSendNothing() async throws {
        let client = LoginHTTPClient { _, _ in
            Issue.record("Verification failure must not send requests")
            return (Data(), 500)
        }
        let auth = RitualAuthenticator(dependencies: DownloaderDependencies(client: client, sleep: noPause, now: Date.init, progress: discardProgress))
        await #expect(throws: RitualAuthenticationError.cancelled) {
            try await auth.login(
                phone: RitualPhoneNumber(number: "5555550123"),
                deviceID: testDeviceID,
                getCaptchaHandler: { throw RitualAuthenticationError.cancelled },
                getOTPHandler: { _ in "123456" }
            )
        }
        #expect(client.requests.isEmpty)
    }

    @Test
    func rejectedAuthorizationDoesNotAskForOTP() async throws {
        let client = LoginHTTPClient { _, _ in (Data(#"{"error":"private server detail"}"#.utf8), 403) }
        let auth = RitualAuthenticator(dependencies: DownloaderDependencies(client: client, sleep: noPause, now: Date.init, progress: discardProgress))
        var requestedCode = false
        await #expect(throws: RitualAuthenticationError.rejected(403)) {
            try await auth.login(
                phone: RitualPhoneNumber(number: "5555550123"),
                deviceID: testDeviceID,
                getCaptchaHandler: { "fresh" },
                getOTPHandler: { _ in requestedCode = true; return "123456" }
            )
        }
        #expect(!requestedCode)
        #expect(client.requests.count == 1)
        #expect(!RitualAuthenticationError.rejected(403).localizedDescription.contains("private"))
    }

    @Test
    func invalidDeviceIdentifierSendsNothing() async throws {
        let client = LoginHTTPClient { _, _ in
            Issue.record("An invalid device identifier must fail before sending a request")
            return (Data(), 500)
        }
        let auth = RitualAuthenticator(dependencies: DownloaderDependencies(client: client, sleep: noPause, now: Date.init, progress: discardProgress))
        await #expect(throws: RitualDownloadError.invalidContext("Invalid device UUID")) {
            try await auth.login(
                phone: RitualPhoneNumber(number: "5555550123"),
                deviceID: "not-a-uuid",
                getCaptchaHandler: { Issue.record("CAPTCHA must not be requested"); return "unused" },
                getOTPHandler: { _ in Issue.record("OTP must not be requested"); return "unused" }
            )
        }
        #expect(client.requests.isEmpty)
    }

    @Test
    func malformedAuthorizationResponseDoesNotAskForOTP() async throws {
        let client = LoginHTTPClient { _, _ in (Data(#"{"token":"","last_four":"0123"}"#.utf8), 200) }
        let auth = RitualAuthenticator(dependencies: DownloaderDependencies(client: client, sleep: noPause, now: Date.init, progress: discardProgress))
        var requestedCode = false
        await #expect(throws: RitualDownloadError.invalidResponse("Invalid sign-in authorization response")) {
            try await auth.login(
                phone: RitualPhoneNumber(number: "5555550123"),
                deviceID: testDeviceID,
                getCaptchaHandler: { "fresh" },
                getOTPHandler: { _ in requestedCode = true; return "123456" }
            )
        }
        #expect(!requestedCode)
        #expect(client.requests.count == 1)
    }

    @Test
    func rejectedCodeExchangeIsReported() async throws {
        let client = LoginHTTPClient { _, number in number == 1 ? (authorization(), 200) : (Data(), 403) }
        let auth = RitualAuthenticator(dependencies: DownloaderDependencies(client: client, sleep: noPause, now: Date.init, progress: discardProgress))
        await #expect(throws: RitualAuthenticationError.rejected(403)) {
            try await auth.login(
                phone: RitualPhoneNumber(number: "5555550123"),
                deviceID: testDeviceID,
                getCaptchaHandler: { "fresh" },
                getOTPHandler: { _ in "123456" }
            )
        }
        #expect(client.requests.count == 2)
    }

    @Test(arguments: [
        #"{"access_token":"","refresh_token":"refresh","expires_in":3600}"#,
        #"{"access_token":"invalid","refresh_token":"refresh","expires_in":3600}"#,
        #"{"access_token":"header.e30.signature","expires_in":3600}"#
    ])
    func malformedCodeExchangeTokenIsRejected(_ body: String) async throws {
        let client = LoginHTTPClient { _, number in number == 1 ? (authorization(), 200) : (Data(body.utf8), 200) }
        let auth = RitualAuthenticator(dependencies: DownloaderDependencies(client: client, sleep: noPause, now: Date.init, progress: discardProgress))
        await #expect(throws: RitualDownloadError.invalidResponse("Invalid sign-in token response")) {
            try await auth.login(
                phone: RitualPhoneNumber(number: "5555550123"),
                deviceID: testDeviceID,
                getCaptchaHandler: { "fresh" },
                getOTPHandler: { _ in "123456" }
            )
        }
        #expect(client.requests.count == 2)
    }

    @Test(arguments: ["f:provider:wrong", "not-a-user-id"])
    func malformedUserIdentityIsRejected(_ subject: String) async throws {
        let client = LoginHTTPClient { _, number in (number == 1 ? authorization() : try signInToken(subject: subject), 200) }
        let auth = RitualAuthenticator(dependencies: DownloaderDependencies(client: client, sleep: noPause, now: Date.init, progress: discardProgress))
        await #expect(throws: RitualDownloadError.self) {
            try await auth.login(phone: RitualPhoneNumber(number: "5555550123"), deviceID: testDeviceID, getCaptchaHandler: { "fresh" }, getOTPHandler: { _ in "123456" })
        }
        #expect(client.requests.count == 2)
    }

    @Test(arguments: ["5555550123", "1 555 555 0123", "+1 (555) 555-0123"])
    func northAmericanPhoneNormalization(_ text: String) throws {
        let phone = try RitualPhoneNumber(number: text)
        #expect(phone.nationalNumber == "5555550123")
        #expect(phone.callingCode == "+1")
        #expect(phone.countryCode == "CA")
    }

    @Test(arguments: ["123", "+49 5555550123", "5555550123x", "++15555550123", "٥٥٥٥٥٥٠١٢٣"])
    func invalidPhonesAreRejected(_ text: String) {
        #expect(throws: RitualAuthenticationError.invalidPhoneNumber) { try RitualPhoneNumber(number: text) }
    }

    @Test
    func verificationDocumentUsesCapturedConfiguration() {
        #expect(RitualVerificationPage.baseURL.absoluteString == "https://account.ritual.co/")
        #expect(RitualVerificationPage.siteKey == "6Lerr_YhAAAAALEmlnXaaPX2DO2TbMq36qgw4c1r")
        #expect(RitualVerificationPage.html.contains("size: 'invisible'"))
        #expect(RitualVerificationPage.html.contains("grecaptcha.execute(widget)"))
        #expect(RitualVerificationPage.html.contains("send({cancel:true})"))
    }
}
