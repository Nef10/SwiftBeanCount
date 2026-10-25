import Foundation
import RitualDownloader
import SwiftBeanCountModel
import SwiftBeanCountParser
import Testing

@testable import SwiftBeanCountRitualMapper

private struct FundingCase {
    let vouchers: [String]
    let company: Decimal
    let bonus: Decimal
}

private func ledgerWithRoles() -> Ledger {
    Parser.parse(
        string: """
            2020-01-01 open Expenses:Food:TakeOut CAD
              ritual-role: "expense"
            2020-01-01 open Income:Work:Benefit CAD
              ritual-role: "company-benefit"
            2020-01-01 open Income:Rewards CAD
              ritual-role: "bonus-program"
            """
    )
}

private func receipt(
    vouchers: [String] = ["10.00", "5.00"],
    credits: String = "2.00",
    paid: String = "6.00",
    status: String? = "Order Completed",
    merchantName: String = "Test Café",
    totals customTotals: [RitualTotalsLine] = []
)
    throws -> RitualReceipt {
    var totals = [RitualTotalsLine(label: "Subtotal", amount: "22.00"), RitualTotalsLine(label: "Tax", amount: "1.00")]
    totals += vouchers.map { RitualTotalsLine(label: "Voucher", amount: "-" + $0) }
    totals += [RitualTotalsLine(label: "Credits Applied", amount: "-" + credits), RitualTotalsLine(label: "Total", amount: paid)]
    return try RitualReceipt(
        receiptID: String(repeating: "a", count: 32),
        dateTime: "Oct. 7, 2026 | 12:30 PM",
        merchantName: merchantName,
        status: status,
        items: [
            RitualReceiptItem(quantity: 2, itemName: " 6) MANGO CALIFORNIA ROLL [GF] ", price: "13.00", variants: ["Extra sauce"]),
            RitualReceiptItem(quantity: 1, itemName: " Hawaiian - Personal 10\" ", price: "9.00")
        ],
        totals: customTotals.isEmpty ? totals : customTotals
    )
}

@Suite
struct SwiftBeanCountRitualMapperTests {
    @Test
    func fullReceiptFallbackPaymentAndNarration() throws {
        let ledger = ledgerWithRoles()
        let mapped = try #require(SwiftBeanCountRitualMapper(ledger: ledger).map([receipt()]).first)
        let transaction = mapped.transaction
        #expect(mapped.possibleDuplicate == nil)
        #expect(transaction.metaData.narration == "2 × Mango California Roll; Hawaiian - Personal")
        #expect(transaction.metaData.payee == "Test Café")
        #expect(transaction.metaData.metaData["ritual-ordered-at"] == nil)
        #expect(transaction.postings.map(\.amount.number) == [23, -6, -10, -7])
        #expect(transaction.postings[1].accountName.fullName == "Assets:TODO")
        #expect(try transaction.balance(in: ledger).isZeroWithTolerance())
        let reparsed = Parser.parse(string: transaction.description)
        #expect(reparsed.parsingErrors.isEmpty)
        #expect(reparsed.transactions.first?.metaData.narration == transaction.metaData.narration)
    }

    @Test
    func matchedBankDataAndSharedPostingsArePreserved() throws { // swiftlint:disable:this function_body_length
        let ledger = ledgerWithRoles()
        let date = Calendar.current.date(from: DateComponents(year: 2_026, month: 10, day: 8))!
        let bank = Transaction(
            metaData: TransactionMetaData(
                date: date,
                payee: "TEST CAFE",
                narration: "Lunch with colleague",
                flag: .incomplete,
                tags: [Tag(name: "SharedExpenses")],
                metaData: ["bank-id": "original"]
            ),
            postings: [
                Posting(
                    accountName: try AccountName("Liabilities:CreditCard:Bank"),
                    amount: Amount(number: -6, commoditySymbol: "CAD", decimalDigits: 2),
                    metaData: ["payment-note": "preserve"]
                ),
                Posting(
                    accountName: try AccountName("Expenses:Food:EatingOut"),
                    amount: Amount(number: 4, commoditySymbol: "CAD", decimalDigits: 2),
                    metaData: ["expense-note": "preserve"]
                ),
                Posting(accountName: try AccountName("Assets:Receivables:Friend"), amount: Amount(number: 2, commoditySymbol: "CAD", decimalDigits: 2))
            ]
        )
        ledger.add(bank)
        let mapped = try #require(SwiftBeanCountRitualMapper(ledger: ledger).map([receipt()]).first)
        let updated = mapped.transaction
        #expect(mapped.possibleDuplicate === bank)
        #expect(updated.metaData.date == bank.metaData.date)
        #expect(updated.metaData.flag == .incomplete)
        #expect(updated.metaData.tags == bank.metaData.tags)
        #expect(updated.metaData.metaData["bank-id"] == "original")
        #expect(updated.metaData.metaData["ritual-original-narration"] == "Lunch with colleague")
        #expect(updated.metaData.metaData["ritual-order-date"] == "2026-10-07")
        #expect(updated.postings[0] == bank.postings[0])
        #expect(updated.postings[2] == bank.postings[2])
        #expect(updated.postings[1].amount.number == 21)
        #expect(updated.postings[1].accountName == bank.postings[1].accountName)
        #expect(updated.postings[1].metaData == bank.postings[1].metaData)
        #expect(try updated.balance(in: ledger).isZeroWithTolerance())
        #expect(bank.postings[1].amount.number == 4)
    }

