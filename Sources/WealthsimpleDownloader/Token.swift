//
//  Token.swift
//
//
//  Created by Steffen Kötte on 2020-07-12.
//

import Foundation
 #if canImport(FoundationNetworking)
 import FoundationNetworking
 #endif

/// Errors which can happen when getting a Token
public enum TokenError: Error, Equatable {
    /// When no token is found
    case noToken
    /// When the received data is not valid JSON
    case invalidJson(error: String)
    /// When the received JSON does not have the right type
    case invalidJsonType(json: Data)
    /// When the paramters could not be converted to JSON
    case invalidParameters(parameters: [String: String])
    /// When the received JSON does not have all expected values
    case missingResultParamenter(json: String)
    /// When an HTTP error occurs
    case httpError(error: String)
    /// When no data is received from the HTTP request
    case noDataReceived
}

struct Token {

    private static let credentialStorageKeyAccessToken = "accessToken"
    private static let credentialStorageKeyRefreshToken = "refreshToken"
    private static let credentialStorageKeyExpiry = "expiry"

    private static var url: URL { URLConfiguration.shared.urlObject(for: "oauth/v2/token")! }
    private static var testUrl: URL { URLConfiguration.shared.urlObject(for: "oauth/v2/token/info")! }
    private static var clientId = "4da53ac2b03225bed1550eba8e4611e086c7b905a3855e6ed12ea08c246758fa" // From the website
    private static var scope = "read" // the clientId supports some write scopes, but as this library only reads we limit it for safety

    private let accessToken: String
    private let refreshToken: String
    private let expiry: Date
    private let credentialStorage: CredentialStorage

    private init(accessToken: String, refreshToken: String, expiry: Date, credentialStorage: CredentialStorage) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiry = expiry
        self.credentialStorage = credentialStorage
    }

    private init(json: [String: Any], credentialStorage: CredentialStorage) throws {
        guard let accessToken = json["access_token"] as? String,
              let expiresIn = json["expires_in"] as? Int,
              let createdAt = json["created_at"] as? Int,
              let refreshToken = json["refresh_token"] as? String else {
            throw TokenError.missingResultParamenter(json: String(data: try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]), encoding: .utf8) ?? "")
        }
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        let expiresAt = createdAt + expiresIn
        self.expiry = Date(timeIntervalSince1970: TimeInterval(expiresAt))
        self.credentialStorage = credentialStorage
    }

    static func getToken(username: String, password: String, otp: String, credentialStorage: CredentialStorage, completion: @escaping (Result<Self, TokenError>) -> Void) {
        var request = URLRequest(url: url)
        request.setValue(otp, forHTTPHeaderField: "x-wealthsimple-otp")
        let json = [
            "grant_type": "password",
            "username": username,
            "password": password,
            "scope": scope,
            "client_id": clientId
        ]
        sendTokenRequest(parameters: json, request: request, credentialStorage: credentialStorage, completion: completion)
    }

    static func getToken(from credentialStorage: CredentialStorage, completion: @escaping (Self?) -> Void) {
        guard let accessToken = credentialStorage.read(credentialStorageKeyAccessToken),
              let refreshToken = credentialStorage.read(credentialStorageKeyRefreshToken),
              let expiryString = credentialStorage.read(credentialStorageKeyExpiry),
              let expiryDouble = Double(expiryString) else {
            completion(nil)
            return
        }
        let token = Self(accessToken: accessToken, refreshToken: refreshToken, expiry: Date(timeIntervalSince1970: expiryDouble), credentialStorage: credentialStorage)
        token.refreshIfNeeded {
            switch $0 {
            case .failure:
                completion(nil)
            case let .success(newToken):
                newToken.testIfValid {
                    if $0 {
                        completion(newToken)
                    } else {
                        completion(nil)
                    }
                }
            }
        }
    }

    private static func sendTokenRequest(
        parameters json: [String: String],
        request urlRequest: URLRequest,
        credentialStorage: CredentialStorage,
        completion: @escaping (Result<Self, TokenError>) -> Void
    ) {
        var request = urlRequest
        let session = URLSession.shared
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json, options: []) else {
            completion(.failure(TokenError.invalidParameters(parameters: json)))
            return
        }
        let task = session.uploadTask(with: request, from: jsonData) { data, response, error in
            handleTokenResponse(data: data, response: response, error: error, credentialStorage: credentialStorage, completion: completion)
        }
        task.resume()
    }

    private static func handleTokenResponse(
        data: Data?,
        response: URLResponse?,
        error: Error?,
        credentialStorage: CredentialStorage,
        completion: (Result<Self, TokenError>) -> Void
    ) {
        guard let data else {
            if let error {
                completion(.failure(TokenError.httpError(error: error.localizedDescription)))
            } else {
                completion(.failure(TokenError.noDataReceived))
            }
            return
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            completion(.failure(TokenError.httpError(error: "No HTTPURLResponse")))
            return
        }
        guard httpResponse.statusCode == 200 else {
            completion(.failure(TokenError.httpError(error: "Status code \(httpResponse.statusCode)")))
            return
        }
        completion(parse(data: data, credentialStorage: credentialStorage))
    }

    private static func parse(data: Data, credentialStorage: CredentialStorage) -> Result<Self, TokenError> {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return .failure(TokenError.invalidJsonType(json: data))
        }
        do {
            let token = try Self(json: json, credentialStorage: credentialStorage)
            token.saveToken()
            return .success(token)
        } catch {
            return .failure(error as! TokenError) // swiftlint:disable:this force_cast
        }
    }

    private func testIfValid(completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: Self.testUrl)
        let session = URLSession.shared
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authenticateRequest(request) { request in
            let task = session.dataTask(with: request) { _, response, error in
                guard error == nil else {
                    completion(false)
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false)
                    return
                }
                completion(httpResponse.statusCode == 200)
            }
            task.resume()
        }
    }

    func authenticateRequest(_ request: URLRequest, completion: (URLRequest) -> Void) {
        var requestCopy = request
        requestCopy.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        completion(requestCopy)
    }

    func refreshIfNeeded(completion: @escaping (Result<Self, TokenError>) -> Void) {
        if needsRefresh() {
            refresh(completion: completion)
        } else {
            completion(.success(self))
        }
    }

    private func needsRefresh() -> Bool {
        expiry < Date()
    }

    private func refresh(completion: @escaping (Result<Self, TokenError>) -> Void) {
        let request = URLRequest(url: Self.url)
        let json = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": Self.clientId
        ]
        Self.sendTokenRequest(parameters: json, request: request, credentialStorage: credentialStorage, completion: completion)
    }

    private func saveToken() {
        credentialStorage.save(accessToken, for: Self.credentialStorageKeyAccessToken)
        credentialStorage.save(refreshToken, for: Self.credentialStorageKeyRefreshToken)
        credentialStorage.save(String(expiry.timeIntervalSince1970), for: Self.credentialStorageKeyExpiry)
    }

}
