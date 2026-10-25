import Foundation

enum RitualConstants {
    static let clientID = "mobile-client-ios"
    static let appVersion = "197001"
    static let clientOS = "27.0.1"
    static let userAgent = "Ritual/1.97.1.4 CFNetwork/3896.100.1.2.1 Darwin/27.0.0"
    static let tokenURL = URL(string: "https://account.ritual.co/auth/realms/ritual-customer/protocol/openid-connect/token")!
    static let authorizationURL = URL(string: "https://account.ritual.co/auth/realms/ritual-customer/otp-resource/authorization")!
    static let apiURL = URL(string: "https://app.ritual.co/starhopper")!
}
