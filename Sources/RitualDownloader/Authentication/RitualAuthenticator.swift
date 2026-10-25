import Foundation

/// Sign-in and session failures which do not expose server responses or credentials.
public enum RitualAuthenticationError: LocalizedError, Equatable {
    /// The phone number or country/calling-code configuration is invalid.
    case invalidPhoneNumber
    /// A fresh CAPTCHA result could not be obtained.
    case verificationFailed
    /// The host application cannot present the verification view.
    case verificationUnavailable
    /// The user cancelled verification.
    case cancelled
    /// The verification code must contain six ASCII digits.
    case invalidCode
    /// The server rejected an SMS authorization or code exchange.
    case rejected(Int)
    /// A saved refresh token is no longer valid; sign in again.
    case sessionExpired
    /// When the authentication is not set
    case noAuthentication

    public var errorDescription: String? {
        switch self {
        case .invalidPhoneNumber:
            return "Enter a valid phone number for the configured country and calling code."
        case .verificationFailed:
            return "Ritual verification failed or expired. Please try signing in again."
        case .verificationUnavailable:
            return "Ritual sign-in requires an application that can show the verification view."
        case .cancelled:
            return "Ritual sign-in was cancelled."
        case .invalidCode:
            return "Enter the six-digit verification code."
        case .rejected(let status):
            return "Ritual sign-in was rejected (HTTP \(status)). Restart the import to request a new code."
        case .sessionExpired:
            return "The saved Ritual session has expired. Sign in again."
        case .noAuthentication:
            return "The authentication was not successfully set."
        }
    }
}

/// The country, calling prefix and national number required by Ritual's SMS authorization.
public struct RitualPhoneNumber: Equatable, Sendable {
    /// Two-letter country code, for example CA.
    public let countryCode: String
    /// International calling prefix including +, for example +1.
    public let callingCode: String
    /// National number without separators or calling prefix.
    public let nationalNumber: String

    /// Normalizes a national or international phone number for the configured country.
    public init(number: String, countryCode: String = "CA", callingCode: String = "+1") throws {
        let number = number.trimmingCharacters(in: .whitespacesAndNewlines)
        let country = countryCode.uppercased()
        let prefix = String(callingCode.dropFirst())
        guard country.count == 2, country.allSatisfy({ $0.isASCII && $0.isLetter }), callingCode.first == "+",
              (1...3).contains(prefix.count), Self.digits(prefix), !prefix.hasPrefix("0"),
              number.allSatisfy({ "+0123456789 ()-.".contains($0) }), number.filter({ $0 == "+" }).count <= 1,
              !number.contains("+") || number.first == "+" else {
            throw RitualAuthenticationError.invalidPhoneNumber
        }
        var digits = number.filter { $0.isASCII && $0.isNumber }
        if number.hasPrefix("+") {
            guard digits.hasPrefix(prefix) else {
                throw RitualAuthenticationError.invalidPhoneNumber
            }
            digits.removeFirst(prefix.count)
        } else if prefix == "1", digits.count == 11, digits.hasPrefix("1") {
            digits.removeFirst()
        }
        guard (4...15).contains(digits.count), digits.count + prefix.count <= 15,
              prefix != "1" || digits.count == 10 else {
            throw RitualAuthenticationError.invalidPhoneNumber
        }
        self.countryCode = country
        self.callingCode = callingCode
        nationalNumber = digits
    }

    static func digits(_ value: String) -> Bool { !value.isEmpty && value.allSatisfy { $0.isASCII && $0.isNumber } }
}

struct Token: Decodable {
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }

    let accessToken: String
    let refreshToken: String?
    let expiresIn: Double?
}

class RitualAuthorization: Codable {

    private struct Subject: Decodable {
        let sub: String
    }

    private var accessToken: String
    private var refreshToken: String
    private var expiresAt: Date
    private let userID: String
    private let context: RitualDeviceContext

    var userAgent: String {
        context.userAgent
    }

    var clientContext: Data {
        context.clientContext
    }

    var authorizationFields: [ProtoField] {
        [.bytes(157, context.capabilities), .string(255, accessToken)]
    }

    init(token: Token, deviceID: String) throws {
        guard let refreshToken = token.refreshToken, let expiresIn = token.expiresIn, !refreshToken.isEmpty,
              !token.accessToken.isEmpty, !refreshToken.contains(where: \.isWhitespace), !token.accessToken.contains(where: \.isWhitespace) else {
            throw RitualDownloadError.invalidResponse("Invalid token response")
        }

        self.accessToken = token.accessToken
        self.refreshToken = refreshToken
        self.expiresAt = Date.now.addingTimeInterval(expiresIn)

        let parts = accessToken.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, accessToken.count <= 1_048_576 else {
            throw RitualDownloadError.invalidResponse("Invalid access token")
        }
        var payload = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload), let subject = try? JSONDecoder().decode(Subject.self, from: data),
              let userID = subject.sub.split(separator: ":").last.map(String.init), userID.count == 32,
              userID.allSatisfy({ $0.isASCII && $0.isHexDigit }) else {
            throw RitualDownloadError.invalidResponse("Access token has no Ritual user ID")
        }

