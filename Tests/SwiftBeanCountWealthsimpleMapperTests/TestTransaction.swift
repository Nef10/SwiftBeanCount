import Foundation
import SwiftBeanCountModel
import Wealthsimple

struct TestAsset: Asset {
    var name: String = ""
    var currency: String = ""
    var symbol = ""
    var type: AssetType = .currency
}

struct TestPositon: Position {
    var accountId = ""
    var asset: Asset = TestAsset()
    var priceAmount = ""
    var positionDate = Date()
    var priceCurrency = ""
    var quantity = ""

    var assetSymbol: String {
        get {
            asset.symbol
        }
        set {
            var newAsset = TestAsset(from: asset)
            newAsset.symbol = newValue
            asset = newAsset
        }
    }

    var assetType: AssetType {
        get {
            asset.type
        }
        set {
            var newAsset = TestAsset(from: asset)
            newAsset.type = newValue
            asset = newAsset
        }
    }
}

struct TestTransaction: Wealthsimple.Transaction {
    var id = ""
    var accountId = ""
    var transactionType: TransactionType = .buy
    var description = ""
    var symbol = ""
    var quantity = ""
    var marketPriceAmount = ""
    var marketPriceCurrency = ""
    var marketValueAmount = ""
    var marketValueCurrency = ""
    var netCashAmount = ""
    var netCashCurrency = ""
    var fxRate = ""
    var effectiveDate = Date()
    var processDate = Date()
}

extension TestAsset {
    init(from asset: Asset) {
        name = asset.name
        currency = asset.currency
        type = asset.type
        symbol = asset.symbol
    }
}
