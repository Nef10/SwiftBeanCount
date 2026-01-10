//
//  AccountNameTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2020-05-22.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountModel
import Testing

@Suite
struct AccountNameTests {

    private static let invalidNames = [
        "Assets", "Liabilities", "Income", "Expenses", "Equity", "Assets:", "Assets:Test:", "Assets:Test:", "Assets:Test::Test", "💰", "",
        "Assets:Cash Account", "Assets: Cash", "Expenses:Grocery Store", "Liabilities:Credit Card"
    ]
    private static let validNames = ["Assets:Cash", "Assets:Cash:Test:Test:A", "Assets:Cash:Ca💰h:Test:💰", "Liabilities:Test", "Income:Test", "Expenses:Test", "Equity:Test"]

    @Test(arguments: validNames)
    func initValidName(name: String) throws {
        #expect(throws: Never.self) { try AccountName(name) }
    }

    @Test(arguments: invalidNames)
    func initInvalidName(name: String) throws {
        #expect(throws: AccountNameError.invaildName(name)) { try AccountName(name) }
    }

    @Test(arguments: validNames)
    func isNameValidTrue(name: String) {
        #expect(AccountName.isNameValid(name))
    }

    @Test(arguments: invalidNames)
    func isNameValidFalse(name: String) {
        #expect(!(AccountName.isNameValid(name)))
    }

    @Test
    func nameItem() throws {
        #expect(TestUtils.cash.nameItem == "Cash")
        #expect(try AccountName("Assets:A:B:C:D:E:Cash").nameItem == "Cash")
        #expect(try AccountName("Assets:💰").nameItem == "💰")
    }

    @Test
    func accountType() throws {
        #expect(try AccountName("Assets:Test").accountType == AccountType.asset)
        #expect(try AccountName("Liabilities:Test").accountType == AccountType.liability)
        #expect(try AccountName("Income:Test").accountType == AccountType.income)
        #expect(try AccountName("Expenses:Test").accountType == AccountType.expense)
        #expect(try AccountName("Equity:Test").accountType == AccountType.equity)
    }

    @Test
    func accountNameEqual() throws {
        let name1 = try AccountName("Assets:Test")
        let name2 = try AccountName("Assets:Test")
        let name3 = try AccountName("Assets:Test:Test")
        #expect(name1 == name2)
        #expect(name1 != name3)
    }

}
