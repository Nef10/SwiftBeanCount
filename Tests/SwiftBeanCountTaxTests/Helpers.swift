import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountTax

func basicLedger() throws -> Ledger {
    let ledger = Ledger()
    let date = Date(timeIntervalSince1970: 1_650_013_015)

    try ledger.add(Account(name: try AccountName("Assets:Account1:A"), metaData: [MetaDataKeys.issuer: "Issuer 1", "Taxslip1": "TaxBox1"]))
    try ledger.add(Account(name: try AccountName("Assets:Account1:b"), metaData: [MetaDataKeys.issuer: "Issuer 1", "Taxslip1": "TaxBox2"]))
    try ledger.add(Account(name: try AccountName("Assets:Account2"), metaData: ["Taxslip2": "TaxBox1"]))
    try ledger.add(Account(name: try AccountName("Expenses:Tax")))
    try ledger.add(Account(name: try AccountName("Income:Gain")))

    ledger.add(Transaction(metaData: TransactionMetaData(date: date), postings: [
        Posting(accountName: try AccountName("Assets:Account1:A"), amount: Amount(number: 100, commoditySymbol: "USD")),
        Posting(accountName: try AccountName("Expenses:Tax"), amount: Amount(number: -100, commoditySymbol: "USD"))
    ]))
    ledger.add(Transaction(metaData: TransactionMetaData(date: date), postings: [
        Posting(accountName: try AccountName("Assets:Account1:b"), amount: Amount(number: 50, commoditySymbol: "USD")),
        Posting(accountName: try AccountName("Expenses:Tax"), amount: Amount(number: -50, commoditySymbol: "USD"))
    ]))
    ledger.add(Transaction(metaData: TransactionMetaData(date: date, metaData: [MetaDataKeys.year: "2021"]), postings: [
        Posting(accountName: try AccountName("Assets:Account1:A"), amount: Amount(number: 200, commoditySymbol: "EUR")),
        Posting(accountName: try AccountName("Expenses:Tax"), amount: Amount(number: -200, commoditySymbol: "EUR"))
    ]))
    ledger.add(Transaction(metaData: TransactionMetaData(date: date), postings: [
        Posting(accountName: try AccountName("Assets:Account2"), amount: Amount(number: 150, commoditySymbol: "EUR")),
        Posting(accountName: try AccountName("Expenses:Tax"), amount: Amount(number: -150, commoditySymbol: "EUR"))
    ]))

    ledger.custom.append(Custom(date: date, name: MetaDataKeys.settings, values: [MetaDataKeys.slipNames, "Taxslip1", "Taxslip2"]))
    ledger.custom.append(Custom(date: Date(timeIntervalSince1970: 1_618_477_015), name: MetaDataKeys.settings, values: [MetaDataKeys.slipNames, "Taxslip1"]))
    ledger.custom.append(Custom(date: date, name: MetaDataKeys.settings, values: [MetaDataKeys.slipCurrency, "Taxslip1", "USD"]))
    ledger.custom.append(Custom(date: date, name: MetaDataKeys.settings, values: [MetaDataKeys.slipCurrency, "Taxslip2", "EUR"]))
    ledger.custom.append(Custom(date: date.advanced(by: -20_000), name: MetaDataKeys.settings, values: [MetaDataKeys.slipCurrency, "Taxslip2", "CAD"]))

    return ledger
}

func symbolLedger() throws -> Ledger {
    let ledger = Ledger()
    let date = Date(timeIntervalSince1970: 1_650_013_015)

    try ledger.add(Account(name: try AccountName("Assets:Account1:SYM"), metaData: ["Taxslip1": "TaxBox1"]))
    try ledger.add(Account(name: try AccountName("Assets:Account1:SYMB:Acc"), metaData: ["Taxslip1": "TaxBox2"]))
    try ledger.add(Account(name: try AccountName("Assets:Account2"), metaData: ["Taxslip2": "TaxBox1", MetaDataKeys.symbol: "SYMBO", MetaDataKeys.description: "Desc"]))
    try ledger.add(Account(name: try AccountName("Expenses:Tax")))

    try ledger.add(Commodity(symbol: "SYM"))
    try ledger.add(Commodity(symbol: "SYMB", metaData: [MetaDataKeys.commodityName: "DescB"]))

    ledger.add(Transaction(metaData: TransactionMetaData(date: date), postings: [
        Posting(accountName: try AccountName("Assets:Account1:SYM"), amount: Amount(number: 100, commoditySymbol: "USD")),
        Posting(accountName: try AccountName("Expenses:Tax"), amount: Amount(number: -100, commoditySymbol: "USD"))
    ]))
    ledger.add(Transaction(metaData: TransactionMetaData(date: date), postings: [
        Posting(accountName: try AccountName("Assets:Account1:SYMB:Acc"), amount: Amount(number: 50, commoditySymbol: "USD")),
        Posting(accountName: try AccountName("Expenses:Tax"), amount: Amount(number: -50, commoditySymbol: "USD"))
    ]))
    ledger.add(Transaction(metaData: TransactionMetaData(date: date), postings: [
        Posting(accountName: try AccountName("Assets:Account2"), amount: Amount(number: 150, commoditySymbol: "EUR")),
        Posting(accountName: try AccountName("Expenses:Tax"), amount: Amount(number: -150, commoditySymbol: "EUR"))
    ]))

    ledger.custom.append(Custom(date: date, name: MetaDataKeys.settings, values: [MetaDataKeys.slipNames, "Taxslip2", "Taxslip1"]))
    ledger.custom.append(Custom(date: date, name: MetaDataKeys.settings, values: [MetaDataKeys.slipCurrency, "Taxslip1", "USD"]))
    ledger.custom.append(Custom(date: date, name: MetaDataKeys.settings, values: [MetaDataKeys.slipCurrency, "Taxslip2", "EUR"]))

    return ledger
}

