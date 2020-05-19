//
//  InventoryTests.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2019-09-14.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

// swiftlint:disable file_length
@testable import SwiftBeanCountModel
import XCTest

class InventoryTests: XCTestCase {

    let bookingMethods = [BookingMethod.strict, BookingMethod.lifo, BookingMethod.fifo]

    let date = Date(timeIntervalSince1970: 1_496_905_200)
    let transaction = Transaction(metaData: TransactionMetaData(date: Date(timeIntervalSince1970: 1_496_905_200),
                                                                payee: "Payee",
                                                                narration: "Narration",
                                                                flag: Flag.complete,
                                                                tags: []))
    let accountName = try! AccountName("Assets:Inventory")
    var account: Account!
    let commodity1 = Commodity(symbol: "EUR")
    let commodity2 = Commodity(symbol: "CAD")

    override func setUp() {
        super.setUp()
        account = Account(name: accountName)
    }

    func testInit() {
        for bookingMethod in bookingMethods {
            XCTAssertNotNil(Inventory(bookingMethod: bookingMethod))
        }
    }

    func testDescription() {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
            let cost1 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

            let amount2 = Amount(number: 3.0, commodity: commodity1, decimalDigits: 2)
            let cost2 = try! Cost(amount: Amount(number: 5.0, commodity: commodity2, decimalDigits: 2), date: date, label: nil)
            let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

            do {
                let result1 = try inventory.book(posting: posting1)
                let result2 = try inventory.book(posting: posting2)
                XCTAssertNil(result1)
                XCTAssertNil(result2)
            } catch {
                XCTFail("Error thrown")
            }

            XCTAssertEqual(String(describing: inventory), """
                \(amount1) \(cost1)
                \(amount2) \(cost2)
                """)
        }
    }

}

extension InventoryTests { // Test Adding

    func testAdding() {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)
            let amount = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
            let cost = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
            let posting = Posting(accountName: accountName, amount: amount, transaction: transaction, price: nil, cost: cost)

            do {
                let result = try inventory.book(posting: posting)
                XCTAssertNil(result)
            } catch {
                XCTFail("Error thrown")
            }

