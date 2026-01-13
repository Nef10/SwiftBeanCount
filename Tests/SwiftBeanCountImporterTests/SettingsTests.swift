//
//  SettingsTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2021-08-26.
//  Copyright © 2021 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountImporter
import Testing

extension TestsUsingStorage {

@Suite
struct SettingsTests {

    @Test
    func descriptionMappings() {
        Settings.storage = TestStorage()

        #expect(Settings.allDescriptionMappings.isEmpty)

        // set
        Settings.setDescriptionMapping(key: "originalDescription", description: "new one")
        #expect(Settings.allDescriptionMappings == ["originalDescription": "new one"])

        // update
        Settings.setDescriptionMapping(key: "originalDescription", description: "newer one")
        #expect(Settings.allDescriptionMappings == ["originalDescription": "newer one"])

        // two
        Settings.setDescriptionMapping(key: "originalDescription2", description: "new")
        #expect(Settings.allDescriptionMappings == ["originalDescription": "newer one", "originalDescription2": "new"])

        // delete
        Settings.setDescriptionMapping(key: "originalDescription2", description: nil)
        #expect(Settings.allDescriptionMappings == ["originalDescription": "newer one"])
    }

    @Test
    func payeeMappings() {
        Settings.storage = TestStorage()

        #expect(Settings.allPayeeMappings.isEmpty)

        // set
        Settings.setPayeeMapping(key: "originalDescription", payee: "new one")
        #expect(Settings.allPayeeMappings == ["originalDescription": "new one"])

        // update
        Settings.setPayeeMapping(key: "originalDescription", payee: "newer one")
        #expect(Settings.allPayeeMappings == ["originalDescription": "newer one"])

        // two
        Settings.setPayeeMapping(key: "originalDescription2", payee: "new")
        #expect(Settings.allPayeeMappings == ["originalDescription": "newer one", "originalDescription2": "new"])

        // delete
        Settings.setPayeeMapping(key: "originalDescription2", payee: nil)
        #expect(Settings.allPayeeMappings == ["originalDescription": "newer one"])
    }

    @Test
    func accountMappings() {
        Settings.storage = TestStorage()

        #expect(Settings.allAccountMappings.isEmpty)

        // set
        Settings.setAccountMapping(key: "originalDescription", account: "new one")
        #expect(Settings.allAccountMappings == ["originalDescription": "new one"])

        // update
        Settings.setAccountMapping(key: "originalDescription", account: "newer one")
        #expect(Settings.allAccountMappings == ["originalDescription": "newer one"])

        // two
        Settings.setAccountMapping(key: "originalDescription2", account: "new")
        #expect(Settings.allAccountMappings == ["originalDescription": "newer one", "originalDescription2": "new"])

        // delete
        Settings.setAccountMapping(key: "originalDescription2", account: nil)
        #expect(Settings.allAccountMappings == ["originalDescription": "newer one"])
    }

    @Test
    func dateTolerance() {
        Settings.storage = TestStorage()

        #expect(Settings.dateToleranceInDays == Settings.defaultDateTolerance)
        #expect(Settings.dateTolerance == Double(Settings.defaultDateTolerance * 60 * 60 * 24))

        Settings.dateToleranceInDays = 4
        #expect(Settings.dateToleranceInDays == 4)
        #expect(Settings.dateTolerance == Double(4 * 60 * 60 * 24))
    }

}

}
