//
//  Authentication.swift
//  GoogleAuthentication
//
//  Created by Steffen Kötte on 2020-02-10.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

#if os(iOS) || os(macOS)

import AuthenticationServices
import Foundation
import KeychainAccess
import OAuthSwift

/// Wraper around OAuthSwift and KeychainAccess to authenticate to Google APIs while automatically saving the tokens into the keychain
public class Authentication {

    private static let keychainKey = "googleOAuthCredentials"

    private let scope: String
    private let redirectURI: String
    private let keychain: Keychain
    private var oAuth: OAuth2Swift

    /// Creates an Authentication instance with the configuration from an OAuth App
    /// - Parameters:
    ///   - appID: The app ID from Google (Part of the consumer key in front of .apps.googleusercontent.com
    ///            or part of the redirect URI after com.googleusercontent.apps.
    ///   - consumerSecret: OAuth consumer secret
    ///   - scope: scope of the authorization
    ///   - keychainService: string used for the keychain identification, usually your Bundle ID
    public init(
        appID: String,
        consumerSecret: String,
        scope: String,
        keychainService: String
    ) {
        self.oAuth = OAuth2Swift(
            consumerKey: "\(appID).apps.googleusercontent.com",
            consumerSecret: consumerSecret,
            authorizeUrl: "https://accounts.google.com/o/oauth2/auth",
            accessTokenUrl: "https://accounts.google.com/o/oauth2/token",
            responseType: "code"
        )
        self.redirectURI = "com.googleusercontent.apps.\(appID)"
        self.scope = scope
        self.keychain = Keychain(service: keychainService)

        oAuth.allowMissingStateCheck = true
    }

    /// Authenticates the user
    ///
    /// If the keychain has a token saved it retreives this and returns without calling Google.
    /// After successful authentication the tokens are saved in the keychain
    ///
    /// - Parameter
    ///   - authenticationPresentationContextProvider: ASWebAuthenticationPresentationContextProviding for ASWebAuthenticationSession to show a dialog on if needed
    ///   - completion: OAuthSwift.TokenCompletionHandler
    public func authenticate(
        authenticationPresentationContextProvider: ASWebAuthenticationPresentationContextProviding,
        completion: @escaping OAuthSwift.TokenCompletionHandler
    ) {
        if retreiveAndApplyCredentials() {
            completion(.success((oAuth.client.credential, nil, [:])))
            return
        }

        let handler = ASWebAuthenticationURLHandler(callbackURLScheme: redirectURI, authenticationPresentationContextProvider: authenticationPresentationContextProvider)
        oAuth.authorizeURLHandler = handler

        _ = oAuth.authorize(withCallbackURL: URL(string: "\(redirectURI):/oauth2Callback")!, scope: scope, state: "") { result in
            if case let .success((credential, _, _)) = result {
                self.saveCredential(credential)
            }
            completion(result)
        }
    }

    /// Sends a GET request with the neccessary authnetication headers
    ///
    /// Handels token renewals automatically, including saving the updated token to the keychain
    ///
    /// - Parameters:
    ///   - url: URL to call
    ///   - completion: OAuthSwiftHTTPRequest.CompletionHandler
    /// - Returns: OAuthSwiftRequestHandle?
    @discardableResult
    public func startAuthorizedGETRequest(_ url: URLConvertible, completionHandler completion: @escaping OAuthSwiftHTTPRequest.CompletionHandler) -> OAuthSwiftRequestHandle? {
        oAuth.startAuthorizedRequest(url,
                                     method: .GET,
                                     parameters: [:],
                                     onTokenRenewal: { result in
                                         if case let .success(credential) = result {
                                             self.saveCredential(credential)
                                         }
                                     },
                                     completionHandler: completion)
    }

    private func saveCredential(_ credential: OAuthSwiftCredential) {
        do {
            let codedData = try NSKeyedArchiver.archivedData(withRootObject: credential, requiringSecureCoding: true)
            keychain[data: Self.keychainKey] = codedData
        } catch {
            print("Error while saving credentails in keychain: \(error)")
        }
    }

    private func retreiveAndApplyCredentials() -> Bool {
        if let credentialData = keychain[data: Self.keychainKey] {
            do {
                if let credential = try NSKeyedUnarchiver.unarchivedObject(ofClass: OAuthSwiftCredential.self, from: credentialData) {
                    oAuth.client.credential.oauthToken = credential.oauthToken
                    oAuth.client.credential.oauthRefreshToken = credential.oauthRefreshToken
                    oAuth.client.credential.oauthTokenSecret = credential.oauthTokenSecret
                    oAuth.client.credential.oauthTokenExpiresAt = credential.oauthTokenExpiresAt
                    oAuth.client.credential.version = credential.version
                    oAuth.client.credential.signatureMethod = credential.signatureMethod
                    return true
                }
            } catch {
                print("Error while getting credentails from keychain: \(error)")
            }
        }
        return false
    }

}

#endif
