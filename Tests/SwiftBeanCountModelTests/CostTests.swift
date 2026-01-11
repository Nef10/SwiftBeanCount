//
//  CostTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2019-09-08.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountModel
import Testing

@Suite
struct CostTests {

    private let label1 = "1"
    private let label2 = "2"

    @Test
    func negativeAmount() {
        #expect(throws: CostError.negativeAmount("{-1 EUR}")) { try Cost(amount: Amount(number: -1, commoditySymbol: TestUtils.eur), date: nil, label: nil) }
    }

    @Test
    func equal() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(cost1 == cost2)
    }

    @Test
    func equalRespectsAmount() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount2, date: TestUtils.date20170608, label: label1)
        let cost3 = try Cost(amount: nil, date: TestUtils.date20170608, label: label1)
        #expect(cost1 != cost2)
        #expect(cost1 != cost3)
    }

    @Test
    func equalRespectsDate() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170609, label: label1)
        let cost3 = try Cost(amount: TestUtils.amount, date: nil, label: label1)
        #expect(cost1 != cost2)
        #expect(cost1 != cost3)
    }

    @Test
    func equalRespectsLabel() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label2)
        let cost3 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: nil)
        #expect(cost1 != cost2)
        #expect(cost1 != cost3)
    }

    @Test
    func equalWorksWithNil() throws {
        let cost1 = try Cost(amount: nil, date: nil, label: nil)
        let cost2 = try Cost(amount: nil, date: nil, label: nil)
        #expect(cost1 == cost2)
    }

    @Test
    func matches() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: nil, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(cost1.matches(cost: cost2))
    }

    @Test
    func matchesNil() throws {
        let cost1 = try Cost(amount: nil, date: nil, label: nil)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(cost1.matches(cost: cost2))
    }

    @Test
    func matchesLabel() throws {
        let cost1 = try Cost(amount: nil, date: nil, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(cost1.matches(cost: cost2))
    }

    @Test
    func matchesDate() throws {
        let cost1 = try Cost(amount: nil, date: TestUtils.date20170608, label: nil)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(cost1.matches(cost: cost2))
    }

    @Test
    func matchesAmount() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: nil, label: nil)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(cost1.matches(cost: cost2))
    }

    @Test
    func notMatchesLabel() throws {
        let cost1 = try Cost(amount: nil, date: nil, label: label2)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(!(cost1.matches(cost: cost2)))
    }

    @Test
    func notMatchesDate() throws {
        let cost1 = try Cost(amount: nil, date: TestUtils.date20170609, label: nil)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(!(cost1.matches(cost: cost2)))
    }

    @Test
    func notMatchesAmount() throws {
        let cost1 = try Cost(amount: TestUtils.amount2, date: nil, label: nil)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(!(cost1.matches(cost: cost2)))
    }

    @Test
    func matchesLabelWrong() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label2)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(!(cost1.matches(cost: cost2)))
    }

    @Test
    func matchesDateWrong() throws {
        let cost1 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170609, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(!(cost1.matches(cost: cost2)))
    }

    @Test
    func matchesAmountWrong() throws {
        let cost1 = try Cost(amount: TestUtils.amount2, date: TestUtils.date20170608, label: label1)
        let cost2 = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(!(cost1.matches(cost: cost2)))
    }

    @Test
    func description() throws {
        let cost = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: label1)
        #expect(String(describing: cost) == "{2017-06-08, \(String(describing: TestUtils.amount)), \"\(label1)\"}")
    }

    @Test
    func descriptionWithoutDate() throws {
        let cost = try Cost(amount: TestUtils.amount, date: nil, label: label1)
        #expect(String(describing: cost) == "{\(String(describing: TestUtils.amount)), \"\(label1)\"}")
    }

    @Test
    func descriptionWithoutAmount() throws {
        let cost = try Cost(amount: nil, date: TestUtils.date20170608, label: label1)
        #expect(String(describing: cost) == "{2017-06-08, \"\(label1)\"}")
    }

    @Test
    func descriptionWithoutLabel() throws {
        let cost = try Cost(amount: TestUtils.amount, date: TestUtils.date20170608, label: nil)
        #expect(String(describing: cost) == "{2017-06-08, \(String(describing: TestUtils.amount))}")
    }

    @Test
    func descriptionWithOnlyAmount() throws {
        let cost = try Cost(amount: TestUtils.amount, date: nil, label: nil)
        #expect(String(describing: cost) == "{\(String(describing: TestUtils.amount))}")
    }

    @Test
    func descriptionWithOnlyDate() throws {
        let cost = try Cost(amount: nil, date: TestUtils.date20170608, label: nil)
        #expect(String(describing: cost) == "{2017-06-08}")
    }

    @Test
    func descriptionWithOnlyLabel() throws {
        let cost = try Cost(amount: nil, date: nil, label: label1)
        #expect(String(describing: cost) == "{\"\(label1)\"}")
    }

    @Test
    func emptyDescription() throws {
        let cost = try Cost(amount: nil, date: nil, label: nil)
        #expect(String(describing: cost) == "{}")
    }

}
