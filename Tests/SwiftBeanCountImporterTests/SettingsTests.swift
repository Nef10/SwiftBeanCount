//
//  SettingsTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2021-08-26.
//  Copyright © 2021 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountImporter
import XCTest

final class SettingsTests: XCTestCase {

    func testDescriptionMappings() {
        UserDefaults.standard.removeObject(forKey: Settings.descriptionUserDefaultsKey)

        XCTAssertEqual(Settings.allDescriptionMappings, [:])

        // set
        Settings.setDescriptionMapping(key: "originalDescription", description: "new one")
        XCTAssertEqual(Settings.allDescriptionMappings, ["originalDescription": "new one"])

        // update
        Settings.setDescriptionMapping(key: "originalDescription", description: "newer one")
        XCTAssertEqual(Settings.allDescriptionMappings, ["originalDescription": "newer one"])

        // two
        Settings.setDescriptionMapping(key: "originalDescription2", description: "new")
        XCTAssertEqual(Settings.allDescriptionMappings, ["originalDescription": "newer one", "originalDescription2": "new"])

        // delete
        Settings.setDescriptionMapping(key: "originalDescription2", description: nil)
        XCTAssertEqual(Settings.allDescriptionMappings, ["originalDescription": "newer one"])

        UserDefaults.standard.removeObject(forKey: Settings.descriptionUserDefaultsKey)
    }

    func testPayeeMappings() {
        UserDefaults.standard.removeObject(forKey: Settings.payeesUserDefaultKey)

        XCTAssertEqual(Settings.allPayeeMappings, [:])

        // set
        Settings.setPayeeMapping(key: "originalDescription", payee: "new one")
        XCTAssertEqual(Settings.allPayeeMappings, ["originalDescription": "new one"])

        // update
        Settings.setPayeeMapping(key: "originalDescription", payee: "newer one")
        XCTAssertEqual(Settings.allPayeeMappings, ["originalDescription": "newer one"])

        // two
        Settings.setPayeeMapping(key: "originalDescription2", payee: "new")
        XCTAssertEqual(Settings.allPayeeMappings, ["originalDescription": "newer one", "originalDescription2": "new"])

        // delete
        Settings.setPayeeMapping(key: "originalDescription2", payee: nil)
        XCTAssertEqual(Settings.allPayeeMappings, ["originalDescription": "newer one"])

        UserDefaults.standard.removeObject(forKey: Settings.payeesUserDefaultKey)
    }

    func testAccountMappings() {
        UserDefaults.standard.removeObject(forKey: Settings.accountsUserDefaultsKey)

        XCTAssertEqual(Settings.allAccountMappings, [:])

        // set
        Settings.setAccountMapping(key: "originalDescription", account: "new one")
        XCTAssertEqual(Settings.allAccountMappings, ["originalDescription": "new one"])

        // update
        Settings.setAccountMapping(key: "originalDescription", account: "newer one")
        XCTAssertEqual(Settings.allAccountMappings, ["originalDescription": "newer one"])

        // two
        Settings.setAccountMapping(key: "originalDescription2", account: "new")
        XCTAssertEqual(Settings.allAccountMappings, ["originalDescription": "newer one", "originalDescription2": "new"])

        // delete
        Settings.setAccountMapping(key: "originalDescription2", account: nil)
        XCTAssertEqual(Settings.allAccountMappings, ["originalDescription": "newer one"])

        UserDefaults.standard.removeObject(forKey: Settings.accountsUserDefaultsKey)
    }

    func testDateTolerance() {
        UserDefaults.standard.removeObject(forKey: Settings.dateToleranceUserDefaultsKey)

        XCTAssertEqual(Settings.dateToleranceInDays, Settings.defaultDateTolerance)
        XCTAssertEqual(Settings.dateTolerance, Double(Settings.defaultDateTolerance * 60 * 60 * 24))

        Settings.dateToleranceInDays = 4
        XCTAssertEqual(Settings.dateToleranceInDays, 4)
        XCTAssertEqual(Settings.dateTolerance, Double(4 * 60 * 60 * 24))

        UserDefaults.standard.removeObject(forKey: Settings.dateToleranceUserDefaultsKey)
    }

}
