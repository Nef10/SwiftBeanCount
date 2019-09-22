//
//  Inventory.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2019-09-14.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation

/// The Booking Method for an Inventory defines how ambiguous lot matches are handled
public enum BookingMethod {
    /// throw error for ambiguous matches
    case strict
    /// last in first out
    case lifo
    /// first in first out
    case fifo
}

/// Errors an inventory booking can throw
public enum InventoryError: Error {
    /// an ambiguous match when trying to reduce the inventory
    case ambiguousBooking(String)
    /// trying to reduce a lot by more units than it has
    case lotNotBigEnough(String)
    /// no matching lot to reduce was found
    case noLotFound(String)
}

/// Inventory of lots for things held at cost
class Inventory {

    /// Lot, one entry in the inventory
    struct Lot {

        /// units in this lot, including commodity
        private(set) var units: Amount

        /// Cost of the lot
        let cost: Cost

        /// Creates a lot
        ///
        /// - Parameters:
        ///   - units: units in the lot
        ///   - cost: cost if the lot
        init(units: Amount, cost: Cost) {
            self.units = units
            self.cost = cost
        }

        /// Adjusts the units in the lot
        ///
        /// The max of the decimalDigits is used
        ///
        /// - Parameter amount: amount to add
        mutating func adjustUnits(_ amount: Amount) {
            units = Amount(number: units.number + amount.number,
                           commodity: units.commodity,
                           decimalDigits: max(units.decimalDigits, amount.decimalDigits))
        }

    }

    /// `BookingMethod` used for the Inventory
    let bookingMethod: BookingMethod

    /// Array with all lots
    private(set) var inventory = [Lot]()

    /// Creates a new Inventory
    ///
    /// - Parameter bookingMethod: booking method for the inventory
    init(bookingMethod: BookingMethod) {
        self.bookingMethod = bookingMethod
    }

    /// Books a posting in the inventory
    ///
    /// - Parameter posting: posting to book
    /// - Returns: The price which should be used for the posting (negative of the amount paid for the units) or nil if the posting is the buy or cannot be booked
    /// - Throws: InventoryError if the posting cannot be booked (e.g. ambiguous lot match)
    func book(posting: Posting) throws -> MultiCurrencyAmount? {
        guard let cost = posting.cost else {
            assertionFailure("Trying to book a posting without cost")
            return nil
        }
        let existingLotForCommodity = inventory.first { $0.units.commodity == posting.amount.commodity }
        // inventories can either have all positive or all negative lots
        if !(existingLotForCommodity != nil) || existingLotForCommodity?.units.number.sign == posting.amount.number.sign {
            // When we have a cost without date in the posting and we need to add it, use the date from the transaction
            let lot = Lot(units: posting.amount,
                          cost: try Cost(amount: cost.amount, date: cost.date != nil ? cost.date : posting.transaction.metaData.date, label: cost.label))
            add(lot)
        } else {
            let lot = Lot(units: posting.amount, cost: cost)
            return try reduce(lot)
        }
        return nil
    }

    /// Adds a lot to the inventory
    ///
    /// Adding means that the lot has the same sign as the existing units of the same commodity in the inventory,
    /// the sign of the units in the lot can be negative
    ///
    /// - Parameter lot: lot to add
    private func add(_ lot: Lot) {
        if let matchingLotIndex = inventory.firstIndex(where: { $0.units.commodity == lot.units.commodity && $0.cost == lot.cost }) {
            inventory[matchingLotIndex].adjustUnits(lot.units)
        } else {
            inventory.append(lot)
        }
    }

    /// Reduces the inventory
    ///
    /// Reducing means the that lot has a different sign than the existing units of the same commodity in the inventory,
    /// the sign of the units in the lot can be positive
    ///
    /// - Parameter lot: lot to reduce
    /// - Returns: The price which should be used for the posting of the lot (negative of the amount paid for the units)
    /// - Throws: InventoryError if the lot cannot be reduced (e.g. ambiguous lot match)
    private func reduce(_ lot: Lot) throws -> MultiCurrencyAmount {
        let matches = inventory.indices.filter { inventory[$0].units.commodity == lot.units.commodity && lot.cost.matches(cost: inventory[$0].cost) }
        let isTotalReduction = matches.reduce(Decimal()) { $0 + inventory[$1].units.number } == -lot.units.number
        if isTotalReduction {
            let result = matches.reduce(MultiCurrencyAmount(amounts: [:], decimalDigits: [:])) {
                $0 + Amount(number: inventory[$1].cost.amount!.number * -inventory[$1].units.number,
                            commodity: inventory[$1].cost.amount!.commodity,
                            decimalDigits: inventory[$1].cost.amount!.decimalDigits).multiCurrencyAmount
            }
            inventory.removeAll { $0.units.commodity == lot.units.commodity && lot.cost.matches(cost: $0.cost) }
            return result
        }
        if matches.count == 1 {
            let index = matches.first!
            guard abs(lot.units.number) < abs(inventory[index].units.number) else {
                throw InventoryError.lotNotBigEnough("Lot not big enough: Trying to reduce \(inventory[index]) by \(lot)")
            }
            inventory[index].adjustUnits(lot.units)
            let amount = inventory[index].cost.amount!
            return Amount(number: amount.number * lot.units.number, commodity: amount.commodity, decimalDigits: amount.decimalDigits).multiCurrencyAmount
        } else if matches.isEmpty {
            throw InventoryError.noLotFound("No Lot matching \(lot) found, inventory: \(self)")
        }
        return try reduceAmbigious(lot, matches: matches)
    }

