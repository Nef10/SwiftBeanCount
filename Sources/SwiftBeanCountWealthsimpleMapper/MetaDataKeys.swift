//
//  MetaDataKeys.swift
//  SwiftBeanCountWealthsimpleMapper
//
//  Created by Steffen Kötte on 2020-07-31.
//

/// Data in meta data used in the ledger
enum MetaData {
    ///
    static let importerType = "wealthsimple"
}

/// Keys for meta data used in the ledger
enum MetaDataKeys {

    /// Key used to save and lookup the wealthsimple transaction id of transactions in the meta data
    static let id = "wealthsimple-id"

    /// Key used to save and the wealthsimple transaction id of a merged nrwt transactions in the meta data
    static let nrwtId = "wealthsimple-id-nrwt"

    /// Key used to save the record date of a dividend on dividend transactions
    static let dividendRecordDate = "record-date"

    /// Key used to save the number of shares for which a dividend was received on dividend transactions
    static let dividendShares = "shares"

    /// Key used to save the symbol of shares for which non resident witholding tax was paid
    static let symbol = "symbol"

    /// Key used to identify wealthsimple accounts in the ledger
    static let importerType = "importer-type"

    /// Key used for wealthsimple account numbers in the ledger
    static let number = "number"

}
