//
//  InventoryTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2019-09-14.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

// swiftlint:disable file_length

import Foundation
@testable import SwiftBeanCountModel
import Testing

@Suite
struct InventoryTests {

    private static var transactionStore = [Transaction]() // required because the posting reference is unowned

    private let date = TestUtils.date20170608

    @Test(arguments: BookingMethod.allCases)
    func description(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 3.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        let cost2 = try Cost(amount: Amount(number: 5.0, commoditySymbol: TestUtils.cad, decimalDigits: 2), date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        do {
            let result1 = try inventory.book(posting: transactionPosting(posting1))
            let result2 = try inventory.book(posting: transactionPosting(posting2))
            #expect(result1 == nil)
            #expect(result2 == nil)
        } catch {
            Issue.record("Error thrown: \(error)")
        }

        #expect(String(describing: inventory) == """
            \(amount1) \(cost1)
            \(amount2) \(cost2)
            """)
    }

}

extension InventoryTests { // Test Adding

    @Test(arguments: BookingMethod.allCases)
    func adding(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)
        let amount = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting = Posting(accountName: TestUtils.cash, amount: amount, price: nil, cost: cost)

        #expect(try inventory.book(posting: transactionPosting(posting)) == nil)

        #expect(inventory.inventory.count == 1)
        #expect(inventory.inventory.first?.units == amount)
        #expect(inventory.inventory.first?.cost == cost)
    }

    @Test(arguments: BookingMethod.allCases)
    func addingTransactionDateUsed(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)
        let amount = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: nil, label: nil)
        let posting = Posting(accountName: TestUtils.cash, amount: amount, price: nil, cost: cost)

        #expect(try inventory.book(posting: transactionPosting(posting)) == nil)

        #expect(inventory.inventory.first?.cost.date == date)
    }

    @Test(arguments: BookingMethod.allCases)
    func addingMultiple(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 3.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        let cost2 = try Cost(amount: Amount(number: 5.0, commoditySymbol: TestUtils.cad, decimalDigits: 2), date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        #expect(result1 == nil)
        #expect(result2 == nil)

        #expect(inventory.inventory.count == 2)
        #expect(inventory.inventory.first?.units == amount1)
        #expect(inventory.inventory.first?.cost == cost1)
        #expect(inventory.inventory.last?.units == amount2)
        #expect(inventory.inventory.last?.cost == cost2)
    }

    @Test(arguments: BookingMethod.allCases)
    func addingSameCost(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost)

        let amount2 = Amount(number: 3.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost)

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        #expect(result1 == nil)
        #expect(result2 == nil)

        #expect(inventory.inventory.count == 1)
        #expect(inventory.inventory.first?.units.commoditySymbol == TestUtils.eur)
        #expect(inventory.inventory.first?.units.decimalDigits == 2)
        #expect(inventory.inventory.first?.units.number == amount1.number + amount2.number)
        #expect(inventory.inventory.first?.cost == cost)
    }

    @Test(arguments: BookingMethod.allCases)
    func addingSameCostDifferentCommodity(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost)

        let amount2 = Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 2)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost)

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        #expect(result1 == nil)
        #expect(result2 == nil)

        #expect(inventory.inventory.count == 2)
        #expect(inventory.inventory.first?.units == amount1)
        #expect(inventory.inventory.first?.cost == cost)
        #expect(inventory.inventory.last?.units == amount2)
        #expect(inventory.inventory.last?.cost == cost)
    }

    @Test(arguments: BookingMethod.allCases)
    func addingNegative(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)
        let amount = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting = Posting(accountName: TestUtils.cash, amount: amount, price: nil, cost: cost)

        #expect(try inventory.book(posting: transactionPosting(posting)) == nil)

        #expect(inventory.inventory.count == 1)
        #expect(inventory.inventory.first?.units == amount)
        #expect(inventory.inventory.first?.cost == cost)
    }

    @Test(arguments: BookingMethod.allCases)
    func addingMultipleNegative(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)

        let amount1 = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: -3.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        let cost2 = try Cost(amount: Amount(number: 5.0, commoditySymbol: TestUtils.cad, decimalDigits: 2), date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        #expect(result1 == nil)
        #expect(result2 == nil)

        #expect(inventory.inventory.count == 2)
        #expect(inventory.inventory.first?.units == amount1)
        #expect(inventory.inventory.first?.cost == cost1)
        #expect(inventory.inventory.last?.units == amount2)
        #expect(inventory.inventory.last?.cost == cost2)
    }

    @Test(arguments: BookingMethod.allCases)
    func addingSameCostNegative(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)

        let amount1 = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost)

        let amount2 = Amount(number: -3.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost)

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        #expect(result1 == nil)
        #expect(result2 == nil)

        #expect(inventory.inventory.count == 1)
        #expect(inventory.inventory.first?.units.commoditySymbol == TestUtils.eur)
        #expect(inventory.inventory.first?.units.decimalDigits == 2)
        #expect(inventory.inventory.first?.units.number == amount1.number + amount2.number)
        #expect(inventory.inventory.first?.cost == cost)
    }

}

extension InventoryTests { // Test Reduce

    @Test(arguments: BookingMethod.allCases)
    func reduce(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: -1.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        let cost2 = try Cost(amount: nil, date: nil, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        #expect(result1 == nil)
        #expect(result2 == Amount(number: -cost1.amount!.number,
                                  commoditySymbol: cost1.amount!.commoditySymbol,
                                  decimalDigits: cost1.amount!.decimalDigits).multiCurrencyAmount)

        #expect(inventory.inventory.count == 1)
        #expect(inventory.inventory.first?.units.number == amount1.number + amount2.number)
        #expect(inventory.inventory.first?.units.decimalDigits == 2)
        #expect(inventory.inventory.first?.cost == cost1)
    }

    @Test(arguments: BookingMethod.allCases)
    func reduceMoreThanExist(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: -3.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        let cost2 = try Cost(amount: nil, date: nil, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        #expect(try inventory.book(posting: transactionPosting(posting1)) == nil)

        #expect(throws: InventoryError.lotNotBigEnough("Lot not big enough: Trying to reduce 2.0 EUR {2017-06-08, 3.0 CAD} by -3.00 EUR {}")) {
            try inventory.book(posting: transactionPosting(posting2))
        }
    }

    @Test(arguments: BookingMethod.allCases)
    func reduceNoLot(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: -1.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        let cost2 = try Cost(amount: Amount(number: 4.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: nil, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        #expect(try inventory.book(posting: transactionPosting(posting1)) == nil)

        #expect(throws: InventoryError.noLotFound("No Lot matching -1.00 EUR {4.0 CAD} found, inventory: 2.0 EUR {2017-06-08, 3.0 CAD}")) {
            try inventory.book(posting: transactionPosting(posting2))
        }
    }

    @Test(arguments: BookingMethod.allCases)
    func reducePositive(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)

        let amount1 = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 1.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        let cost2 = try Cost(amount: nil, date: nil, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        #expect(result1 == nil)
        #expect(result2 == cost1.amount?.multiCurrencyAmount)

        #expect(inventory.inventory.count == 1)
        #expect(inventory.inventory.first?.units.number == amount1.number + amount2.number)
        #expect(inventory.inventory.first?.units.decimalDigits == 2)
        #expect(inventory.inventory.first?.cost == cost1)
    }

    @Test(arguments: BookingMethod.allCases)
    func reduceDifferentCurrencyPresent(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.567, commoditySymbol: TestUtils.cad, decimalDigits: 3), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 1.0, commoditySymbol: TestUtils.cad, decimalDigits: 2)
        let cost2 = try Cost(amount: nil, date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let amount3 = Amount(number: -1.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        let cost3 = try Cost(amount: nil, date: nil, label: nil)
        let posting3 = Posting(accountName: TestUtils.cash, amount: amount3, price: nil, cost: cost3)

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        let result3 = try inventory.book(posting: transactionPosting(posting3))
        #expect(result1 == nil)
        #expect(result2 == nil)
        #expect(result3 == Amount(number: -cost1.amount!.number,
                                  commoditySymbol: cost1.amount!.commoditySymbol,
                                  decimalDigits: cost1.amount!.decimalDigits).multiCurrencyAmount)

        #expect(inventory.inventory.count == 2)
        #expect(inventory.inventory.first?.units.number == amount1.number + amount3.number)
        #expect(inventory.inventory.first?.units.decimalDigits == 2)
        #expect(inventory.inventory.first?.cost == cost1)
        #expect(inventory.inventory.last?.units == amount2)
        #expect(inventory.inventory.last?.cost == cost2)
    }

    @Test(arguments: BookingMethod.allCases)
    func reduceDifferentLotPresent(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 5.5, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost2 = try Cost(amount: Amount(number: 2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let amount3 = Amount(number: -1.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        let posting3 = Posting(accountName: TestUtils.cash, amount: amount3, price: nil, cost: cost1)

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        let result3 = try inventory.book(posting: transactionPosting(posting3))
        #expect(result1 == nil)
        #expect(result2 == nil)
        #expect(result3 == Amount(number: -cost1.amount!.number,
                                  commoditySymbol: cost1.amount!.commoditySymbol,
                                  decimalDigits: cost1.amount!.decimalDigits).multiCurrencyAmount)

        #expect(inventory.inventory.count == 2)
        #expect(inventory.inventory.first?.units.number == amount1.number + amount3.number)
        #expect(inventory.inventory.first?.units.decimalDigits == 2)
        #expect(inventory.inventory.first?.cost == cost1)
        #expect(inventory.inventory.last?.units == amount2)
        #expect(inventory.inventory.last?.cost == cost2)
    }

    @Test
    func reduceAmbigiousStrict() throws {
        let inventory = Inventory(bookingMethod: .strict)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost2 = try Cost(amount: Amount(number: 2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let amount3 = Amount(number: -1.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        let posting3 = Posting(accountName: TestUtils.cash, amount: amount3, price: nil, cost: try Cost(amount: nil, date: nil, label: nil))

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        #expect(result1 == nil)
        #expect(result2 == nil)

        #expect(throws: InventoryError.ambiguousBooking("""
            Ambigious Booking: -1.00 EUR {}, matches: 2.0 EUR {2017-06-08, 3.0 CAD}
            2.0 EUR {2017-06-08, 2.0 CAD}, inventory: 2.0 EUR {2017-06-08, 3.0 CAD}
            2.0 EUR {2017-06-08, 2.0 CAD}
            """)) { try inventory.book(posting: transactionPosting(posting3)) }

        #expect(inventory.inventory.count == 2)
        #expect(inventory.inventory.first?.units == amount1)
        #expect(inventory.inventory.first?.cost == cost1)
        #expect(inventory.inventory.last?.units == amount2)
        #expect(inventory.inventory.last?.cost == cost2)
    }

    @Test(arguments: [BookingMethod.lifo, BookingMethod.fifo])
    func reduceAmbigiousNotEnoughUnits(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost2 = try Cost(amount: Amount(number: 2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let amount3 = Amount(number: -5.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost3 = try Cost(amount: nil, date: nil, label: nil)
        let posting3 = Posting(accountName: TestUtils.cash, amount: amount3, price: nil, cost: cost3)

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        #expect(result1 == nil)
        #expect(result2 == nil)

        #expect(throws: InventoryError.lotNotBigEnough("Not enough units: Trying to reduce by \(amount3) \(cost3)")) {
            try inventory.book(posting: transactionPosting(posting3))
        }
    }

    @Test
    func reduceAmbigiousLIFO() throws {
        let inventory = Inventory(bookingMethod: .lifo)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost2 = try Cost(amount: Amount(number: 2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let amount3 = Amount(number: -1.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let posting3 = Posting(accountName: TestUtils.cash, amount: amount3, price: nil, cost: try Cost(amount: nil, date: nil, label: nil))

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        #expect(result1 == nil)
        #expect(result2 == nil)

        #expect(try inventory.book(posting: transactionPosting(posting3)) == Amount(number: -2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1).multiCurrencyAmount)

        #expect(inventory.inventory.count == 2)
        #expect(inventory.inventory.first?.units == amount1)
        #expect(inventory.inventory.first?.cost == cost1)
        #expect(inventory.inventory.last?.units == Amount(number: 1.0, commoditySymbol: TestUtils.eur, decimalDigits: 1))
        #expect(inventory.inventory.last?.cost == cost2)
    }

    @Test
    func reduceAmbigiousLIFOExactLot() throws {
        let inventory = Inventory(bookingMethod: .lifo)

        let amount1 = Amount(number: 3.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost2 = try Cost(amount: Amount(number: 2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let amount3 = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let posting3 = Posting(accountName: TestUtils.cash, amount: amount3, price: nil, cost: try Cost(amount: nil, date: nil, label: nil))

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        #expect(result1 == nil)
        #expect(result2 == nil)

        let result = try inventory.book(posting: transactionPosting(posting3))
        #expect(result == Amount(number: -4.0, commoditySymbol: TestUtils.cad, decimalDigits: 1).multiCurrencyAmount)

        #expect(inventory.inventory.count == 1)
        #expect(inventory.inventory.last?.units == amount1)
        #expect(inventory.inventory.last?.cost == cost1)
    }

    @Test
    func reduceAmbigiousLIFOMultipleLots() throws {
        let inventory = Inventory(bookingMethod: .lifo)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost2 = try Cost(amount: Amount(number: 2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let amount3 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost3 = try Cost(amount: Amount(number: 4.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting3 = Posting(accountName: TestUtils.cash, amount: amount3, price: nil, cost: cost3)

        let amount4 = Amount(number: -5.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let posting4 = Posting(accountName: TestUtils.cash, amount: amount4, price: nil, cost: try Cost(amount: nil, date: nil, label: nil))

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        let result3 = try inventory.book(posting: transactionPosting(posting3))
        #expect(result1 == nil)
        #expect(result2 == nil)
        #expect(result3 == nil)

        let result = try inventory.book(posting: transactionPosting(posting4))
        #expect(result == Amount(number: -15.0, commoditySymbol: TestUtils.cad, decimalDigits: 1).multiCurrencyAmount)

        #expect(inventory.inventory.count == 1)
        #expect(inventory.inventory.last?.units == Amount(number: 1.0, commoditySymbol: TestUtils.eur, decimalDigits: 1))
        #expect(inventory.inventory.last?.cost == cost1)
    }

    @Test
    func reduceAmbigiousFIFO() throws {
        let inventory = Inventory(bookingMethod: .fifo)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost2 = try Cost(amount: Amount(number: 2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let amount3 = Amount(number: -1.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let posting3 = Posting(accountName: TestUtils.cash, amount: amount3, price: nil, cost: try Cost(amount: nil, date: nil, label: nil))

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        #expect(result1 == nil)
        #expect(result2 == nil)

        #expect(try inventory.book(posting: transactionPosting(posting3)) == Amount(number: -3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1).multiCurrencyAmount)

        #expect(inventory.inventory.count == 2)
        #expect(inventory.inventory.first?.units == Amount(number: 1.0, commoditySymbol: TestUtils.eur, decimalDigits: 1))
        #expect(inventory.inventory.first?.cost == cost1)
        #expect(inventory.inventory.last?.units == amount2)
        #expect(inventory.inventory.last?.cost == cost2)
    }

    @Test
    func reduceAmbigiousFIFOExactLot() throws {
        let inventory = Inventory(bookingMethod: .fifo)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 3.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost2 = try Cost(amount: Amount(number: 2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let amount3 = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let posting3 = Posting(accountName: TestUtils.cash, amount: amount3, price: nil, cost: try Cost(amount: nil, date: nil, label: nil))

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        #expect(result1 == nil)
        #expect(result2 == nil)

        #expect(try inventory.book(posting: transactionPosting(posting3)) == Amount(number: -6.0, commoditySymbol: TestUtils.cad, decimalDigits: 1).multiCurrencyAmount)

        #expect(inventory.inventory.count == 1)
        #expect(inventory.inventory.last?.units == amount2)
        #expect(inventory.inventory.last?.cost == cost2)
    }

    @Test
    func reduceAmbigiousFIFOMultipleLots() throws {
        let inventory = Inventory(bookingMethod: .fifo)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost2 = try Cost(amount: Amount(number: 2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let amount3 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost3 = try Cost(amount: Amount(number: 4.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting3 = Posting(accountName: TestUtils.cash, amount: amount3, price: nil, cost: cost3)

        let amount4 = Amount(number: -5.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let posting4 = Posting(accountName: TestUtils.cash, amount: amount4, price: nil, cost: try Cost(amount: nil, date: nil, label: nil))

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        let result3 = try inventory.book(posting: transactionPosting(posting3))
        #expect(result1 == nil)
        #expect(result2 == nil)
        #expect(result3 == nil)

        let result = try inventory.book(posting: transactionPosting(posting4))
        #expect(result == Amount(number: -14.0, commoditySymbol: TestUtils.cad, decimalDigits: 1).multiCurrencyAmount)

        #expect(inventory.inventory.count == 1)
        #expect(inventory.inventory.last?.units == Amount(number: 1.0, commoditySymbol: TestUtils.eur, decimalDigits: 1))
        #expect(inventory.inventory.last?.cost == cost3)
    }

    @Test(arguments: BookingMethod.allCases)
    func totalReduce(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: nil, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        let cost2 = try Cost(amount: nil, date: nil, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        #expect(result1 == nil)
        #expect(result2 == Amount(number: amount2.number * cost1.amount!.number,
                                  commoditySymbol: cost1.amount!.commoditySymbol,
                                  decimalDigits: cost1.amount!.decimalDigits).multiCurrencyAmount)

        #expect(inventory.inventory.isEmpty)
    }

    @Test(arguments: BookingMethod.allCases)
    func totalReduceMultipleLots(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)

        let amount1 = Amount(number: 2.5, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: nil, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost2 = try Cost(amount: Amount(number: 3.05, commoditySymbol: TestUtils.cad, decimalDigits: 2), date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let amount3 = Amount(number: -4.5, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        let cost3 = try Cost(amount: nil, date: nil, label: nil)
        let posting3 = Posting(accountName: TestUtils.cash, amount: amount3, price: nil, cost: cost3)

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        let result3 = try inventory.book(posting: transactionPosting(posting3))
        #expect(result1 == nil)
        #expect(result2 == nil)
        #expect(result3 == MultiCurrencyAmount(amounts: [TestUtils.cad: -11.1], decimalDigits: [TestUtils.cad: 2]))

        #expect(inventory.inventory.isEmpty)
    }

    @Test(arguments: BookingMethod.allCases)
    func totalReduceDifferentCurrencyPresent(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: nil, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1)
        let cost2 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let amount3 = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        let cost3 = try Cost(amount: nil, date: nil, label: nil)
        let posting3 = Posting(accountName: TestUtils.cash, amount: amount3, price: nil, cost: cost3)

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        let result3 = try inventory.book(posting: transactionPosting(posting3))
        #expect(result1 == nil)
        #expect(result2 == nil)
        #expect(result3 == Amount(number: amount3.number * cost1.amount!.number,
                                  commoditySymbol: cost1.amount!.commoditySymbol,
                                  decimalDigits: cost1.amount!.decimalDigits).multiCurrencyAmount)

        #expect(inventory.inventory.count == 1)
        #expect(inventory.inventory.first?.units == amount2)
        #expect(inventory.inventory.first?.cost == cost2)
    }

    @Test(arguments: BookingMethod.allCases)
    func totalReduceDifferentLotPresent(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: nil, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost2 = try Cost(amount: Amount(number: 2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let amount3 = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        let posting3 = Posting(accountName: TestUtils.cash, amount: amount3, price: nil, cost: cost1)

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        let result3 = try inventory.book(posting: transactionPosting(posting3))
        #expect(result1 == nil)
        #expect(result2 == nil)
        #expect(result3 == Amount(number: amount3.number * cost1.amount!.number,
                                  commoditySymbol: cost1.amount!.commoditySymbol,
                                  decimalDigits: cost1.amount!.decimalDigits).multiCurrencyAmount)

        #expect(inventory.inventory.count == 1)
        #expect(inventory.inventory.first?.units == amount2)
        #expect(inventory.inventory.first?.cost == cost2)
    }

    @Test(arguments: BookingMethod.allCases)
    func amountDifferentCurrency(bookingMethod: BookingMethod) throws {
        let inventory = Inventory(bookingMethod: bookingMethod)

        let amount1 = Amount(number: 2.5, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: nil, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost2 = try Cost(amount: Amount(number: 3.05, commoditySymbol: TestUtils.eur, decimalDigits: 2), date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let amount3 = Amount(number: -4.5, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        let cost3 = try Cost(amount: nil, date: nil, label: nil)
        let posting3 = Posting(accountName: TestUtils.cash, amount: amount3, price: nil, cost: cost3)

        let result1 = try inventory.book(posting: transactionPosting(posting1))
        let result2 = try inventory.book(posting: transactionPosting(posting2))
        let result3 = try inventory.book(posting: transactionPosting(posting3))
        #expect(result1 == nil)
        #expect(result2 == nil)
        #expect(result3 == MultiCurrencyAmount(amounts: [TestUtils.eur: -6.10, TestUtils.cad: -5.0], decimalDigits: [TestUtils.eur: 2, TestUtils.cad: 1]))

        #expect(inventory.inventory.isEmpty)
    }

    func transactionPosting(_ posting: Posting) -> TransactionPosting {
        let transaction = Transaction(metaData: TransactionMetaData(date: date,
                                                                    payee: "Payee",
                                                                    narration: "Narration",
                                                                    flag: Flag.complete,
                                                                    tags: []),
                                      postings: [posting])
        Self.transactionStore.append(transaction)
        return transaction.postings[0]

    }

}

extension InventoryTests { // Inventory.Lot Tests

    @Test
    func lotDescription() throws {
        let amount = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: nil, label: nil)
        let lot = Inventory.Lot(units: amount, cost: cost)
        #expect(String(describing: lot) == "\(amount) \(cost)")
    }

    @Test
    func lotEqual() throws {
        let amount = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: nil, label: nil)
        let lot1 = Inventory.Lot(units: amount, cost: cost)
        let lot2 = Inventory.Lot(units: amount, cost: cost)
        #expect(lot1 == lot2)
    }

    @Test
    func lotEqualRespectsAmount() throws {
        let amount1 = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let amount2 = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        let cost = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: nil, label: nil)
        let lot1 = Inventory.Lot(units: amount1, cost: cost)
        let lot2 = Inventory.Lot(units: amount2, cost: cost)
        #expect(lot1 != lot2)
    }

    @Test
    func lotEqualRespectsCost() throws {
        let amount = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 2), date: nil, label: nil)
        let cost2 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: nil, label: nil)
        let lot1 = Inventory.Lot(units: amount, cost: cost1)
        let lot2 = Inventory.Lot(units: amount, cost: cost2)
        #expect(lot1 != lot2)
    }

}

extension InventoryTests { // BookingMethod tests

    @Test
    func bookingMethodDescription() {
        #expect(String(describing: BookingMethod.fifo) == "FIFO")
        #expect(String(describing: BookingMethod.lifo) == "LIFO")
        #expect(String(describing: BookingMethod.strict) == "STRICT")
    }

}
