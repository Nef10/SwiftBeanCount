import Foundation

/// Connects the authentication process with the delegate and provides a simple interface to obtain credentials.
final class RitualLogin {
    private weak var delegate: RitualDownloaderDelegate?
    private let authenticator: RitualAuthenticatorProvider
    private let overwriteGetCaptchaHandler: (() async throws -> String)?
    /// Indicates weather a login was performed. Its false if saved credentials were used.
    private(set) var signedIn = false

    #if canImport(WebKit) && (canImport(UIKit) || canImport(AppKit))
    private var verificationView: RitualVerificationView?
    #endif

    init(
        delegate: RitualDownloaderDelegate?,
        authenticator: RitualAuthenticatorProvider,
        overwriteGetCaptchaHandler: (() async throws -> String)?,
    ) {
        self.delegate = delegate
        self.authenticator = authenticator
        self.overwriteGetCaptchaHandler = overwriteGetCaptchaHandler
    }

    func credentials() async throws -> RitualAuthorization {
        if let json = delegate?.readCredential("ritual-authorization"), let authorization = try? JSONDecoder().decode(RitualAuthorization.self, from: Data(json.utf8)) {
            return authorization
        }
        let phone = try await phoneNumber()
        let deviceID = deviceIdentifier()
        let result = try await authenticator.login(
            phone: phone,
            deviceID: deviceID,
            getCaptchaHandler: { try await self.getCaptcha() },
            getOTPHandler: { try await self.otpCode(for: $0) }
        )
        let json = String(data: try JSONEncoder().encode(result), encoding: .utf8)!
        delegate?.saveCredential(json, for: "ritual-authorization")
        signedIn = true
        return result
    }

    func clearSession() {
        delegate?.saveCredential("", for: "ritual-authorization")
        delegate?.saveCredential("", for: "ritual-device-id")
    }

    /// Returns a unique device identifier. If one is already saved it is returned, otherwise a new one is generated, saved and returned.
    private func deviceIdentifier() -> String {
        if let saved = delegate?.readCredential("ritual-device-id"), UUID(uuidString: saved) != nil {
            return saved
        }
        let identifier = UUID().uuidString
        delegate?.saveCredential(identifier, for: "ritual-device-id")
        return identifier
    }

    /// Reads phone number from saved credentials, if not present or valid requests it from the delegate and saves it.
    private func phoneNumber() async throws -> RitualPhoneNumber {
        if let number = delegate?.readCredential("ritual-phone-number"),
           let phone = try? RitualPhoneNumber(number: number) {
            return phone
        }
        guard let delegate else {
            throw RitualAuthenticationError.verificationUnavailable
        }
        let number = await input(validate: { (try? RitualPhoneNumber(number: $0)) != nil }, request: {
            delegate.requestPhoneNumber(callingCode: "+1", completion: $0)
        })
        let phone = try RitualPhoneNumber(number: number)
        delegate.saveCredential(phone.nationalNumber, for: "ritual-phone-number")
        return phone
    }

    /// Requests an OTP code from the delegate and validates it.
    private func otpCode(for destination: RitualOTPDestination) async throws -> String {
        guard let delegate else {
            throw RitualAuthenticationError.verificationUnavailable
        }
        return await input(validate: {
            let digits = $0.filter { !$0.isWhitespace }
            return digits.count == 6 && digits.allSatisfy { $0.isASCII && $0.isNumber }
        }, request: {
            delegate.requestVerificationCode(destination: destination, completion: $0)
        })
    }

    /// Requests input from the delegate and validates it. Returns the input when it is valid.
    private func input(validate: @escaping (String) -> Bool, request: (@escaping (String) -> Bool) -> Void) async -> String {
        await withCheckedContinuation { continuation in
            var submitted = false
            request { text in
                let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !submitted, validate(text) else {
                    return false
                }
                submitted = true
                continuation.resume(returning: text)
                return true
            }
        }
    }

    /// Requests a captcha from the delegate and returns it. Throws an error if no delegate is present or if the platform does not support web views.
    /// Can be overwritten with `overwriteGetCaptchaHandler` for testing purposes.
    private func getCaptcha() async throws -> String {
        if let overwriteGetCaptchaHandler {
            return try await overwriteGetCaptchaHandler()
        }
        #if canImport(WebKit) && (canImport(UIKit) || canImport(AppKit))
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                guard let parent = self.delegate?.view() else {
                    continuation.resume(throwing: RitualAuthenticationError.verificationUnavailable)
                    return
                }
                let view = RitualVerificationView()
                self.verificationView = view
                view.start(in: parent) { result in
                    self.verificationView = nil
                    self.delegate?.removeView()
                    continuation.resume(with: result)
                }
            }
        }
        #else
        throw RitualAuthenticationError.verificationUnavailable
        #endif
    }
}
