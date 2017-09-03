//
//  Amount.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-21.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

public struct Amount {

    public let number: Decimal
    public let commodity: Commodity
    public let decimalDigits: Int

    public init(number: Decimal, commodity: Commodity, decimalDigits: Int = 0) {
        self.number = number
        self.commodity = commodity
        self.decimalDigits = decimalDigits
    }
}

extension Amount : CustomStringConvertible {

    public var description: String { return "\(amountString) \(commodity)" }

    private var amountString: String { return type(of: self).numberFormatter(fractionDigits: decimalDigits).string(from:number as NSDecimalNumber)! }

    static private let numberFormatter: NumberFormatter = {
        let _formatter = NumberFormatter()
        _formatter.numberStyle = .decimal
        _formatter.minimumFractionDigits = 2
        _formatter.maximumFractionDigits = 100
        return _formatter
    }()

    static private func numberFormatter(fractionDigits: Int) -> NumberFormatter {
        let numberFormatter = self.numberFormatter
        numberFormatter.maximumFractionDigits = fractionDigits
        numberFormatter.minimumFractionDigits = fractionDigits
        return numberFormatter
    }

}

extension Amount : MultiCurrencyAmountRepresentable {
    public var multiAccountAmount: MultiCurrencyAmount {
        return MultiCurrencyAmount(amounts: [commodity: number], decimalDigits: [commodity: decimalDigits])
    }
}

extension Amount : Equatable {
    public static func == (lhs: Amount, rhs: Amount) -> Bool {
        return lhs.number == rhs.number && lhs.commodity == rhs.commodity && lhs.decimalDigits == rhs.decimalDigits
    }
}