            XCTAssertEqual(inventory.inventory.count, 1)
            XCTAssertEqual(inventory.inventory.first?.units, amount)
            XCTAssertEqual(inventory.inventory.first?.cost, cost)
        }
    }

    func testAddingTransactionDateUsed() {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)
            let amount = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
            let cost = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: nil, label: nil)
            let posting = Posting(accountName: accountName, amount: amount, transaction: transaction, price: nil, cost: cost)

            do {
                let result = try inventory.book(posting: posting)
                XCTAssertNil(result)
            } catch {
                XCTFail("Error thrown")
            }

            XCTAssertEqual(inventory.inventory.first?.cost.date, date)
        }
    }

    func testAddingMultiple() {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
            let cost1 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

            let amount2 = Amount(number: 3.0, commodity: commodity1, decimalDigits: 2)
            let cost2 = try! Cost(amount: Amount(number: 5.0, commodity: commodity2, decimalDigits: 2), date: date, label: nil)
            let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

            do {
                let result1 = try inventory.book(posting: posting1)
                let result2 = try inventory.book(posting: posting2)
                XCTAssertNil(result1)
                XCTAssertNil(result2)
            } catch {
                XCTFail("Error thrown")
            }

            XCTAssertEqual(inventory.inventory.count, 2)
            XCTAssertEqual(inventory.inventory.first?.units, amount1)
            XCTAssertEqual(inventory.inventory.first?.cost, cost1)
            XCTAssertEqual(inventory.inventory.last?.units, amount2)
            XCTAssertEqual(inventory.inventory.last?.cost, cost2)
        }
    }

    func testAddingSameCost() {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
            let cost = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost)

            let amount2 = Amount(number: 3.0, commodity: commodity1, decimalDigits: 2)
            let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost)

            do {
                let result1 = try inventory.book(posting: posting1)
                let result2 = try inventory.book(posting: posting2)
                XCTAssertNil(result1)
                XCTAssertNil(result2)
            } catch {
                XCTFail("Error thrown")
            }

            XCTAssertEqual(inventory.inventory.count, 1)
            XCTAssertEqual(inventory.inventory.first?.units.commodity, commodity1)
            XCTAssertEqual(inventory.inventory.first?.units.decimalDigits, 2)
            XCTAssertEqual(inventory.inventory.first?.units.number, amount1.number + amount2.number)
            XCTAssertEqual(inventory.inventory.first?.cost, cost)
        }
    }

    func testAddingSameCostDifferentCommodity() {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
            let cost = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost)

            let amount2 = Amount(number: 3.0, commodity: commodity2, decimalDigits: 2)
            let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost)

            do {
                let result1 = try inventory.book(posting: posting1)
                let result2 = try inventory.book(posting: posting2)
                XCTAssertNil(result1)
                XCTAssertNil(result2)
            } catch {
                XCTFail("Error thrown")
            }

            XCTAssertEqual(inventory.inventory.count, 2)
            XCTAssertEqual(inventory.inventory.first?.units, amount1)
            XCTAssertEqual(inventory.inventory.first?.cost, cost)
            XCTAssertEqual(inventory.inventory.last?.units, amount2)
            XCTAssertEqual(inventory.inventory.last?.cost, cost)
        }
    }

    func testAddingNegative() {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)
            let amount = Amount(number: -2.0, commodity: commodity1, decimalDigits: 1)
            let cost = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
            let posting = Posting(accountName: accountName, amount: amount, transaction: transaction, price: nil, cost: cost)

            do {
                let result = try inventory.book(posting: posting)
                XCTAssertNil(result)
            } catch {
                XCTFail("Error thrown")
            }

            XCTAssertEqual(inventory.inventory.count, 1)
            XCTAssertEqual(inventory.inventory.first?.units, amount)
            XCTAssertEqual(inventory.inventory.first?.cost, cost)
        }
    }

    func testAddingMultipleNegative() {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: -2.0, commodity: commodity1, decimalDigits: 1)
            let cost1 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

            let amount2 = Amount(number: -3.0, commodity: commodity1, decimalDigits: 2)
            let cost2 = try! Cost(amount: Amount(number: 5.0, commodity: commodity2, decimalDigits: 2), date: date, label: nil)
            let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

            do {
                let result1 = try inventory.book(posting: posting1)
                let result2 = try inventory.book(posting: posting2)
                XCTAssertNil(result1)
                XCTAssertNil(result2)
            } catch {
                XCTFail("Error thrown")
            }

            XCTAssertEqual(inventory.inventory.count, 2)
            XCTAssertEqual(inventory.inventory.first?.units, amount1)
            XCTAssertEqual(inventory.inventory.first?.cost, cost1)
            XCTAssertEqual(inventory.inventory.last?.units, amount2)
            XCTAssertEqual(inventory.inventory.last?.cost, cost2)
        }
    }

    func testAddingSameCostNegative() {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: -2.0, commodity: commodity1, decimalDigits: 1)
            let cost = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost)

            let amount2 = Amount(number: -3.0, commodity: commodity1, decimalDigits: 2)
            let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost)

            do {
                let result1 = try inventory.book(posting: posting1)
                let result2 = try inventory.book(posting: posting2)
                XCTAssertNil(result1)
                XCTAssertNil(result2)
            } catch {
                XCTFail("Error thrown")
            }

            XCTAssertEqual(inventory.inventory.count, 1)
            XCTAssertEqual(inventory.inventory.first?.units.commodity, commodity1)
            XCTAssertEqual(inventory.inventory.first?.units.decimalDigits, 2)
            XCTAssertEqual(inventory.inventory.first?.units.number, amount1.number + amount2.number)
            XCTAssertEqual(inventory.inventory.first?.cost, cost)
        }
    }

}

extension InventoryTests { // Test Reduce

