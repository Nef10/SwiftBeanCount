//
//  ASWebAuthenticationURLHandler.swift
//  GoogleAuthentication
//
//  Created by Steffen Kötte on 2020-02-10.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

#if os(iOS) || os(macOS)

import AuthenticationServices
import Foundation
import OAuthSwift

class ASWebAuthenticationURLHandler: OAuthSwiftURLHandlerType {
    var webAuthSession: ASWebAuthenticationSession?
    let callbackURLScheme: String

    weak var authenticationPresentationContextProvider: ASWebAuthenticationPresentationContextProviding?

    public init(callbackURLScheme: String, authenticationPresentationContextProvider: ASWebAuthenticationPresentationContextProviding?) {
        self.callbackURLScheme = callbackURLScheme
        self.authenticationPresentationContextProvider = authenticationPresentationContextProvider
    }

    public func handle(_ url: URL) {
        webAuthSession = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme) { callback, error in
            guard let callback else {
                let message = error?.localizedDescription.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
                let urlString = "\(self.callbackURLScheme)?error=\(message ?? "Unknown")"
                guard let url = URL(string: urlString) else {
                    print("Error: Could not convert URL String to URL")
                    return
                }
                OAuthSwift.handle(url: url)
                return
            }
            OAuthSwift.handle(url: callback)
        }
        webAuthSession?.presentationContextProvider = authenticationPresentationContextProvider
        _ = webAuthSession?.start()
    }
}

#endif