    @Test
    func oneLargestEligibleVoucherIncludingTiesAndCredits() throws {
        let ledger = ledgerWithRoles()
        let cases: [FundingCase] = [
            FundingCase(vouchers: ["10.00", "5.00"], company: 10, bonus: 7),
            FundingCase(vouchers: ["5.00", "5.00"], company: 5, bonus: 7),
            FundingCase(vouchers: ["26.00", "20.00"], company: 20, bonus: 28),
            FundingCase(vouchers: ["26.00"], company: 0, bonus: 28),
            FundingCase(vouchers: [], company: 0, bonus: 2)
        ]
        for test in cases {
            let item = try receipt(vouchers: test.vouchers)
            let subtotal = test.company + test.bonus + 6 - 1
            let totals = [RitualTotalsLine(label: "Subtotal", amount: subtotal.description)] + item.totals.dropFirst()
            let adjusted = try RitualReceipt(
                receiptID: item.receiptID,
                dateTime: "Oct. 7, 2026 | 12:30 PM",
                merchantName: item.merchantName,
                status: item.status,
                items: item.items,
                totals: Array(totals)
            )
            let result = try #require(SwiftBeanCountRitualMapper(ledger: ledger).map([adjusted]).first?.transaction)
            #expect(result.postings.first { $0.accountName.fullName == "Income:Work:Benefit" }?.amount.number ?? 0 == -test.company)
            #expect(result.postings.first { $0.accountName.fullName == "Income:Rewards" }?.amount.number ?? 0 == -test.bonus)
        }
    }

    @Test
    func alreadyImportedAndExcludedStatuses() throws {
        let ledger = ledgerWithRoles()
        let transaction = try #require(SwiftBeanCountRitualMapper(ledger: ledger).map([receipt()]).first?.transaction)
        ledger.add(transaction)
        #expect(try SwiftBeanCountRitualMapper(ledger: ledger).map([receipt()]).isEmpty)
        for status in ["Order Canceled", "Order Rejected", "Order Refunded"] {
            #expect(try SwiftBeanCountRitualMapper(ledger: ledger).map([receipt(status: status)]).isEmpty)
        }
        #expect(try SwiftBeanCountRitualMapper(ledger: ledger).knownReceiptIDs == [receipt().receiptID])
    }

    @Test
    func missingAndAmbiguousRolesOrTotalsFail() throws {
        #expect(throws: RitualMappingError.invalidRole("expense")) { try SwiftBeanCountRitualMapper(ledger: Ledger()) }
        let ledger = ledgerWithRoles()
        try ledger.add(Account(name: AccountName("Expenses:Other"), metaData: ["ritual-role": "expense"]))
        #expect(throws: RitualMappingError.invalidRole("expense")) { try SwiftBeanCountRitualMapper(ledger: ledger) }
        let valid = ledgerWithRoles()
        #expect(throws: RitualMappingError.self) { try SwiftBeanCountRitualMapper(ledger: valid).map([receipt(paid: "7.00")]) }
    }