    func testReduce() {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
            let cost1 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

            let amount2 = Amount(number: -1.0, commodity: commodity1, decimalDigits: 2)
            let cost2 = try! Cost(amount: nil, date: nil, label: nil)
            let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

            do {
                let result1 = try inventory.book(posting: posting1)
                let result2 = try inventory.book(posting: posting2)
                XCTAssertNil(result1)
                XCTAssertEqual(result2, Amount(number: -cost1.amount!.number,
                                               commodity: cost1.amount!.commodity,
                                               decimalDigits: cost1.amount!.decimalDigits).multiCurrencyAmount)
            } catch {
                XCTFail("Error thrown")
            }

            XCTAssertEqual(inventory.inventory.count, 1)
            XCTAssertEqual(inventory.inventory.first?.units.number, amount1.number + amount2.number)
            XCTAssertEqual(inventory.inventory.first?.units.decimalDigits, 2)
            XCTAssertEqual(inventory.inventory.first?.cost, cost1)
        }
    }

    func testReduceMoreThanExist() {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
            let cost1 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

            let amount2 = Amount(number: -3.0, commodity: commodity1, decimalDigits: 2)
            let cost2 = try! Cost(amount: nil, date: nil, label: nil)
            let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

            var errorMessage = ""
            do {
                let result1 = try inventory.book(posting: posting1)
                XCTAssertNil(result1)
                _ = try inventory.book(posting: posting2)
            } catch {
                errorMessage = error.localizedDescription
            }

            XCTAssertEqual(errorMessage, "Lot not big enough: Trying to reduce 2.0 EUR {2017-06-08, 3.0 CAD} by -3.00 EUR {}")
        }
    }

    func testReduceNoLot() {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
            let cost1 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

            let amount2 = Amount(number: -1.0, commodity: commodity1, decimalDigits: 2)
            let cost2 = try! Cost(amount: Amount(number: 4.0, commodity: commodity2, decimalDigits: 1), date: nil, label: nil)
            let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

            var errorMessage = ""
            do {
                let result1 = try inventory.book(posting: posting1)
                XCTAssertNil(result1)
                _ = try inventory.book(posting: posting2)
            } catch {
                errorMessage = error.localizedDescription
            }

            XCTAssertEqual(errorMessage, "No Lot matching -1.00 EUR {4.0 CAD} found, inventory: 2.0 EUR {2017-06-08, 3.0 CAD}")
        }
    }

    func testReducePositive() {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: -2.0, commodity: commodity1, decimalDigits: 1)
            let cost1 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

            let amount2 = Amount(number: 1.0, commodity: commodity1, decimalDigits: 2)
            let cost2 = try! Cost(amount: nil, date: nil, label: nil)
            let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

            do {
                let result1 = try inventory.book(posting: posting1)
                let result2 = try inventory.book(posting: posting2)
                XCTAssertNil(result1)
                XCTAssertEqual(result2, cost1.amount?.multiCurrencyAmount)
            } catch {
                XCTFail("Error thrown")
            }

            XCTAssertEqual(inventory.inventory.count, 1)
            XCTAssertEqual(inventory.inventory.first?.units.number, amount1.number + amount2.number)
            XCTAssertEqual(inventory.inventory.first?.units.decimalDigits, 2)
            XCTAssertEqual(inventory.inventory.first?.cost, cost1)
        }
    }

    func testReduceDifferentCurrencyPresent() {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
            let cost1 = try! Cost(amount: Amount(number: 3.567, commodity: commodity2, decimalDigits: 3), date: date, label: nil)
            let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

            let amount2 = Amount(number: 1.0, commodity: commodity2, decimalDigits: 2)
            let cost2 = try! Cost(amount: nil, date: date, label: nil)
            let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

            let amount3 = Amount(number: -1.0, commodity: commodity1, decimalDigits: 2)
            let cost3 = try! Cost(amount: nil, date: nil, label: nil)
            let posting3 = Posting(accountName: accountName, amount: amount3, transaction: transaction, price: nil, cost: cost3)

            do {
                let result1 = try inventory.book(posting: posting1)
                let result2 = try inventory.book(posting: posting2)
                let result3 = try inventory.book(posting: posting3)
                XCTAssertNil(result1)
                XCTAssertNil(result2)
                XCTAssertEqual(result3, Amount(number: -cost1.amount!.number,
                                               commodity: cost1.amount!.commodity,
                                               decimalDigits: cost1.amount!.decimalDigits).multiCurrencyAmount)
            } catch {
                XCTFail("Error thrown")
            }

            XCTAssertEqual(inventory.inventory.count, 2)
            XCTAssertEqual(inventory.inventory.first?.units.number, amount1.number + amount3.number)
            XCTAssertEqual(inventory.inventory.first?.units.decimalDigits, 2)
            XCTAssertEqual(inventory.inventory.first?.cost, cost1)
            XCTAssertEqual(inventory.inventory.last?.units, amount2)
            XCTAssertEqual(inventory.inventory.last?.cost, cost2)
        }
    }

    func testReduceDifferentLotPresent() {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
            let cost1 = try! Cost(amount: Amount(number: 5.5, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

            let amount2 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
            let cost2 = try! Cost(amount: Amount(number: 2.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
            let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

            let amount3 = Amount(number: -1.0, commodity: commodity1, decimalDigits: 2)
            let posting3 = Posting(accountName: accountName, amount: amount3, transaction: transaction, price: nil, cost: cost1)

            do {
                let result1 = try inventory.book(posting: posting1)
                let result2 = try inventory.book(posting: posting2)
                let result3 = try inventory.book(posting: posting3)
                XCTAssertNil(result1)
                XCTAssertNil(result2)
                XCTAssertEqual(result3, Amount(number: -cost1.amount!.number,
                                               commodity: cost1.amount!.commodity,
                                               decimalDigits: cost1.amount!.decimalDigits).multiCurrencyAmount)
            } catch {
                XCTFail("Error thrown")
            }

            XCTAssertEqual(inventory.inventory.count, 2)
            XCTAssertEqual(inventory.inventory.first?.units.number, amount1.number + amount3.number)
            XCTAssertEqual(inventory.inventory.first?.units.decimalDigits, 2)
            XCTAssertEqual(inventory.inventory.first?.cost, cost1)
            XCTAssertEqual(inventory.inventory.last?.units, amount2)
            XCTAssertEqual(inventory.inventory.last?.cost, cost2)
        }
    }

    func testReduceAmbigiousStrict() {
        let inventory = Inventory(bookingMethod: .strict)

        let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
        let cost1 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
        let cost2 = try! Cost(amount: Amount(number: 2.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

        let amount3 = Amount(number: -1.0, commodity: commodity1, decimalDigits: 2)
        let posting3 = Posting(accountName: accountName, amount: amount3, transaction: transaction, price: nil, cost: try! Cost(amount: nil, date: nil, label: nil))

        do {
            let result1 = try inventory.book(posting: posting1)
            let result2 = try inventory.book(posting: posting2)
            XCTAssertNil(result1)
            XCTAssertNil(result2)
        } catch {
            XCTFail("Error thrown")
        }

        XCTAssertThrowsError(try inventory.book(posting: posting3)) {
            XCTAssertEqual($0.localizedDescription, """
            Ambigious Booking: -1.00 EUR {}, matches: 2.0 EUR {2017-06-08, 3.0 CAD}
            2.0 EUR {2017-06-08, 2.0 CAD}, inventory: 2.0 EUR {2017-06-08, 3.0 CAD}
            2.0 EUR {2017-06-08, 2.0 CAD}
            """)
        }

        XCTAssertEqual(inventory.inventory.count, 2)
        XCTAssertEqual(inventory.inventory.first?.units, amount1)
        XCTAssertEqual(inventory.inventory.first?.cost, cost1)
        XCTAssertEqual(inventory.inventory.last?.units, amount2)
        XCTAssertEqual(inventory.inventory.last?.cost, cost2)
    }

    func testReduceAmbigiousNotEnoughUnits() {
        for bookingMethod in [BookingMethod.lifo, BookingMethod.fifo] {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
            let cost1 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
            let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

            let amount2 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
            let cost2 = try! Cost(amount: Amount(number: 2.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
            let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

            let amount3 = Amount(number: -5.0, commodity: commodity1, decimalDigits: 1)
            let cost3 = try! Cost(amount: nil, date: nil, label: nil)
            let posting3 = Posting(accountName: accountName, amount: amount3, transaction: transaction, price: nil, cost: cost3)

            do {
                let result1 = try inventory.book(posting: posting1)
                let result2 = try inventory.book(posting: posting2)
                XCTAssertNil(result1)
                XCTAssertNil(result2)
            } catch {
                XCTFail("Error thrown")
            }

            XCTAssertThrowsError(try inventory.book(posting: posting3)) {
                XCTAssertEqual($0.localizedDescription, "Not enough units: Trying to reduce by \(amount3) \(cost3)")
            }
        }
    }

    func testReduceAmbigiousLIFO() {
        let inventory = Inventory(bookingMethod: .lifo)

        let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
        let cost1 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
        let cost2 = try! Cost(amount: Amount(number: 2.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

        let amount3 = Amount(number: -1.0, commodity: commodity1, decimalDigits: 1)
        let posting3 = Posting(accountName: accountName, amount: amount3, transaction: transaction, price: nil, cost: try! Cost(amount: nil, date: nil, label: nil))

        do {
            let result1 = try inventory.book(posting: posting1)
            let result2 = try inventory.book(posting: posting2)
            XCTAssertNil(result1)
            XCTAssertNil(result2)
        } catch {
            XCTFail("Error thrown")
        }

        do {
            let result = try inventory.book(posting: posting3)
            XCTAssertEqual(result, Amount(number: -2.0, commodity: commodity2, decimalDigits: 1).multiCurrencyAmount)
        } catch {
            XCTFail("Error thrown")
        }

        XCTAssertEqual(inventory.inventory.count, 2)
        XCTAssertEqual(inventory.inventory.first?.units, amount1)
        XCTAssertEqual(inventory.inventory.first?.cost, cost1)
        XCTAssertEqual(inventory.inventory.last?.units, Amount(number: 1.0, commodity: commodity1, decimalDigits: 1))
        XCTAssertEqual(inventory.inventory.last?.cost, cost2)
    }

    func testReduceAmbigiousLIFOExactLot() {
        let inventory = Inventory(bookingMethod: .lifo)

        let amount1 = Amount(number: 3.0, commodity: commodity1, decimalDigits: 1)
        let cost1 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
        let cost2 = try! Cost(amount: Amount(number: 2.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

        let amount3 = Amount(number: -2.0, commodity: commodity1, decimalDigits: 1)
        let posting3 = Posting(accountName: accountName, amount: amount3, transaction: transaction, price: nil, cost: try! Cost(amount: nil, date: nil, label: nil))

        do {
            let result1 = try inventory.book(posting: posting1)
            let result2 = try inventory.book(posting: posting2)
            XCTAssertNil(result1)
            XCTAssertNil(result2)
        } catch {
            XCTFail("Error thrown")
        }

        do {
            let result = try inventory.book(posting: posting3)
            XCTAssertEqual(result, Amount(number: -4.0, commodity: commodity2, decimalDigits: 1).multiCurrencyAmount)
        } catch {
            XCTFail("Error thrown")
        }

        XCTAssertEqual(inventory.inventory.count, 1)
        XCTAssertEqual(inventory.inventory.last?.units, amount1)
        XCTAssertEqual(inventory.inventory.last?.cost, cost1)
    }

    func testReduceAmbigiousLIFOMultipleLots() {
        let inventory = Inventory(bookingMethod: .lifo)

        let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
        let cost1 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
        let cost2 = try! Cost(amount: Amount(number: 2.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

        let amount3 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
        let cost3 = try! Cost(amount: Amount(number: 4.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
        let posting3 = Posting(accountName: accountName, amount: amount3, transaction: transaction, price: nil, cost: cost3)

        let amount4 = Amount(number: -5.0, commodity: commodity1, decimalDigits: 1)
        let posting4 = Posting(accountName: accountName, amount: amount4, transaction: transaction, price: nil, cost: try! Cost(amount: nil, date: nil, label: nil))

        do {
            let result1 = try inventory.book(posting: posting1)
            let result2 = try inventory.book(posting: posting2)
            let result3 = try inventory.book(posting: posting3)
            XCTAssertNil(result1)
            XCTAssertNil(result2)
            XCTAssertNil(result3)
        } catch {
            XCTFail("Error thrown")
        }

        do {
            let result = try inventory.book(posting: posting4)
            XCTAssertEqual(result, Amount(number: -15.0, commodity: commodity2, decimalDigits: 1).multiCurrencyAmount)
        } catch {
            XCTFail("Error thrown")
        }

        XCTAssertEqual(inventory.inventory.count, 1)
        XCTAssertEqual(inventory.inventory.last?.units, Amount(number: 1.0, commodity: commodity1, decimalDigits: 1))
        XCTAssertEqual(inventory.inventory.last?.cost, cost1)
    }

    func testReduceAmbigiousFIFO() {
        let inventory = Inventory(bookingMethod: .fifo)

        let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
        let cost1 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
        let cost2 = try! Cost(amount: Amount(number: 2.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

        let amount3 = Amount(number: -1.0, commodity: commodity1, decimalDigits: 1)
        let posting3 = Posting(accountName: accountName, amount: amount3, transaction: transaction, price: nil, cost: try! Cost(amount: nil, date: nil, label: nil))

        do {
            let result1 = try inventory.book(posting: posting1)
            let result2 = try inventory.book(posting: posting2)
            XCTAssertNil(result1)
            XCTAssertNil(result2)
        } catch {
            XCTFail("Error thrown")
        }

        do {
            let result = try inventory.book(posting: posting3)
            XCTAssertEqual(result, Amount(number: -3.0, commodity: commodity2, decimalDigits: 1).multiCurrencyAmount)
        } catch {
            XCTFail("Error thrown")
        }

        XCTAssertEqual(inventory.inventory.count, 2)
        XCTAssertEqual(inventory.inventory.first?.units, Amount(number: 1.0, commodity: commodity1, decimalDigits: 1))
        XCTAssertEqual(inventory.inventory.first?.cost, cost1)
        XCTAssertEqual(inventory.inventory.last?.units, amount2)
        XCTAssertEqual(inventory.inventory.last?.cost, cost2)
    }

    func testReduceAmbigiousFIFOExactLot() {
        let inventory = Inventory(bookingMethod: .fifo)

        let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
        let cost1 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

        let amount2 = Amount(number: 3.0, commodity: commodity1, decimalDigits: 1)
        let cost2 = try! Cost(amount: Amount(number: 2.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

        let amount3 = Amount(number: -2.0, commodity: commodity1, decimalDigits: 1)
        let posting3 = Posting(accountName: accountName, amount: amount3, transaction: transaction, price: nil, cost: try! Cost(amount: nil, date: nil, label: nil))

        do {
            let result1 = try inventory.book(posting: posting1)
            let result2 = try inventory.book(posting: posting2)
            XCTAssertNil(result1)
            XCTAssertNil(result2)
        } catch {
            XCTFail("Error thrown")
        }

        do {
            let result = try inventory.book(posting: posting3)
            XCTAssertEqual(result, Amount(number: -6.0, commodity: commodity2, decimalDigits: 1).multiCurrencyAmount)
        } catch {
            XCTFail("Error thrown")
        }

        XCTAssertEqual(inventory.inventory.count, 1)
        XCTAssertEqual(inventory.inventory.last?.units, amount2)
        XCTAssertEqual(inventory.inventory.last?.cost, cost2)
    }

    func testReduceAmbigiousFIFOMultipleLots() {
        let inventory = Inventory(bookingMethod: .fifo)

        let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
        let cost1 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
        let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

        let amount2 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
        let cost2 = try! Cost(amount: Amount(number: 2.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
        let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

        let amount3 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
        let cost3 = try! Cost(amount: Amount(number: 4.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
        let posting3 = Posting(accountName: accountName, amount: amount3, transaction: transaction, price: nil, cost: cost3)

        let amount4 = Amount(number: -5.0, commodity: commodity1, decimalDigits: 1)
        let posting4 = Posting(accountName: accountName, amount: amount4, transaction: transaction, price: nil, cost: try! Cost(amount: nil, date: nil, label: nil))

        do {
            let result1 = try inventory.book(posting: posting1)
            let result2 = try inventory.book(posting: posting2)
            let result3 = try inventory.book(posting: posting3)
            XCTAssertNil(result1)
            XCTAssertNil(result2)
            XCTAssertNil(result3)
        } catch {
            XCTFail("Error thrown")
        }

        do {
            let result = try inventory.book(posting: posting4)
            XCTAssertEqual(result, Amount(number: -14.0, commodity: commodity2, decimalDigits: 1).multiCurrencyAmount)
        } catch {
            XCTFail("Error thrown")
        }

        XCTAssertEqual(inventory.inventory.count, 1)
        XCTAssertEqual(inventory.inventory.last?.units, Amount(number: 1.0, commodity: commodity1, decimalDigits: 1))
        XCTAssertEqual(inventory.inventory.last?.cost, cost3)
    }

    func testTotalReduce() {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
            let cost1 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: nil, label: nil)
            let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

            let amount2 = Amount(number: -2.0, commodity: commodity1, decimalDigits: 2)
            let cost2 = try! Cost(amount: nil, date: nil, label: nil)
            let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

            do {
                let result1 = try inventory.book(posting: posting1)
                let result2 = try inventory.book(posting: posting2)
                XCTAssertNil(result1)
                XCTAssertEqual(result2, Amount(number: amount2.number * cost1.amount!.number,
                                               commodity: cost1.amount!.commodity,
                                               decimalDigits: cost1.amount!.decimalDigits).multiCurrencyAmount)
            } catch {
                XCTFail("Error thrown")
            }

            XCTAssertEqual(inventory.inventory.count, 0)
        }
    }

    func testTotalReduceMultipleLots() {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.5, commodity: commodity1, decimalDigits: 1)
            let cost1 = try! Cost(amount: Amount(number: 2.0, commodity: commodity2, decimalDigits: 1), date: nil, label: nil)
            let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

            let amount2 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
            let cost2 = try! Cost(amount: Amount(number: 3.05, commodity: commodity2, decimalDigits: 2), date: date, label: nil)
            let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

            let amount3 = Amount(number: -4.5, commodity: commodity1, decimalDigits: 2)
            let cost3 = try! Cost(amount: nil, date: nil, label: nil)
            let posting3 = Posting(accountName: accountName, amount: amount3, transaction: transaction, price: nil, cost: cost3)

            do {
                let result1 = try inventory.book(posting: posting1)
                let result2 = try inventory.book(posting: posting2)
                let result3 = try inventory.book(posting: posting3)
                XCTAssertNil(result1)
                XCTAssertNil(result2)
                XCTAssertEqual(result3, MultiCurrencyAmount(amounts: [commodity2: -11.1], decimalDigits: [commodity2: 2]))
            } catch {
                XCTFail("Error thrown")
            }

            XCTAssertEqual(inventory.inventory.count, 0)
        }
    }

    func testTotalReduceDifferentCurrencyPresent() {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
            let cost1 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: nil, label: nil)
            let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

            let amount2 = Amount(number: 2.0, commodity: commodity2, decimalDigits: 1)
            let cost2 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
            let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

            let amount3 = Amount(number: -2.0, commodity: commodity1, decimalDigits: 2)
            let cost3 = try! Cost(amount: nil, date: nil, label: nil)
            let posting3 = Posting(accountName: accountName, amount: amount3, transaction: transaction, price: nil, cost: cost3)

            do {
                let result1 = try inventory.book(posting: posting1)
                let result2 = try inventory.book(posting: posting2)
                let result3 = try inventory.book(posting: posting3)
                XCTAssertNil(result1)
                XCTAssertNil(result2)
                XCTAssertEqual(result3, Amount(number: amount3.number * cost1.amount!.number,
                                               commodity: cost1.amount!.commodity,
                                               decimalDigits: cost1.amount!.decimalDigits).multiCurrencyAmount)
            } catch {
                XCTFail("Error thrown")
            }

            XCTAssertEqual(inventory.inventory.count, 1)
            XCTAssertEqual(inventory.inventory.first?.units, amount2)
            XCTAssertEqual(inventory.inventory.first?.cost, cost2)
        }
    }

    func testTotalReduceDifferentLotPresent() {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
            let cost1 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: nil, label: nil)
            let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

            let amount2 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
            let cost2 = try! Cost(amount: Amount(number: 2.0, commodity: commodity2, decimalDigits: 1), date: date, label: nil)
            let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

            let amount3 = Amount(number: -2.0, commodity: commodity1, decimalDigits: 2)
            let posting3 = Posting(accountName: accountName, amount: amount3, transaction: transaction, price: nil, cost: cost1)

            do {
                let result1 = try inventory.book(posting: posting1)
                let result2 = try inventory.book(posting: posting2)
                let result3 = try inventory.book(posting: posting3)
                XCTAssertNil(result1)
                XCTAssertNil(result2)
                XCTAssertEqual(result3, Amount(number: amount3.number * cost1.amount!.number,
                                               commodity: cost1.amount!.commodity,
                                               decimalDigits: cost1.amount!.decimalDigits).multiCurrencyAmount)
            } catch {
                XCTFail("Error thrown")
            }

            XCTAssertEqual(inventory.inventory.count, 1)
            XCTAssertEqual(inventory.inventory.first?.units, amount2)
            XCTAssertEqual(inventory.inventory.first?.cost, cost2)
        }
    }

    func testAmountDifferentCurrency() {
        for bookingMethod in bookingMethods {
            let inventory = Inventory(bookingMethod: bookingMethod)

            let amount1 = Amount(number: 2.5, commodity: commodity1, decimalDigits: 1)
            let cost1 = try! Cost(amount: Amount(number: 2.0, commodity: commodity2, decimalDigits: 1), date: nil, label: nil)
            let posting1 = Posting(accountName: accountName, amount: amount1, transaction: transaction, price: nil, cost: cost1)

            let amount2 = Amount(number: 2.0, commodity: commodity1, decimalDigits: 1)
            let cost2 = try! Cost(amount: Amount(number: 3.05, commodity: commodity1, decimalDigits: 2), date: date, label: nil)
            let posting2 = Posting(accountName: accountName, amount: amount2, transaction: transaction, price: nil, cost: cost2)

            let amount3 = Amount(number: -4.5, commodity: commodity1, decimalDigits: 2)
            let cost3 = try! Cost(amount: nil, date: nil, label: nil)
            let posting3 = Posting(accountName: accountName, amount: amount3, transaction: transaction, price: nil, cost: cost3)

            do {
                let result1 = try inventory.book(posting: posting1)
                let result2 = try inventory.book(posting: posting2)
                let result3 = try inventory.book(posting: posting3)
                XCTAssertNil(result1)
                XCTAssertNil(result2)
                XCTAssertEqual(result3, MultiCurrencyAmount(amounts: [commodity1: -6.10, commodity2: -5.0], decimalDigits: [commodity1: 2, commodity2: 1]))
            } catch {
                XCTFail("Error thrown")
            }

            XCTAssertEqual(inventory.inventory.count, 0)
        }
    }
}

extension InventoryTests { // Inventory.Lot Tests

    func testLotDescription() {
        let amount = Amount(number: -2.0, commodity: commodity1, decimalDigits: 1)
        let cost = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: nil, label: nil)
        let lot = Inventory.Lot(units: amount, cost: cost)
        XCTAssertEqual(String(describing: lot), "\(amount) \(cost)")
    }

    func testLotEqual() {
        let amount = Amount(number: -2.0, commodity: commodity1, decimalDigits: 1)
        let cost = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: nil, label: nil)
        let lot1 = Inventory.Lot(units: amount, cost: cost)
        let lot2 = Inventory.Lot(units: amount, cost: cost)
        XCTAssertTrue(lot1 == lot2)
    }

    func testLotEqualRespectsAmount() {
        let amount1 = Amount(number: -2.0, commodity: commodity1, decimalDigits: 1)
        let amount2 = Amount(number: -2.0, commodity: commodity1, decimalDigits: 2)
        let cost = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: nil, label: nil)
        let lot1 = Inventory.Lot(units: amount1, cost: cost)
        let lot2 = Inventory.Lot(units: amount2, cost: cost)
        XCTAssertFalse(lot1 == lot2)
    }

    func testLotEqualRespectsCost() {
        let amount = Amount(number: -2.0, commodity: commodity1, decimalDigits: 1)
        let cost1 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 2), date: nil, label: nil)
        let cost2 = try! Cost(amount: Amount(number: 3.0, commodity: commodity2, decimalDigits: 1), date: nil, label: nil)
        let lot1 = Inventory.Lot(units: amount, cost: cost1)
        let lot2 = Inventory.Lot(units: amount, cost: cost2)
        XCTAssertFalse(lot1 == lot2)
    }

}

extension InventoryTests { // BookingMethod tests

    func testBookingMethodDescription() {
        XCTAssertEqual(String(describing: BookingMethod.fifo), "FIFO")
        XCTAssertEqual(String(describing: BookingMethod.lifo), "LIFO")
        XCTAssertEqual(String(describing: BookingMethod.strict), "STRICT")
    }

}
