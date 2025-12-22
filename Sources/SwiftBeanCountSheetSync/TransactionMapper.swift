//
//  TransactionMapper.swift
//  SwiftBeanCountSheetSync
//
//  Created by Steffen Koette on 2020-12-05.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import SwiftBeanCountModel

enum TransactionMapper {

    static func mapDataToTransactions(_ data: [SheetParser.TransactionData], ledgerSettings: LedgerSettings) -> [Transaction] {
        data.map { convertToTransaction($0, ledgerSettings: ledgerSettings) }
    }

    private static func convertToTransaction(_ data: SheetParser.TransactionData, ledgerSettings: LedgerSettings) -> Transaction {
        var postings = [Posting]()
        let expenseAmount = Amount(number: data.amount1, commoditySymbol: ledgerSettings.commoditySymbol, decimalDigits: 2)
        let expensePosting = Posting(accountName: ledgerSettings.categoryAccountNames[data.category] ?? LedgerSettings.fallbackAccountName, amount: expenseAmount)
        postings.append(expensePosting)

        var otherAmount: Amount
        switch data.paidBy {
        case .one:
            let paymentAmount = Amount(number: -data.amount, commoditySymbol: ledgerSettings.commoditySymbol, decimalDigits: 2)
            let paymentPosting = Posting(accountName: LedgerSettings.ownAccountName, amount: paymentAmount)
            postings.append(paymentPosting)
            otherAmount = Amount(number: data.amount2, commoditySymbol: ledgerSettings.commoditySymbol, decimalDigits: 2)
        case .two:
            otherAmount = Amount(number: -data.amount1, commoditySymbol: ledgerSettings.commoditySymbol, decimalDigits: 2)
        }
        let otherPosting = Posting(accountName: ledgerSettings.accountName, amount: otherAmount)
        postings.append(otherPosting)

        return Transaction(metaData: TransactionMetaData(date: data.date, payee: data.payee, narration: data.narration, flag: .complete, tags: [ledgerSettings.tag]),
                           postings: postings)
    }

}
