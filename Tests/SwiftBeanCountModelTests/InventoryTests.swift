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

    private let bookingMethods = [BookingMethod.strict, BookingMethod.lifo, BookingMethod.fifo]

    private let date = TestUtils.date20170608
    private var transactionStore = [Transaction]() // required because the posting reference is unowned

   @Test
   func testInit() {
        for bookingMethod in bookingMethods {
            #expect(Inventory(bookingMethod: bookingMethod) != nil)
        }
    }

   @Test
   func testDescription() throws {
        for bookingMethod in bookingMethods {
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
                Issue.record("Error thrown")
            }

            #expect(String(describing: inventory) == """
                \(amount1) \(cost1)
                \(amount2) \(cost2)
                """)
        }
    }

}

extension InventoryTests { // Test Adding

   @Test
   func testAdding() throws {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)
            let amount = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
            let cost = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
            let posting = Posting(accountName: TestUtils.cash, amount: amount, price: nil, cost: cost)

            do {
                let result = try inventory.book(posting: transactionPosting(posting))
                #expect(result == nil)
            } catch {
                Issue.record("Error thrown")
            }

            #expect(inventory.inventory.count == 1)
            #expect(inventory.inventory.first?.units == amount)
            #expect(inventory.inventory.first?.cost == cost)
        }
    }

   @Test
   func testAddingTransactionDateUsed() throws {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)
            let amount = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
            let cost = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: nil, label: nil)
            let posting = Posting(accountName: TestUtils.cash, amount: amount, price: nil, cost: cost)

            do {
                let result = try inventory.book(posting: transactionPosting(posting))
                #expect(result == nil)
            } catch {
                Issue.record("Error thrown")
            }

            #expect(inventory.inventory.first?.cost.date == date)
        }
    }

   @Test
   func testAddingMultiple() throws {
        for bookingMethod in bookingMethods {
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
                Issue.record("Error thrown")
            }

            #expect(inventory.inventory.count == 2)
            #expect(inventory.inventory.first?.units == amount1)
            #expect(inventory.inventory.first?.cost == cost1)
            #expect(inventory.inventory.last?.units == amount2)
            #expect(inventory.inventory.last?.cost == cost2)
        }
    }

   @Test
   func testAddingSameCost() throws {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
            let cost = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost)

            let amount2 = Amount(number: 3.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
            let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost)

            do {
                let result1 = try inventory.book(posting: transactionPosting(posting1))
                let result2 = try inventory.book(posting: transactionPosting(posting2))
                #expect(result1 == nil)
                #expect(result2 == nil)
            } catch {
                Issue.record("Error thrown")
            }

            #expect(inventory.inventory.count == 1)
            #expect(inventory.inventory.first?.units.commoditySymbol == TestUtils.eur)
            #expect(inventory.inventory.first?.units.decimalDigits == 2)
            #expect(inventory.inventory.first?.units.number == amount1.number + amount2.number)
            #expect(inventory.inventory.first?.cost == cost)
        }
    }

   @Test
   func testAddingSameCostDifferentCommodity() throws {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
            let cost = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost)

            let amount2 = Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 2)
            let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost)

            do {
                let result1 = try inventory.book(posting: transactionPosting(posting1))
                let result2 = try inventory.book(posting: transactionPosting(posting2))
                #expect(result1 == nil)
                #expect(result2 == nil)
            } catch {
                Issue.record("Error thrown")
            }

            #expect(inventory.inventory.count == 2)
            #expect(inventory.inventory.first?.units == amount1)
            #expect(inventory.inventory.first?.cost == cost)
            #expect(inventory.inventory.last?.units == amount2)
            #expect(inventory.inventory.last?.cost == cost)
        }
    }

   @Test
   func testAddingNegative() throws {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)
            let amount = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
            let cost = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
            let posting = Posting(accountName: TestUtils.cash, amount: amount, price: nil, cost: cost)

            do {
                let result = try inventory.book(posting: transactionPosting(posting))
                #expect(result == nil)
            } catch {
                Issue.record("Error thrown")
            }

            #expect(inventory.inventory.count == 1)
            #expect(inventory.inventory.first?.units == amount)
            #expect(inventory.inventory.first?.cost == cost)
        }
    }

   @Test
   func testAddingMultipleNegative() throws {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
            let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

            let amount2 = Amount(number: -3.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
            let cost2 = try Cost(amount: Amount(number: 5.0, commoditySymbol: TestUtils.cad, decimalDigits: 2), date: date, label: nil)
            let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

            do {
                let result1 = try inventory.book(posting: transactionPosting(posting1))
                let result2 = try inventory.book(posting: transactionPosting(posting2))
                #expect(result1 == nil)
                #expect(result2 == nil)
            } catch {
                Issue.record("Error thrown")
            }

            #expect(inventory.inventory.count == 2)
            #expect(inventory.inventory.first?.units == amount1)
            #expect(inventory.inventory.first?.cost == cost1)
            #expect(inventory.inventory.last?.units == amount2)
            #expect(inventory.inventory.last?.cost == cost2)
        }
    }

   @Test
   func testAddingSameCostNegative() throws {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
            let cost = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost)

            let amount2 = Amount(number: -3.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
            let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost)

            do {
                let result1 = try inventory.book(posting: transactionPosting(posting1))
                let result2 = try inventory.book(posting: transactionPosting(posting2))
                #expect(result1 == nil)
                #expect(result2 == nil)
            } catch {
                Issue.record("Error thrown")
            }

            #expect(inventory.inventory.count == 1)
            #expect(inventory.inventory.first?.units.commoditySymbol == TestUtils.eur)
            #expect(inventory.inventory.first?.units.decimalDigits == 2)
            #expect(inventory.inventory.first?.units.number == amount1.number + amount2.number)
            #expect(inventory.inventory.first?.cost == cost)
        }
    }

}

extension InventoryTests { // Test Reduce

   @Test
   func testReduce() throws {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
            let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

            let amount2 = Amount(number: -1.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
            let cost2 = try Cost(amount: nil, date: nil, label: nil)
            let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

            do {
                let result1 = try inventory.book(posting: transactionPosting(posting1))
                let result2 = try inventory.book(posting: transactionPosting(posting2))
                #expect(result1 == nil)
                #expect(result2 == Amount(number: -cost1.amount!.number,
                                          commoditySymbol: cost1.amount!.commoditySymbol,
                                          decimalDigits: cost1.amount!.decimalDigits).multiCurrencyAmount)
            } catch {
                Issue.record("Error thrown")
            }

            #expect(inventory.inventory.count == 1)
            #expect(inventory.inventory.first?.units.number == amount1.number + amount2.number)
            #expect(inventory.inventory.first?.units.decimalDigits == 2)
            #expect(inventory.inventory.first?.cost == cost1)
        }
    }

   @Test
   func testReduceMoreThanExist() throws {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
            let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

            let amount2 = Amount(number: -3.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
            let cost2 = try Cost(amount: nil, date: nil, label: nil)
            let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

            var errorMessage = ""
            do {
                let result1 = try inventory.book(posting: transactionPosting(posting1))
                #expect(result1 == nil)
                _ = try inventory.book(posting: transactionPosting(posting2))
            } catch {
                errorMessage = error.localizedDescription
            }

            #expect(errorMessage == "Lot not big enough: Trying to reduce 2.0 EUR {2017-06-08, 3.0 CAD} by -3.00 EUR {}")
        }
    }

   @Test
   func testReduceNoLot() throws {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
            let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

            let amount2 = Amount(number: -1.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
            let cost2 = try Cost(amount: Amount(number: 4.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: nil, label: nil)
            let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

            var errorMessage = ""
            do {
                let result1 = try inventory.book(posting: transactionPosting(posting1))
                #expect(result1 == nil)
                _ = try inventory.book(posting: transactionPosting(posting2))
            } catch {
                errorMessage = error.localizedDescription
            }

            #expect(errorMessage == "No Lot matching -1.00 EUR {4.0 CAD} found, inventory: 2.0 EUR {2017-06-08, 3.0 CAD}")
        }
    }

   @Test
   func testReducePositive() throws {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
            let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

            let amount2 = Amount(number: 1.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
            let cost2 = try Cost(amount: nil, date: nil, label: nil)
            let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

            do {
                let result1 = try inventory.book(posting: transactionPosting(posting1))
                let result2 = try inventory.book(posting: transactionPosting(posting2))
                #expect(result1 == nil)
                #expect(result2 == cost1.amount?.multiCurrencyAmount)
            } catch {
                Issue.record("Error thrown")
            }

            #expect(inventory.inventory.count == 1)
            #expect(inventory.inventory.first?.units.number == amount1.number + amount2.number)
            #expect(inventory.inventory.first?.units.decimalDigits == 2)
            #expect(inventory.inventory.first?.cost == cost1)
        }
    }

   @Test
   func testReduceDifferentCurrencyPresent() throws {
        for bookingMethod in bookingMethods {
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

            do {
                let result1 = try inventory.book(posting: transactionPosting(posting1))
                let result2 = try inventory.book(posting: transactionPosting(posting2))
                let result3 = try inventory.book(posting: transactionPosting(posting3))
                #expect(result1 == nil)
                #expect(result2 == nil)
                #expect(result3 == Amount(number: -cost1.amount!.number,
                                          commoditySymbol: cost1.amount!.commoditySymbol,
                                          decimalDigits: cost1.amount!.decimalDigits).multiCurrencyAmount)
            } catch {
                Issue.record("Error thrown")
            }

            #expect(inventory.inventory.count == 2)
            #expect(inventory.inventory.first?.units.number == amount1.number + amount3.number)
            #expect(inventory.inventory.first?.units.decimalDigits == 2)
            #expect(inventory.inventory.first?.cost == cost1)
            #expect(inventory.inventory.last?.units == amount2)
            #expect(inventory.inventory.last?.cost == cost2)
        }
    }

   @Test
   func testReduceDifferentLotPresent() throws {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
            let cost1 = try Cost(amount: Amount(number: 5.5, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

            let amount2 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
            let cost2 = try Cost(amount: Amount(number: 2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
            let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

            let amount3 = Amount(number: -1.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
            let posting3 = Posting(accountName: TestUtils.cash, amount: amount3, price: nil, cost: cost1)

            do {
                let result1 = try inventory.book(posting: transactionPosting(posting1))
                let result2 = try inventory.book(posting: transactionPosting(posting2))
                let result3 = try inventory.book(posting: transactionPosting(posting3))
                #expect(result1 == nil)
                #expect(result2 == nil)
                #expect(result3 == Amount(number: -cost1.amount!.number,
                                          commoditySymbol: cost1.amount!.commoditySymbol,
                                          decimalDigits: cost1.amount!.decimalDigits).multiCurrencyAmount)
            } catch {
                Issue.record("Error thrown")
            }

            #expect(inventory.inventory.count == 2)
            #expect(inventory.inventory.first?.units.number == amount1.number + amount3.number)
            #expect(inventory.inventory.first?.units.decimalDigits == 2)
            #expect(inventory.inventory.first?.cost == cost1)
            #expect(inventory.inventory.last?.units == amount2)
            #expect(inventory.inventory.last?.cost == cost2)
        }
    }

   @Test
   func testReduceAmbigiousStrict() throws {
        let inventory = Inventory(bookingMethod: .strict)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost2 = try Cost(amount: Amount(number: 2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let amount3 = Amount(number: -1.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        let posting3 = Posting(accountName: TestUtils.cash, amount: amount3, price: nil, cost: try Cost(amount: nil, date: nil, label: nil))

        do {
            let result1 = try inventory.book(posting: transactionPosting(posting1))
            let result2 = try inventory.book(posting: transactionPosting(posting2))
            #expect(result1 == nil)
            #expect(result2 == nil)
        } catch {
            Issue.record("Error thrown")
        }

        let error = #expect(throws: (any Error).self) { try inventory.book(posting: transactionPosting(posting3)) }
        #expect(error.localizedDescription == """
            Ambigious Booking: -1.00 EUR {}, matches: 2.0 EUR {2017-06-08, 3.0 CAD}
            2.0 EUR {2017-06-08, 2.0 CAD}, inventory: 2.0 EUR {2017-06-08, 3.0 CAD}
            2.0 EUR {2017-06-08, 2.0 CAD}
            """)

        #expect(inventory.inventory.count == 2)
        #expect(inventory.inventory.first?.units == amount1)
        #expect(inventory.inventory.first?.cost == cost1)
        #expect(inventory.inventory.last?.units == amount2)
        #expect(inventory.inventory.last?.cost == cost2)
    }

   @Test
   func testReduceAmbigiousNotEnoughUnits() throws {
        for bookingMethod in [BookingMethod.lifo, BookingMethod.fifo] {
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

            do {
                let result1 = try inventory.book(posting: transactionPosting(posting1))
                let result2 = try inventory.book(posting: transactionPosting(posting2))
                #expect(result1 == nil)
                #expect(result2 == nil)
            } catch {
                Issue.record("Error thrown")
            }

            let error = #expect(throws: (any Error).self) { try inventory.book(posting: transactionPosting(posting3)) }
            #expect(error.localizedDescription == "Not enough units: Trying to reduce by \(amount3) \(cost3)")
        }
    }

   @Test
   func testReduceAmbigiousLIFO() throws {
        let inventory = Inventory(bookingMethod: .lifo)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost2 = try Cost(amount: Amount(number: 2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let amount3 = Amount(number: -1.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let posting3 = Posting(accountName: TestUtils.cash, amount: amount3, price: nil, cost: try Cost(amount: nil, date: nil, label: nil))

        do {
            let result1 = try inventory.book(posting: transactionPosting(posting1))
            let result2 = try inventory.book(posting: transactionPosting(posting2))
            #expect(result1 == nil)
            #expect(result2 == nil)
        } catch {
            Issue.record("Error thrown")
        }

        do {
            let result = try inventory.book(posting: transactionPosting(posting3))
            #expect(result == Amount(number: -2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1).multiCurrencyAmount)
        } catch {
            Issue.record("Error thrown")
        }

        #expect(inventory.inventory.count == 2)
        #expect(inventory.inventory.first?.units == amount1)
        #expect(inventory.inventory.first?.cost == cost1)
        #expect(inventory.inventory.last?.units == Amount(number: 1.0, commoditySymbol: TestUtils.eur, decimalDigits: 1))
        #expect(inventory.inventory.last?.cost == cost2)
    }

   @Test
   func testReduceAmbigiousLIFOExactLot() throws {
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
   func testReduceAmbigiousLIFOMultipleLots() throws {
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
   func testReduceAmbigiousFIFO() throws {
        let inventory = Inventory(bookingMethod: .fifo)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost2 = try Cost(amount: Amount(number: 2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let amount3 = Amount(number: -1.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let posting3 = Posting(accountName: TestUtils.cash, amount: amount3, price: nil, cost: try Cost(amount: nil, date: nil, label: nil))

        do {
            let result1 = try inventory.book(posting: transactionPosting(posting1))
            let result2 = try inventory.book(posting: transactionPosting(posting2))
            #expect(result1 == nil)
            #expect(result2 == nil)
        } catch {
            Issue.record("Error thrown")
        }

        do {
            let result = try inventory.book(posting: transactionPosting(posting3))
            #expect(result == Amount(number: -3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1).multiCurrencyAmount)
        } catch {
            Issue.record("Error thrown")
        }

        #expect(inventory.inventory.count == 2)
        #expect(inventory.inventory.first?.units == Amount(number: 1.0, commoditySymbol: TestUtils.eur, decimalDigits: 1))
        #expect(inventory.inventory.first?.cost == cost1)
        #expect(inventory.inventory.last?.units == amount2)
        #expect(inventory.inventory.last?.cost == cost2)
    }

   @Test
   func testReduceAmbigiousFIFOExactLot() throws {
        let inventory = Inventory(bookingMethod: .fifo)

        let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

        let amount2 = Amount(number: 3.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost2 = try Cost(amount: Amount(number: 2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

        let amount3 = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let posting3 = Posting(accountName: TestUtils.cash, amount: amount3, price: nil, cost: try Cost(amount: nil, date: nil, label: nil))

        do {
            let result1 = try inventory.book(posting: transactionPosting(posting1))
            let result2 = try inventory.book(posting: transactionPosting(posting2))
            #expect(result1 == nil)
            #expect(result2 == nil)
        } catch {
            Issue.record("Error thrown")
        }

        do {
            let result = try inventory.book(posting: transactionPosting(posting3))
            #expect(result == Amount(number: -6.0, commoditySymbol: TestUtils.cad, decimalDigits: 1).multiCurrencyAmount)
        } catch {
            Issue.record("Error thrown")
        }

        #expect(inventory.inventory.count == 1)
        #expect(inventory.inventory.last?.units == amount2)
        #expect(inventory.inventory.last?.cost == cost2)
    }

   @Test
   func testReduceAmbigiousFIFOMultipleLots() throws {
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

   @Test
   func testTotalReduce() throws {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
            let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: nil, label: nil)
            let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

            let amount2 = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
            let cost2 = try Cost(amount: nil, date: nil, label: nil)
            let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

            do {
                let result1 = try inventory.book(posting: transactionPosting(posting1))
                let result2 = try inventory.book(posting: transactionPosting(posting2))
                #expect(result1 == nil)
                #expect(result2 == Amount(number: amount2.number * cost1.amount!.number,
                                          commoditySymbol: cost1.amount!.commoditySymbol,
                                          decimalDigits: cost1.amount!.decimalDigits).multiCurrencyAmount)
            } catch {
                Issue.record("Error thrown")
            }

            #expect(inventory.inventory.isEmpty)
        }
    }

   @Test
   func testTotalReduceMultipleLots() throws {
        for bookingMethod in bookingMethods {
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

            do {
                let result1 = try inventory.book(posting: transactionPosting(posting1))
                let result2 = try inventory.book(posting: transactionPosting(posting2))
                let result3 = try inventory.book(posting: transactionPosting(posting3))
                #expect(result1 == nil)
                #expect(result2 == nil)
                #expect(result3 == MultiCurrencyAmount(amounts: [TestUtils.cad: -11.1], decimalDigits: [TestUtils.cad: 2]))
            } catch {
                Issue.record("Error thrown")
            }

            #expect(inventory.inventory.isEmpty)
        }
    }

   @Test
   func testTotalReduceDifferentCurrencyPresent() throws {
        for bookingMethod in bookingMethods {
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

            do {
                let result1 = try inventory.book(posting: transactionPosting(posting1))
                let result2 = try inventory.book(posting: transactionPosting(posting2))
                let result3 = try inventory.book(posting: transactionPosting(posting3))
                #expect(result1 == nil)
                #expect(result2 == nil)
                #expect(result3 == Amount(number: amount3.number * cost1.amount!.number,
                                          commoditySymbol: cost1.amount!.commoditySymbol,
                                          decimalDigits: cost1.amount!.decimalDigits).multiCurrencyAmount)
            } catch {
                Issue.record("Error thrown")
            }

            #expect(inventory.inventory.count == 1)
            #expect(inventory.inventory.first?.units == amount2)
            #expect(inventory.inventory.first?.cost == cost2)
        }
    }

   @Test
   func testTotalReduceDifferentLotPresent() throws {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
            let cost1 = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: nil, label: nil)
            let posting1 = Posting(accountName: TestUtils.cash, amount: amount1, price: nil, cost: cost1)

            let amount2 = Amount(number: 2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
            let cost2 = try Cost(amount: Amount(number: 2.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: date, label: nil)
            let posting2 = Posting(accountName: TestUtils.cash, amount: amount2, price: nil, cost: cost2)

            let amount3 = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
            let posting3 = Posting(accountName: TestUtils.cash, amount: amount3, price: nil, cost: cost1)

            do {
                let result1 = try inventory.book(posting: transactionPosting(posting1))
                let result2 = try inventory.book(posting: transactionPosting(posting2))
                let result3 = try inventory.book(posting: transactionPosting(posting3))
                #expect(result1 == nil)
                #expect(result2 == nil)
                #expect(result3 == Amount(number: amount3.number * cost1.amount!.number,
                                          commoditySymbol: cost1.amount!.commoditySymbol,
                                          decimalDigits: cost1.amount!.decimalDigits).multiCurrencyAmount)
            } catch {
                Issue.record("Error thrown")
            }

            #expect(inventory.inventory.count == 1)
            #expect(inventory.inventory.first?.units == amount2)
            #expect(inventory.inventory.first?.cost == cost2)
        }
    }

   @Test
   func testAmountDifferentCurrency() throws {
        for bookingMethod in bookingMethods {
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

            do {
                let result1 = try inventory.book(posting: transactionPosting(posting1))
                let result2 = try inventory.book(posting: transactionPosting(posting2))
                let result3 = try inventory.book(posting: transactionPosting(posting3))
                #expect(result1 == nil)
                #expect(result2 == nil)
                #expect(result3 == MultiCurrencyAmount(amounts: [TestUtils.eur: -6.10, TestUtils.cad: -5.0], decimalDigits: [TestUtils.eur: 2, TestUtils.cad: 1]))
            } catch {
                Issue.record("Error thrown")
            }

            #expect(inventory.inventory.isEmpty)
        }
    }

   func transactionPosting(_ posting: Posting) -> TransactionPosting {
        let transaction = Transaction(metaData: TransactionMetaData(date: date,
                                                                    payee: "Payee",
                                                                    narration: "Narration",
                                                                    flag: Flag.complete,
                                                                    tags: []),
                                      postings: [posting])
        transactionStore.append(transaction)
        return transaction.postings[0]

    }

}

extension InventoryTests { // Inventory.Lot Tests

   @Test
   func testLotDescription() throws {
        let amount = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: nil, label: nil)
        let lot = Inventory.Lot(units: amount, cost: cost)
        #expect(String(describing: lot) == "\(amount) \(cost)")
    }

   @Test
   func testLotEqual() throws {
        let amount = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let cost = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: nil, label: nil)
        let lot1 = Inventory.Lot(units: amount, cost: cost)
        let lot2 = Inventory.Lot(units: amount, cost: cost)
        #expect(lot1 == lot2)
    }

   @Test
   func testLotEqualRespectsAmount() throws {
        let amount1 = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 1)
        let amount2 = Amount(number: -2.0, commoditySymbol: TestUtils.eur, decimalDigits: 2)
        let cost = try Cost(amount: Amount(number: 3.0, commoditySymbol: TestUtils.cad, decimalDigits: 1), date: nil, label: nil)
        let lot1 = Inventory.Lot(units: amount1, cost: cost)
        let lot2 = Inventory.Lot(units: amount2, cost: cost)
        #expect(lot1 != lot2)
    }

   @Test
   func testLotEqualRespectsCost() throws {
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
   func testBookingMethodDescription() {
        #expect(String(describing: BookingMethod.fifo) == "FIFO")
        #expect(String(describing: BookingMethod.lifo) == "LIFO")
        #expect(String(describing: BookingMethod.strict) == "STRICT")
    }

}
