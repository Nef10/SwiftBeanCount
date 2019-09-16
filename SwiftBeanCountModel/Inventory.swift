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
}

/// Errors an inventory booking can throw
public enum InventoryError: Error {
    /// an ambiguous match when trying to reduce the inventory
    case ambiguousBooking(String)
}

extension InventoryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .ambiguousBooking(error):
            return error
        }
    }
}

/// Inventory of lots for things held at cost
class Inventory {

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
            // When have a cost without date in the posting add we need to add it, use the date from the transaction
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
            inventory[matchingLotIndex].addUnits(lot.units)
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
    /// - Returns: The price which should be used for the posting of the lot (negative of the amount paid for the units) or nil if the posting cannot be booked
    /// - Throws: InventoryError if the lot cannot be reduced (e.g. ambiguous lot match)
    private func reduce(_ lot: Lot) throws -> MultiCurrencyAmount? {
        let matches = inventory.filter { $0.units.commodity == lot.units.commodity && lot.cost.matches(cost: $0.cost) }
        let isTotalReduction = matches.reduce(Decimal()) { $0 + $1.units.number } == -lot.units.number
        if isTotalReduction {
            inventory.removeAll { $0.units.commodity == lot.units.commodity && lot.cost.matches(cost: $0.cost) }
            return matches.reduce(MultiCurrencyAmount(amounts: [:], decimalDigits: [:])) {
                $0 + Amount(number: $1.cost.amount!.number * -$1.units.number,
                            commodity: $1.cost.amount!.commodity,
                            decimalDigits: $1.cost.amount!.decimalDigits).multiCurrencyAmount
            }
        }
        if matches.count == 1 {
            let index = inventory.firstIndex { $0 == matches.first! }!
            inventory[index].removeUnits(lot.units)
            let amount = inventory[index].cost.amount!
            return Amount(number: amount.number * lot.units.number, commodity: amount.commodity, decimalDigits: amount.decimalDigits).multiCurrencyAmount
        }
        return try reduceAmbigious(lot, matches: matches)
    }

    /// Reduce a ambigious lot match based on the booking method
    ///
    /// - Parameters:
    ///   - lot: lot to reduce
    ///   - matches: matches in the inventory for the cost of the lot to reduce
    /// - Returns: The price which should be used for the posting of the lot (negative of the amount paid for the units) or nil if it cannot be booked
    /// - Throws: InventoryError, e.g. for the strict booking method
    private func reduceAmbigious(_ lot: Lot, matches: [Inventory.Lot]) throws -> MultiCurrencyAmount? {
        switch bookingMethod {
        case .strict:
            throw InventoryError.ambiguousBooking("Ambigious Booking: \(lot), matches: \(matches.map { "\($0)" }.joined(separator: "\n")), inventory: \(self)")
        }
    }

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

        /// Adds Units into the lot
        ///
        /// The max of the decimalDigits is used
        ///
        /// - Parameter amount: amount to add
        mutating func addUnits(_ amount: Amount) {
            units = Amount(number: units.number + amount.number,
                           commodity: units.commodity,
                           decimalDigits: max(units.decimalDigits, amount.decimalDigits))
        }

        /// Removes Units from the lot
        ///
        /// The max of the decimalDigits is used
        ///
        /// - Parameter amount: amount to remove
        mutating func removeUnits(_ amount: Amount) {
            units = Amount(number: units.number - amount.number,
                           commodity: units.commodity,
                           decimalDigits: max(units.decimalDigits, amount.decimalDigits))
        }

    }

}

extension Inventory: CustomStringConvertible {

    /// String with all lots
    public var description: String {
        return inventory.map { "\($0)" }.joined(separator: "\n")
    }

}

extension Inventory.Lot: CustomStringConvertible {

    /// String with units and cost
    public var description: String {
        return "\(units) \(cost)"
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
        return lhs.units == rhs.units && lhs.cost == rhs.cost
    }

}