    /// Reduce a ambigious lot match based on the booking method
    ///
    /// - Parameters:
    ///   - lot: lot to reduce
    ///   - matches: indices of matches in the inventory for the cost of the lot to reduce
    /// - Returns: The price which should be used for the posting of the lot (negative of the amount paid for the units)
    /// - Throws: InventoryError, e.g. for the strict booking method
    private func reduceAmbigious(_ lot: Lot, matches: [Int]) throws -> MultiCurrencyAmount {
        switch bookingMethod {
        case .strict:
            throw InventoryError.ambiguousBooking("Ambigious Booking: \(lot), matches: \(matches.map { "\(inventory[$0])" }.joined(separator: "\n")), inventory: \(self)")
        case .lifo:
            let matches = matches.sorted(by: > )
            return try reduceAmbigious(lot, fromMatchesInOrder: matches)
        case .fifo:
            let matches = matches.sorted(by: < )
            return try reduceAmbigious(lot, fromMatchesInOrder: matches)
        }
    }

    /// Reduce a ambigious lot match by going through the matches in the supplied order
    ///
    /// - Parameters:
    ///   - lot: lot to reduce
    ///   - matches: indices of the matches which should be reduced
    /// - Returns: The price which should be used for the posting of the lot (negative of the amount paid for the units)
    /// - Throws: InventoryError, e.g. if not enough units exist in the inventory
    private func reduceAmbigious(_ lot: Lot, fromMatchesInOrder matches: [Int]) throws -> MultiCurrencyAmount {
        var matches = matches
        var toRemove = [Int]()
        var number = lot.units.number
        var cost = MultiCurrencyAmount(amounts: [:], decimalDigits: [:])
        while number != 0 && !matches.isEmpty {
            if abs(inventory[matches.first!].units.number) > abs(number) {
                inventory[matches.first!].adjustUnits(Amount(number: number, commodity: lot.units.commodity, decimalDigits: lot.units.decimalDigits))
                cost += Amount(number: inventory[matches.first!].cost.amount!.number * number,
                               commodity: inventory[matches.first!].cost.amount!.commodity,
                               decimalDigits: inventory[matches.first!].cost.amount!.decimalDigits)
                number = 0
            } else {
                number += inventory[matches.first!].units.number
                cost += Amount(number: inventory[matches.first!].cost.amount!.number * inventory[matches.first!].units.number * -1,
                               commodity: inventory[matches.first!].cost.amount!.commodity,
                               decimalDigits: inventory[matches.first!].cost.amount!.decimalDigits)
                toRemove.append(matches.first!)
                matches.removeFirst()
            }
        }
        for index in toRemove.sorted(by: > ) {
            inventory.remove(at: index)
        }
        if number == 0 {
            return cost
        } else {
            throw InventoryError.lotNotBigEnough("Not enough units: Trying to reduce by \(lot)")
        }
    }

}

extension InventoryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .ambiguousBooking(error), let .lotNotBigEnough(error), let .noLotFound(error):
            return error
        }
    }
}

extension BookingMethod: CustomStringConvertible {
    public var description: String {
        switch self {
        case .strict:
            return "STRICT"
        case .lifo:
            return "LIFO"
        case .fifo:
            return "FIFO"
        }
    }
}

extension Inventory: CustomStringConvertible {

    /// String with all lots
    public var description: String {
        inventory.map { "\($0)" }.joined(separator: "\n")
    }

}

extension Inventory.Lot: CustomStringConvertible {

    /// String with units and cost
    public var description: String {
        "\(units) \(cost)"
    }

}

extension Inventory.Lot: Equatable {

    /// Retuns if the two lots are equal
    ///
    /// - Parameters:
    ///   - lhs: Lot 1
    ///   - rhs: Lot 2
    /// - Returns: true if the units and cost is the same, false otherwise
    public static func == (lhs: Inventory.Lot, rhs: Inventory.Lot) -> Bool {
        lhs.units == rhs.units && lhs.cost == rhs.cost
    }

}