    @Test
    func missingStatusIsRejected() throws {
        #expect(throws: RitualMappingError.invalidReceipt("Missing status")) {
            try SwiftBeanCountRitualMapper(ledger: ledgerWithRoles()).map([receipt(status: nil)])
        }
    }

    @Test
    func invalidFundingRowsAreRejected() throws { // swiftlint:disable:this function_body_length
        let cases: [([RitualTotalsLine], RitualMappingError)] = [
            (
                [
                    RitualTotalsLine(label: "Subtotal", amount: "10.00"),
                    RitualTotalsLine(label: "Total", amount: "10.00"),
                    RitualTotalsLine(label: "Total", amount: "10.00")
                ],
                .invalidReceipt("Duplicated Total")
            ),
            (
                [
                    RitualTotalsLine(label: "Subtotal", amount: "10.00"),
                    RitualTotalsLine(label: "Voucher", amount: "1.00"),
                    RitualTotalsLine(label: "Total", amount: "11.00")
                ],
                .invalidReceipt("Positive Voucher / Credit amount")
            ),
            (
                [RitualTotalsLine(label: "Subtotal", amount: nil), RitualTotalsLine(label: "Total", amount: "0.00")],
                .invalidReceipt("Amount not present")
            ),
            (
                [RitualTotalsLine(label: "Subtotal", amount: "CAD 1.00"), RitualTotalsLine(label: "Total", amount: "0.00")],
                .invalidReceipt("Invalid CAD amount")
            )
        ]
        for (totals, expectedError) in cases {
            #expect(throws: expectedError) {
                try SwiftBeanCountRitualMapper(ledger: ledgerWithRoles()).map([receipt(totals: totals)])
            }
        }
    }

    @Test
    func unsuitableBankTransactionsAreNotMatched() throws {
        let ledger = ledgerWithRoles()
        let item = try receipt()
        ledger.add(Transaction(
            metaData: TransactionMetaData(date: item.timestamp, payee: item.merchantName),
            postings: [
                Posting(accountName: try AccountName("Liabilities:Card"), amount: Amount(number: -6, commoditySymbol: "CAD", decimalDigits: 2)),
                Posting(accountName: try AccountName("Expenses:Food"), amount: Amount(number: 6, commoditySymbol: "USD", decimalDigits: 2))
            ]
        ))
        #expect(try SwiftBeanCountRitualMapper(ledger: ledger).map([item]).first?.possibleDuplicate == nil)

        let punctuationLedger = ledgerWithRoles()
        let punctuationReceipt = try receipt(merchantName: "---")
        punctuationLedger.add(Transaction(
            metaData: TransactionMetaData(date: punctuationReceipt.timestamp, payee: "---"),
            postings: [
                Posting(accountName: try AccountName("Liabilities:Card"), amount: Amount(number: -6, commoditySymbol: "CAD", decimalDigits: 2)),
                Posting(accountName: try AccountName("Expenses:Food"), amount: Amount(number: 6, commoditySymbol: "CAD", decimalDigits: 2))
            ]
        ))
        #expect(try SwiftBeanCountRitualMapper(ledger: punctuationLedger).map([punctuationReceipt]).first?.possibleDuplicate == nil)
    }

    @Test
    func ambiguousBankPaymentsReturnsNilInsteadOfChoosingOne() throws {
        let ledger = ledgerWithRoles()
        let first = try #require(SwiftBeanCountRitualMapper(ledger: ledger).map([receipt()]).first?.transaction)
        let bankHeader = TransactionMetaData(date: first.metaData.date, payee: first.metaData.payee)
        let postings = [
            Posting(accountName: try AccountName("Liabilities:CreditCard:Bank"), amount: Amount(number: -6, commoditySymbol: "CAD", decimalDigits: 2)),
            Posting(accountName: try AccountName("Expenses:Food:TakeOut"), amount: Amount(number: 6, commoditySymbol: "CAD", decimalDigits: 2))
        ]
        ledger.add(Transaction(metaData: bankHeader, postings: postings))
        ledger.add(Transaction(metaData: bankHeader, postings: postings))
        #expect(try SwiftBeanCountRitualMapper(ledger: ledger).map([receipt()]).first!.possibleDuplicate == nil)
    }

    @Test
    func outputUsesPreservedBankDateForOrdering() throws {
        let ledger = ledgerWithRoles()
        let first = try receipt()
        let bankDate = Calendar.current.date(from: DateComponents(year: 2_026, month: 10, day: 8))!
        ledger.add(Transaction(
            metaData: TransactionMetaData(date: bankDate, payee: first.merchantName),
            postings: [
                Posting(accountName: try AccountName("Liabilities:Card"), amount: Amount(number: -6, commoditySymbol: "CAD", decimalDigits: 2)),
                Posting(accountName: try AccountName("Expenses:Food:TakeOut"), amount: Amount(number: 6, commoditySymbol: "CAD", decimalDigits: 2))
            ]
        ))
        let other = try RitualReceipt(
            receiptID: String(repeating: "b", count: 32),
            dateTime: "Oct. 7, 2026",
            merchantName: "Other Cafe",
            status: first.status,
            items: first.items,
            totals: first.totals
        )
        let output = try SwiftBeanCountRitualMapper(ledger: ledger).map([first, other])
        #expect(output.map { $0.transaction.metaData.metaData["ritual-id"] } == [other.receiptID, first.receiptID])
        #expect(output.last?.transaction.metaData.date == bankDate)
    }

    @Test(arguments: [
        "Would you like a take-away bag?", "DO YOU NEED A TAKEOUT BAG?", "Would you like a paper bag", "Add a bag?",
        "Do you need cutlery?", "Would you like utensils?", "Napkins?", "6) Would you like a take-away bag?"
    ])
    func packagingPromptsAreOmittedFromNarration(_ prompt: String) throws {
        let items = [
            RitualReceiptItem(quantity: 1, itemName: prompt, price: "0.25"),
            RitualReceiptItem(quantity: 2, itemName: "Soup", price: "10.00"),
            RitualReceiptItem(quantity: 1, itemName: prompt, price: "0.00"),
            RitualReceiptItem(quantity: 1, itemName: "Cake", price: "5.00"),
            RitualReceiptItem(quantity: 1, itemName: prompt, price: "0.00")
        ]
        #expect(try RitualDescription.narration(items: items) == "2 × Soup; Cake")
        #expect(try RitualDescription.narration(items: [items[0]]).isEmpty)
    }

    @Test
    func foodNamesAndPurchasedBagItemsRemainInNarration() throws {
        let items = [
            RitualReceiptItem(quantity: 1, itemName: "Bagel", price: "3.00"),
            RitualReceiptItem(quantity: 1, itemName: "Would you like a bagel?", price: "3.00"),
            RitualReceiptItem(quantity: 1, itemName: "Bag of chips", price: "2.00")
        ]
        #expect(try RitualDescription.narration(items: items) == "Bagel; Would you like a bagel?; Bag of chips")
    }

    @Test(arguments: [
        (" Pizza - Medium - 12\" ", "Pizza - Medium"), ("12\" Medium Hawaiian", "Medium Hawaiian"), (" Cake [GF];  Pie ", "Cake; Pie"),
        ("BUILD A SALAD BOWL", "Build A Salad Bowl"), ("Combo - Lunch", "Combo - Lunch"),
        (" Cake (GF); Pie [GF] ", "Cake; Pie"), ("(GF) Cake", "Cake"), ("Cake(GF)", "Cake"), ("Soup (Hot)", "Soup (Hot)"),
        (" Pizza (delivery) ", "Pizza"), ("( Delivery) Cake", "Cake"), ("Pizza(DELIVERY ) Large", "Pizza Large"),
        ("Soup [GF] ( Delivery) (GF) Special", "Soup Special"), ("Soup (Delivery options)", "Soup (Delivery options)"),
        (" Pizza (feeds 1-2) ", "Pizza"), ("Soup (Feeds 2) Large", "Soup Large"), ("Platter ( FEEDS 1 – 2 )", "Platter"),
        ("Platter [GF] (delivery) (feeds 1 - 2) Special", "Platter Special"), ("Soup (feeds on demand)", "Soup (feeds on demand)"),
        ("Chicken -  Ritual COMBO", "Chicken Combo"), ("CHICKEN - RITUAL COMBO", "Chicken Combo"),
        ("Chicken - ritual combo (GF)", "Chicken Combo"), (" -  Ritual COMBO", "Combo")
    ])
    func descriptionRules(_ value: (String, String)) throws {
        #expect(try RitualDescription.narration(items: [RitualReceiptItem(quantity: 1, itemName: value.0, price: "3.00")]) == value.1)
    }
}
