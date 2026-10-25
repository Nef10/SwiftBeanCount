//
//  GoogleSheetsExporter.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2026-05-23.
//

import AuthenticationServices
import Foundation
import GoogleAuthentication
import SwiftBeanCountModel
import SwiftBeanCountSheetSync

private enum GoogleSheetsExporterError: LocalizedError {
    case missingInputHandler
    case missingSheetURL

    var errorDescription: String? {
        switch self {
        case .missingInputHandler:
            "Unable to request the required exporter input."
        case .missingSheetURL:
            "Please provide a valid Google Sheets URL."
        }
    }
}

private final class GoogleAuthContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        ASPresentationAnchor()
    }
}

final class GoogleSheetsExporter: LedgerExporter {

    static var exporterName: String { ExportType.googleSheets.displayName }

    private static let recentSheetURLsKey = "recentGoogleSheetURLs"
    private static let recentSheetURLsLimit = 3

    private static var recentSheetURLs: [String] {
        let recents = UserDefaults.standard.stringArray(forKey: Self.recentSheetURLsKey) ?? []
        return Array(recents
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(Self.recentSheetURLsLimit))
    }

    weak var delegate: LedgerExporterDelegate?

    var exportName: String { Self.exporterName }

    private let ledger: Ledger
    private let authentication = Authentication(appID: "1039239506189-ia9evaeo7ggpp4p9f8c94dqvappke54h",
                                                consumerSecret: "08duXE23dRYMpBt1BXedX2aw",
                                                scope: "https://www.googleapis.com/auth/spreadsheets.readonly",
                                                keychainService: "de.steffenkoette.SwiftBeanCountSheetSync")

    init(ledger: Ledger) {
        self.ledger = ledger
    }

    private static func format(result: SyncResult) -> String {
        var text = ""

        if !result.parserErrors.isEmpty {
            text += "Errors (\(result.parserErrors.count)):\n"
            text += result.parserErrors.map { "- \($0.localizedDescription)" }.joined(separator: "\n")
            text += "\n\n"
        }

        if result.transactions.isEmpty {
            text += "No new transactions to upload."
        } else {
            text += "Transactions to upload (\(result.transactions.count)):\n"
            text += result.sheetCells.map { row in row.joined(separator: "\t") }.joined(separator: "\n\n")
        }

        return text
    }

    private static func saveRecentSheetURL(_ sheetURL: String) {
        let trimmedSheetURL = sheetURL.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedSheetURL.isEmpty else {
            return
        }

        var recents = Self.recentSheetURLs.filter { $0 != trimmedSheetURL }
        recents.insert(trimmedSheetURL, at: 0)
        UserDefaults.standard.set(Array(recents.prefix(Self.recentSheetURLsLimit)), forKey: Self.recentSheetURLsKey)
    }

    func export(completion: @escaping (Result<String, Error>) -> Void) {
        switch requestSheetURL() {
        case .failure(let error):
            completion(.failure(error))
        case .success(let sheetURL):
            startAuthenticatedExport(sheetURL: sheetURL, completion: completion)
        }
    }

    private func requestSheetURL() -> Result<String, Error> {
        guard let delegate else {
            return .failure(GoogleSheetsExporterError.missingInputHandler)
        }

        let requestResult = requestSheetURLInput(using: delegate)

        if requestResult.wasCanceled {
            return .failure(ExporterWorkflowError.canceled)
        }

        guard !requestResult.sheetURL.isEmpty else {
            return .failure(GoogleSheetsExporterError.missingSheetURL)
        }
        return .success(requestResult.sheetURL)
    }

    private func requestSheetURLInput(using delegate: LedgerExporterDelegate) -> (sheetURL: String, wasCanceled: Bool) {
        var sheetURL = ""
        var wasCanceled = false
        let group = DispatchGroup()
        group.enter()

        delegate.requestInput(name: "Google Sheets URL", type: .text(Self.recentSheetURLs)) { input in
            let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedInput.isEmpty else {
                return false
            }
            sheetURL = trimmedInput
            Self.saveRecentSheetURL(trimmedInput)
            group.leave()
            return true
        } onCancel: {
            wasCanceled = true
            group.leave()
        }

        group.wait()
        return (sheetURL, wasCanceled)
    }

    private func startAuthenticatedExport(
        sheetURL: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let authentication = authentication
        let ledger = ledger
        DispatchQueue.main.async {
            authentication.authenticate(authenticationPresentationContextProvider: GoogleAuthContext()) { result in
                switch result {
                case .success:
                    Uploader(sheetURL: sheetURL, ledger: ledger).start(authentication: authentication) { syncResult in
                        completion(syncResult.map { Self.format(result: $0) })
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }

}