func currencyLedger() throws -> Ledger {
    let ledger = Ledger()
    let date = Date(timeIntervalSince1970: 1_650_013_015)

    try ledger.add(Account(name: try AccountName("Assets:Account1"), metaData: [ "Taxslip1": "TaxBox1"]))
    try ledger.add(Account(name: try AccountName("Expenses:Tax")))
    try ledger.add(Account(name: try AccountName("Expenses:Random")))

    // correct currency
    ledger.add(Transaction(metaData: TransactionMetaData(date: date), postings: [
        Posting(accountName: try AccountName("Assets:Account1"), amount: Amount(number: 100, commoditySymbol: "USD")),
        Posting(accountName: try AccountName("Expenses:Tax"), amount: Amount(number: -100, commoditySymbol: "USD"))
    ]))
    // no conversion found
    ledger.add(Transaction(metaData: TransactionMetaData(date: date), postings: [
        Posting(accountName: try AccountName("Assets:Account1"), amount: Amount(number: 50, commoditySymbol: "JPY")),
        Posting(accountName: try AccountName("Expenses:Tax"), amount: Amount(number: -50, commoditySymbol: "JPY"))
    ]))
    // price exists
    ledger.add(Transaction(metaData: TransactionMetaData(date: date), postings: [
        Posting(accountName: try AccountName("Assets:Account1"), amount: Amount(number: 200, commoditySymbol: "EUR"), price: Amount(number: 1.75, commoditySymbol: "USD")),
        Posting(accountName: try AccountName("Expenses:Tax"), amount: Amount(number: -350, commoditySymbol: "USD"))
    ]))
    // price on other posting exists
    ledger.add(Transaction(metaData: TransactionMetaData(date: date), postings: [
        Posting(accountName: try AccountName("Assets:Account1"), amount: Amount(number: 150, commoditySymbol: "CAD")),
        Posting(accountName: try AccountName("Expenses:Tax"), amount: Amount(number: -187.50, commoditySymbol: "USD"), price: Amount(number: 0.8, commoditySymbol: "CAD"))
    ]))

    ledger.custom.append(Custom(date: date, name: MetaDataKeys.settings, values: [MetaDataKeys.slipNames, "Taxslip1"]))
    ledger.custom.append(Custom(date: date, name: MetaDataKeys.settings, values: [MetaDataKeys.slipCurrency, "Taxslip1", "USD"]))
    return ledger
}

func splitAccountLedger() throws -> Ledger {
    let ledger = Ledger()
    let date = Date(timeIntervalSince1970: 1_650_013_015)

    try ledger.add(Account(name: try AccountName("Assets:Account1:A"), metaData: [MetaDataKeys.issuer: "Issuer 1", "Taxslip1": "TaxBox1"]))
    try ledger.add(Account(name: try AccountName("Assets:Account1:b"), metaData: [MetaDataKeys.issuer: "Issuer 1", "Taxslip1": "TaxBox2"]))
    try ledger.add(Account(name: try AccountName("Assets:Account2"), metaData: ["Taxslip2": "TaxBox1"]))
    try ledger.add(Account(name: try AccountName("Expenses:Tax")))
    try ledger.add(Account(name: try AccountName("Expenses:Other")))

    ledger.add(Transaction(metaData: TransactionMetaData(date: date), postings: [
        Posting(accountName: try AccountName("Assets:Account1:A"), amount: Amount(number: 100, commoditySymbol: "USD")),
        Posting(accountName: try AccountName("Expenses:Tax"), amount: Amount(number: -100, commoditySymbol: "USD"))
    ]))
    ledger.add(Transaction(metaData: TransactionMetaData(date: date), postings: [
        Posting(accountName: try AccountName("Assets:Account1:A"), amount: Amount(number: 28, commoditySymbol: "USD")),
        Posting(accountName: try AccountName("Assets:Account1:b"), amount: Amount(number: 50, commoditySymbol: "USD")),
        Posting(accountName: try AccountName("Expenses:Tax"), amount: Amount(number: -12, commoditySymbol: "USD")),
        Posting(accountName: try AccountName("Expenses:Other"), amount: Amount(number: -66, commoditySymbol: "USD"))
    ]))
    ledger.add(Transaction(metaData: TransactionMetaData(date: date), postings: [
        Posting(accountName: try AccountName("Assets:Account2"), amount: Amount(number: 150, commoditySymbol: "EUR")),
        Posting(accountName: try AccountName("Expenses:Tax"), amount: Amount(number: -150, commoditySymbol: "EUR"))
    ]))

    ledger.custom.append(Custom(date: date, name: MetaDataKeys.settings, values: [MetaDataKeys.slipNames, "Taxslip1", "Taxslip2"]))
    ledger.custom.append(Custom(date: date, name: MetaDataKeys.settings, values: [MetaDataKeys.slipCurrency, "Taxslip1", "USD"]))
    ledger.custom.append(Custom(date: date, name: MetaDataKeys.settings, values: [MetaDataKeys.slipCurrency, "Taxslip2", "EUR"]))
    ledger.custom.append(Custom(date: date, name: MetaDataKeys.settings, values: [MetaDataKeys.account, "Taxslip1", "SplitBox3", "Expenses:Tax"]))

    return ledger
}
