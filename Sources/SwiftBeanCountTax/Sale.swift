import Foundation
import SwiftBeanCountModel

/// A sale of a security
public struct Sale {
    /// The date of the sale
    public let date: Date
    /// The symbol of the security
    public let symbol: String
    /// The name of the security
    public let name: String?
    /// The quantity of the security sold
    public let quantity: Decimal
    /// The proceeds of the sale
    public let proceeds: MultiCurrencyAmount
    /// The gain of the sale
    public let gain: MultiCurrencyAmount
    /// The provider of the sale, from the account meta data
    public let provider: String
}

extension Sale: CustomStringConvertible {

    var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }

    public var description: String {
        "\(dateFormatter.string(from: date)) \(symbol) \(quantity) \(name ?? "") \(proceeds.fullString) \(gain.fullString)"
    }
}

extension MultiCurrencyAmount {
    /// String which lists the absolut value of each amount in the MultiCurrencyAmount, separated by +
    ///
    /// E.g. 10.00 CAD + 15.22 USD
    public var fullString: String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2

        return amounts.map { "\(formatter.string(for: $0.value)!) \($0.key)" }.joined(separator: " + ")
    }
}
