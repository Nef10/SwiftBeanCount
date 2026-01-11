//
//  CommodityTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2017-06-11.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountModel
import Testing

@Suite
struct CommodityTests {

    @Test
    func description() {
        let commodity = Commodity(symbol: TestUtils.cad)
        #expect(String(describing: commodity).isEmpty)
    }

    @Test
    func descriptionSpecialCharactersOpening() {
        let symbol = "💵"
        let string = "2017-06-08 commodity \(symbol)"
        let commodity = Commodity(symbol: symbol, opening: TestUtils.date20170608)
        #expect(String(describing: commodity) == string)
    }

    @Test
    func descriptionMetaData() {
        let symbol = "CAD"
        let string = "2017-06-08 commodity \(symbol)\n  A: \"B\""
        let commodity = Commodity(symbol: symbol, opening: TestUtils.date20170608, metaData: ["A": "B"])
        #expect(String(describing: commodity) == string)
    }

    @Test
    func validate() {
        let commodity = Commodity(symbol: "EUR", opening: TestUtils.date20170608)
        let ledgerWithPlugin = Ledger()
        ledgerWithPlugin.plugins.append("beancount.plugins.check_commodity")
        guard case .valid = commodity.validate(in: ledgerWithPlugin) else {
            Issue.record("\(commodity) is not valid")
            return
        }
    }

    @Test
    func validateWithoutDate() {
        let commodity = Commodity(symbol: "EUR")

        // Test without plugin - should be valid
        let ledgerWithoutPlugin = Ledger()
        guard case .valid = commodity.validate(in: ledgerWithoutPlugin) else {
            Issue.record("\(commodity) should be valid when check_commodity plugin is not enabled")
            return
        }

        // Test with plugin - should be invalid
        let ledgerWithPlugin = Ledger()
        ledgerWithPlugin.plugins.append("beancount.plugins.check_commodity")
        if case .invalid(let error) = commodity.validate(in: ledgerWithPlugin) {
            #expect(error == "Commodity EUR does not have an opening date")
        } else {
            Issue.record("\(commodity) should be invalid when check_commodity plugin is enabled")
        }
    }

    @Test
    func equal() {
        var eur = Commodity(symbol: "EUR")
        var eur2 = Commodity(symbol: "EUR")
        let cad = Commodity(symbol: "CAD")
        #expect(eur == eur2)
        #expect(eur != cad)

        // meta data
        eur2 = Commodity(symbol: "EUR", metaData: ["A": "B"])
        #expect(eur != eur2)
        eur = Commodity(symbol: "EUR", metaData: ["A": "B"])
        #expect(eur == eur2)
    }

    @Test
    func greater() {
        let eur = TestUtils.eur
        let cad = TestUtils.cad

        #expect(eur > cad)
        #expect(!(eur < cad))
        #expect(!(eur > eur)) // swiftlint:disable:this identical_operands
        #expect(!(cad < cad)) // swiftlint:disable:this identical_operands
    }

    @Test
    func validateUsageDate() {
        // Test commodity with opening date - usage on same date should be valid
        let commodity = Commodity(symbol: "EUR", opening: TestUtils.date20170608)
        let ledgerWithPlugin = Ledger()
        ledgerWithPlugin.plugins.append("beancount.plugins.check_commodity")

        guard case .valid = commodity.validateUsageDate(TestUtils.date20170608, in: ledgerWithPlugin) else {
            Issue.record("Using commodity on opening date should be valid")
            return
        }

        // Test usage after opening date should be valid
        guard case .valid = commodity.validateUsageDate(TestUtils.date20170609, in: ledgerWithPlugin) else {
            Issue.record("Using commodity after opening date should be valid")
            return
        }
    }

    @Test
    func validateUsageDateBeforeOpening() {
        // Test commodity with opening date - usage before opening should be invalid
        let commodity = Commodity(symbol: "EUR", opening: TestUtils.date20170609)
        let ledgerWithPlugin = Ledger()
        ledgerWithPlugin.plugins.append("beancount.plugins.check_commodity")

        if case .invalid(let error) = commodity.validateUsageDate(TestUtils.date20170608, in: ledgerWithPlugin) {
            #expect(error.contains("EUR used on 2017-06-08 before its opening date of 2017-06-09"))
        } else {
            Issue.record("Using commodity before opening date should be invalid")
        }
    }

    @Test
    func validateUsageDateWithoutPlugin() {
        // Test without plugin - should always be valid regardless of dates
        let commodity = Commodity(symbol: "EUR", opening: TestUtils.date20170609)
        let ledgerWithoutPlugin = Ledger()

        guard case .valid = commodity.validateUsageDate(TestUtils.date20170608, in: ledgerWithoutPlugin) else {
            Issue.record("Usage date validation should be skipped when plugin is not enabled")
            return
        }
    }

    @Test
    func validateUsageDateWithoutOpeningDate() {
        // Test commodity without opening date
        let commodity = Commodity(symbol: "EUR")
        let ledgerWithPlugin = Ledger()
        ledgerWithPlugin.plugins.append("beancount.plugins.check_commodity")

        guard case .valid = commodity.validateUsageDate(TestUtils.date20170608, in: ledgerWithPlugin) else {
            Issue.record("Using commodity without opening date should be ignored in the validateUsageDate, as it is tested in the valdiate function")
            return
        }

    }

}
