//
//  DownloadImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2021-09-14.
//  Copyright © 2021 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import Testing

@Suite
struct DownloadImporterTests {

   @Test
   func testImporters() {
        #if canImport(UIKit) || canImport(AppKit)
            if #available(iOS 14.5, macOS 11.3, *) {
                #if os(macOS)
                    #expect(DownloadImporterFactory.importers.count == 5)
                #else
                   #expect(DownloadImporterFactory.importers.count == 4)
                #endif
            } else {
                #if os(macOS)
                    #expect(DownloadImporterFactory.importers.count == 4)
                #else
                    #expect(DownloadImporterFactory.importers.count == 3)
                #endif
            }
        #else
            #expect(DownloadImporterFactory.importers.count == 2)
        #endif
    }

   @Test
   func testNew() {
        #expect(DownloadImporterFactory.new(ledger: Ledger(), name: "This is not a valid name") == nil)

        let importers = DownloadImporterFactory.importers
        for importer in importers {
            #expect(type(of: DownloadImporterFactory.new(ledger: nil, name: importer.importerName)!) == importer)
        }
    }

   @Test
   func testNoEqualImporterTypes() {
        var types = [String]()
        let importers = DownloadImporterFactory.importers as! [BaseImporter.Type] // swiftlint:disable:this force_cast
        for importer in importers {
            guard !types.contains(importer.importerType) else {
                Issue.record("Importers cannot use the same type")
                return
            }
            types.append(importer.importerType)
        }
    }

   @Test
   func testNoEqualName() {
        var names = [String]()
        let importers = DownloadImporterFactory.importers
        for importer in importers {
            guard !names.contains(importer.importerName) else {
                Issue.record("Importers cannot use the same name")
                return
            }
            names.append(importer.importerName)
        }
    }

}
