import Foundation

/// An online user account
public protocol User {

    /// User name used to login
    var userName: String { get }
    /// Credit Card Accounts the user has access to
    var accounts: [Account] { get }
    /// Authenticated
    var authenticated: Bool { get }

}

/// A rogers online user account
public struct RogersUser: User, Codable {

    enum CodingKeys: String, CodingKey {
        case userName
        case authenticated
        case rogersAccounts = "accounts"
    }

    public let userName: String
    public let authenticated: Bool
    private let rogersAccounts: [RogersAccount]

    public var accounts: [Account] {
        rogersAccounts
    }

}
