import Foundation
import SwiftBeanCountModel

extension Amount {

    init(for string: String, in commoditySymbol: CommoditySymbol, negate: Bool = false, inverse: Bool = false) {
        var (number, decimalDigits) = string.amountDecimal()
        if negate {
            number = -number
        }
        if inverse {
            number = 1 / number
        }
        // Wealthsimple cuts of an ending 0 in the second digit. However, all amounts we deal with have at least 2 digits
        self.init(number: number, commoditySymbol: commoditySymbol, decimalDigits: max(2, decimalDigits))
    }

}