        self.userID = userID
        self.context = try Self.context(userID: userID, deviceID: deviceID)
    }

    private static func context(userID: String, deviceID: String) throws -> RitualDeviceContext {
        let locale = ProtoMessage(fields: [.string(1, "en"), .string(2, "CA")]).encoded
        let version = ProtoMessage(fields: [.varint(1, 1), .varint(2, 97), .varint(3, 1), .varint(4, 4)]).encoded
        let operatingSystem = ProtoMessage(fields: [.varint(1, 27), .varint(2, 0), .varint(3, 1)]).encoded
        let device = ProtoMessage(fields: [.bytes(1, operatingSystem), .string(2, "Apple"), .string(3, "iPhone")]).encoded
        let context = ProtoMessage(fields: [
            .string(1, deviceID), .varint(3, 197_001), .string(4, userID), .bytes(5, locale), .varint(6, 1),
            .bytes(8, Data()), .varint(9, 0), .bytes(11, device), .bytes(12, version), .bytes(13, locale)
        ])
        // Empty location expresses no device location; no captured coordinates are reused.
        let groups: [UInt64] = [4, 33, 34, 36, 9, 12, 15, 18, 21, 25, 27]
        let features: [UInt64] = [
            3, 4, 2, 8, 5, 6, 7, 9, 11, 10, 12, 15, 14, 17, 18, 19, 20, 22, 21, 25, 24, 26, 28, 30, 33, 32, 34, 29, 37, 38, 36, 46,
            40, 39, 41, 43, 42, 44, 35, 45, 47, 48, 53, 56, 51, 52, 55, 59, 58, 61, 62, 66, 67, 68, 70, 71, 72, 73, 74, 75, 76, 78,
            77, 79, 80, 81, 82, 83, 86, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 102, 103, 104, 105
        ]
        let capabilities = ProtoMessage(fields: groups.map { .varint(1, $0) } + [4, 5].flatMap { field in features.map { .varint(field, $0) } })
        return try RitualDeviceContext(clientContext: context.encoded, capabilities: capabilities.encoded, userAgent: RitualConstants.userAgent)
    }

    @discardableResult
    func refreshIfNeeded(dependencies: DownloaderDependencies) async throws -> Bool {
        guard needsRefresh() else {
            return false
        }
        try await refresh(dependencies: dependencies)
        return true
    }

    func refresh(dependencies: DownloaderDependencies) async throws {
        let values = ["grant_type": "refresh_token", "client_id": "mobile-client-ios", "scope": "offline_access", "refresh_token": refreshToken]
        let response = try await Request.sent(
            RitualConstants.tokenURL,
            values: values,
            label: "token refresh",
            dependencies: dependencies
        )

        if [400, 401].contains(response.1.statusCode), let object = try? JSONSerialization.jsonObject(with: response.0) as? [String: Any],
              let error = object["error"] as? String, error == "invalid_grant" || error == "invalid_token" {
            throw RitualAuthenticationError.sessionExpired
        }

        guard (200..<300).contains(response.1.statusCode) else {
            throw RitualDownloadError.httpStatus(response.1.statusCode)
        }
        let token = try JSONDecoder().decode(Token.self, from: response.0)
        guard let expiresIn = token.expiresIn, !token.accessToken.isEmpty else {
            throw RitualDownloadError.invalidResponse("Invalid refreshed access token response")
        }
        accessToken = token.accessToken
        refreshToken = token.refreshToken ?? refreshToken
        expiresAt = Date.now.addingTimeInterval(expiresIn)
    }

    private func needsRefresh() -> Bool {
        expiresAt <= Date.now.addingTimeInterval(30)
    }

}

/// Delivery destination returned by Ritual when authorizing a sign-in code.
public enum RitualOTPDestination: Equatable, Sendable {
    /// Code sent to the phone number identified by its final four digits.
    case sms(phoneLastFour: String)
    /// Email verification requested by Ritual, with its server-provided masked address.
    case email(maskedAddress: String)

    /// User-facing prompt suitable for the importer's one-time-code input.
    public var prompt: String {
        switch self {
        case .sms(let lastFour):
            return "SMS code (phone ending \(lastFour))"
        case .email(let address):
            return "Email verification code (sent to \(address))"
        }
    }
}

struct RitualOTPChallenge: Decodable {
    enum CodingKeys: String, CodingKey {
        case token
        case lastFour = "last_four"
        case mfaEmail = "mfa_email"
    }

