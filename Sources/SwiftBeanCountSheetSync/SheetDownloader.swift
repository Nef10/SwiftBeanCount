//
//  SheetDownloader.swift
//  SwiftBeanCountSheetSync
//
//  Created by Steffen Kötte on 2020-02-11.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

#if os(macOS) || os(iOS)

import Foundation
import GoogleAuthentication
import SwiftBeanCountModel

enum SheetDownloader {

    enum DownloaderError: LocalizedError {
        case unableToParseResponse(String)
        case networkRequestFailed(String)

        public var errorDescription: String? {
            switch self {
            case .unableToParseResponse(message: let message):
                return "\(message)"
            case .networkRequestFailed(message: let message):
                return "\(message)"
            }
        }
    }

    static func download(authentication: Authentication, url: String, completion: @escaping (Result<[[String]], DownloaderError>) -> Void) {
        var sheetId = url.replacingOccurrences(of: "https://docs.google.com/spreadsheets/d/", with: "")
        sheetId = sheetId.components(separatedBy: "/")[0]
        getSheet(authentication: authentication, id: sheetId, completion: completion)
    }

    private static func getSheet(authentication: Authentication, id: String, completion: @escaping (Result<[[String]], DownloaderError>) -> Void) {
        let area = "Expenses!A:I"
        authentication.startAuthorizedGETRequest("https://sheets.googleapis.com/v4/spreadsheets/\(id)/values/\(area)") { result in
            DispatchQueue.global(qos: .userInitiated).async {
                switch result {
                case .success(let response):
                    guard let data = try? JSONSerialization.jsonObject(with: response.data, options: []) as? [String: Any], let values = data["values"] as? [[String]] else {
                        completion(.failure(.unableToParseResponse("Unable to parse response: \(response.dataString() ?? "")")))
                        return
                    }
                    completion(.success(values))
                case .failure(let error):
                    completion(.failure(.networkRequestFailed("Network request failed: \(error.localizedDescription)")))
                }
            }
        }
    }

}

#endif
