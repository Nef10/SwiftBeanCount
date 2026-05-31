//
//  GoogleSheetDownloadImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2026-05-31.
//

#if os(macOS)

import Foundation
@testable import SwiftBeanCountImporter
import Testing

private final class GoogleSheetURLInputDelegate: BaseTestImporterDelegate {
    let expectedSuggestions: [String]
    let providedURL: String
    var verified = false

    init(expectedSuggestions: [String], providedURL: String) {
        self.expectedSuggestions = expectedSuggestions
        self.providedURL = providedURL
    }

    override func requestInput(name: String, type: ImporterInputRequestType, completion: (String) -> Bool) {
        #expect(name == "URL")
        switch type {
        case .text(let suggestions):
            #expect(suggestions == expectedSuggestions)
        default:
            Issue.record("Expected text input request")
        }
        verified = true
        #expect(completion(providedURL))
    }
}

extension TestsUsingStorage {

@Suite
struct GoogleSheetDownloadImporterTests {

    @Test
    func requestSheetURLUsesRecentSuggestionsAndCachesInput() {
        Settings.storage = TestStorage()
        Settings.addRecentGoogleSheetURL("https://example.com/1")
        Settings.addRecentGoogleSheetURL("https://example.com/2")
        Settings.addRecentGoogleSheetURL("https://example.com/3")

        let importer = GoogleSheetDownloadImporter(ledger: nil)
        let delegate = GoogleSheetURLInputDelegate(expectedSuggestions: [
            "https://example.com/3",
            "https://example.com/2",
            "https://example.com/1",
        ], providedURL: "https://example.com/4")
        importer.delegate = delegate

        #expect(importer.requestSheetURL() == "https://example.com/4")
        #expect(delegate.verified)
        #expect(Settings.recentGoogleSheetURLs == [
            "https://example.com/4",
            "https://example.com/3",
            "https://example.com/2",
        ])
    }

}

}

#endif