    let token: String
    let lastFour: String?
    let mfaEmail: String?

    func destination() throws -> RitualOTPDestination {
        if let email = mfaEmail?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            guard email.count <= 254, email.contains("@"), !email.contains(where: { $0.isWhitespace || $0.isNewline }) else {
                throw RitualDownloadError.invalidResponse("Invalid email verification destination")
            }
            return .email(maskedAddress: email)
        }
        guard let lastFour, lastFour.count == 4, RitualPhoneNumber.digits(lastFour) else {
            throw RitualDownloadError.invalidResponse("Missing verification destination")
        }
        return .sms(phoneLastFour: lastFour)
    }
}

protocol RitualAuthenticatorProvider {
    func login(
        phone: RitualPhoneNumber,
        deviceID: String,
        getCaptchaHandler: () async throws -> String,
        getOTPHandler: (RitualOTPDestination) async throws -> String
    ) async throws -> RitualAuthorization
}

/// Signs in to Ritual using phone authorization, fresh browser verification, and a user-entered SMS or email code.
class RitualAuthenticator {

    private var networkRequestNumber = 0

    private let dependencies: DownloaderDependencies

    init(dependencies: DownloaderDependencies) {
        self.dependencies = dependencies
    }

    private static func getOTPHandler(destination: RitualOTPDestination, getOTPHandler: (RitualOTPDestination) async throws -> String) async throws -> String {
        let otp = try await getOTPHandler(destination).filter { !$0.isWhitespace }
        guard otp.count == 6, RitualPhoneNumber.digits(otp) else {
            throw RitualAuthenticationError.invalidCode
        }
        return otp
    }

    /// Signs in without retaining verification or one-time codes. Each call creates an independent login run.
    /// - Parameters:
    ///   - phone: Normalized telephone number and country.
    ///   - deviceID: A persistent device UUID generated by the host application.
    ///   - getCaptchaHandler: Presents the verification page and returns a fresh CAPTCHA result.
    ///   - getOTPHandler: Requests a one-time code using the delivery destination returned by Ritual.
    func login(
        phone: RitualPhoneNumber,
        deviceID: String,
        getCaptchaHandler: () async throws -> String,
        getOTPHandler: (RitualOTPDestination) async throws -> String
    ) async throws -> RitualAuthorization {
        try Task.checkCancellation()
        guard UUID(uuidString: deviceID) != nil else {
            throw RitualDownloadError.invalidContext("Invalid device UUID")
        }
        let captchaCode = try await getCaptchaHandler()
        let otpChallenge = try await authorize(phone: phone, captchaCode: captchaCode, deviceID: deviceID)
        let otp = try await Self.getOTPHandler(destination: otpChallenge.destination(), getOTPHandler: getOTPHandler)
        return try await login(deviceID: deviceID, otpChallenge: otpChallenge, otp: otp)
    }

    private func login(deviceID: String, otpChallenge: RitualOTPChallenge, otp: String) async throws -> RitualAuthorization {
        let response = try await Request.sent(
            RitualConstants.tokenURL,
            values: [
                "client_id": RitualConstants.clientID,
                "device_id": deviceID,
                "app_ver": RitualConstants.appVersion,
                "client_os": RitualConstants.clientOS,
                "scope": "offline_access",
                "grant_type": "password",
                "nsa_token": otpChallenge.token,
                "otp_code": otp
            ],
            label: "verification code exchange",
            dependencies: dependencies
        )
        guard (200..<300).contains(response.1.statusCode) else {
            throw RitualAuthenticationError.rejected(response.1.statusCode)
        }
        guard let token = try? JSONDecoder().decode(Token.self, from: response.0), let authorization = try? RitualAuthorization(token: token, deviceID: deviceID) else {
            throw RitualDownloadError.invalidResponse("Invalid sign-in token response")
        }
        return authorization
    }

    private func authorize(phone: RitualPhoneNumber, captchaCode: String, deviceID: String) async throws -> RitualOTPChallenge {
        let response = try await Request.sent(
            RitualConstants.authorizationURL,
            values: [
                "phone_country": phone.countryCode,
                "phone_calling": phone.callingCode,
                "phone_local": phone.nationalNumber,
                "client_id": RitualConstants.clientID,
                "device_id": deviceID,
                "challenge": captchaCode
            ],
            label: "request sign-in code",
            dependencies: dependencies
        )
        guard (200..<300).contains(response.1.statusCode) else {
            throw RitualAuthenticationError.rejected(response.1.statusCode)
        }
        guard let value = try? JSONDecoder().decode(RitualOTPChallenge.self, from: response.0), !value.token.isEmpty, value.token.count <= 1_048_576 else {
            throw RitualDownloadError.invalidResponse("Invalid sign-in authorization response")
        }
        return value
    }

}

extension RitualAuthenticator: RitualAuthenticatorProvider {}
