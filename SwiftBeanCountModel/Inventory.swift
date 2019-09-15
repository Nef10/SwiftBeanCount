//
//  Inventory.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2019-09-14.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation

public enum BookingMethod {
    case strict
}

class Inventory {

    let bookingMethod: BookingMethod

    private(set) var inventory = [Entry]()

    init(bookingMethod: BookingMethod) {
        self.bookingMethod = bookingMethod
    }

    func book(posting: Posting) {
        guard let cost = posting.cost else {
            assertionFailure("Trying to book a posting without cost")
            return
        }
        let entry = Entry(units: posting.amount, cost: cost)
        let existingEntryForCommodity = inventory.first { $0.units.commodity == entry.units.commodity }
        // inventories can either have all positive or all negative entries
        if !(existingEntryForCommodity != nil) || existingEntryForCommodity?.units.number.sign == entry.units.number.sign {
            add(entry)
        } else {
            reduce(entry)
        }
    }

    private func add(_ entry: Entry) {
        if let matchingEntryIndex = inventory.firstIndex(where: { $0.units.commodity == entry.units.commodity && $0.cost == entry.cost }) {
            inventory[matchingEntryIndex].addUnits(entry.units)
        } else {
            inventory.append(entry)
        }
    }

    private func reduce(_ entry: Entry) {
        switch bookingMethod {
        case .strict:
            // TODO
            return
        }
    }

    struct Entry {

        private(set) var units: Amount

        let cost: Cost

        init(units: Amount, cost: Cost) {
            self.units = units
            self.cost = cost
        }

        mutating func addUnits(_ amount: Amount) {
            units = Amount(number: units.number + amount.number,
                           commodity: units.commodity,
                           decimalDigits: max(units.decimalDigits, amount.decimalDigits))
        }

    }

}
