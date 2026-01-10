//
//  EquatePlusImporterTests.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2024-01-21
//  Copyright © 2024 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import Testing

@Suite
struct EquatePlusImporterTests {

    // swiftlint:disable line_length
    private let fullString = "Powered by EquatePlusPlans & TradingTransactions & RecordsInformation & SupportHelpThe displayed total may differ from the sum of the parts, as values have been rounded off to 2 or 3 decimal places, depending on the currency.Last purchased5.278414 SharesPurchase price€ 69.15763Purchase dateMar. 18, 2029Collecting fundsShares purchasedShares allocatedHide purchase historyContribution datePlan cycleContribution typeStatusContribution amountAmount available to purchasePurchase datePurchased sharesDec. 31, 2023Own contributionYour contributionAllocated$ 532.20€ 363.48Jan. 1, 20242.638316Dec. 31, 2023Own contributionMatching contributionAllocated$ 223.10€ 152.37Jan. 1, 20241.105984Nov. 30, 2023Own contributionYour contributionAllocated$ 608.22€ 409.02Dec. 2, 20232.755402Nov. 30, 2023Own contributionMatching contributionAllocated$ 254.97€ 171.46Dec. 2, 20231.155072Oct. 31, 2023Own contributionYour contributionAllocated$ 7,602.80€ 1,033.56Nov. 7, 20237.928071€ 70,588.45123.654321Market price€ 67.45 as of April 25, 2028 (XETRA)€ 67.45 as of April 25, 2028 at 08:37 AM (XETRA)flatexDEGIRO Bank AGHelpYour assets are held by flatexDEGIRO Bank AGSee lessDateActivityVehicle DescriptionPurchase/Sell priceQuantityMar. 10, 2029Sell–€ 80.10105-1.000000Jan. 1, 2024MatchOwn€ 48.218711.105984Jan. 1, 2024PurchaseOwn€ 48.218712.638316Dec. 2, 2023MatchOwn€ 59.377741.155072Dec. 2, 2023PurchaseOwn€ 59.377742.7554020.001234Profile"
    private let wrongContributionDate = "Powered by EquatePlusPlans & TradingTransactions & RecordsInformation & SupportHelpThe displayed total may differ from the sum of the parts, as values have been rounded off to 2 or 3 decimal places, depending on the currency.Last purchased5.278414 SharesPurchase price€ 69.15763Purchase dateMar. 18, 2029Collecting fundsShares purchasedShares allocatedHide purchase historyContribution datePlan cycleContribution typeStatusContribution amountAmount available to purchasePurchase datePurchased sharesDec. 31, 2023Own contributionYour contributionAllocated$ 532.20€ 363.48Jan. 1, 20242.638316Dec. 31, 2023Own contributionMatching contributionAllocated$ 223.10€ 152.37Jan. 1, 20241.105984Nov. 30, 2023Own contributionYour contributionAllocated$ 608.22€ 409.02Dec. 2, 20232.755402Nov. 32, 2023Own contributionMatching contributionAllocated$ 254.97€ 171.46Dec. 2, 20231.155072Oct. 31, 2023Own contributionYour contributionAllocated$ 7,602.80€ 1,033.56Nov. 7, 20237.928071€ 70,588.45123.654321Market price€ 67.45 as of April 25, 2028 (XETRA)€ 67.45 as of April 25, 2028 at 08:37 AM (XETRA)flatexDEGIRO Bank AGHelpYour assets are held by flatexDEGIRO Bank AGSee lessDateActivityVehicle DescriptionPurchase/Sell priceQuantityMar. 10, 2029Sell–€ 80.10105-1.000000Jan. 1, 2024MatchOwn€ 48.218711.105984Jan. 1, 2024PurchaseOwn€ 48.218712.638316Dec. 2, 2023MatchOwn€ 59.377741.155072Dec. 2, 2023PurchaseOwn€ 59.377742.7554020.001234Profile"
    private let wrongPurchaseDate = "Powered by EquatePlusPlans & TradingTransactions & RecordsInformation & SupportHelpThe displayed total may differ from the sum of the parts, as values have been rounded off to 2 or 3 decimal places, depending on the currency.Last purchased5.278414 SharesPurchase price€ 69.15763Purchase dateMar. 18, 2029Collecting fundsShares purchasedShares allocatedHide purchase historyContribution datePlan cycleContribution typeStatusContribution amountAmount available to purchasePurchase datePurchased sharesDec. 31, 2023Own contributionYour contributionAllocated$ 532.20€ 363.48Jan. 1, 20242.638316Dec. 31, 2023Own contributionMatching contributionAllocated$ 223.10€ 152.37Jan. 1, 20241.105984Nov. 30, 2023Own contributionYour contributionAllocated$ 608.22€ 409.02Dec. 2, 20232.755402Nov. 30, 2023Own contributionMatching contributionAllocated$ 254.97€ 171.46Dec. 32, 20231.155072Oct. 31, 2023Own contributionYour contributionAllocated$ 7,602.80€ 1,033.56Nov. 7, 20237.928071€ 70,588.45123.654321Market price€ 67.45 as of April 25, 2028 (XETRA)€ 67.45 as of April 25, 2028 at 08:37 AM (XETRA)flatexDEGIRO Bank AGHelpYour assets are held by flatexDEGIRO Bank AGSee lessDateActivityVehicle DescriptionPurchase/Sell priceQuantityMar. 10, 2029Sell–€ 80.10105-1.000000Jan. 1, 2024MatchOwn€ 48.218711.105984Jan. 1, 2024PurchaseOwn€ 48.218712.638316Dec. 2, 2023MatchOwn€ 59.377741.155072Dec. 2, 2023PurchaseOwn€ 59.377742.7554020.001234Profile"
    private let wrongTransactionDate = "Powered by EquatePlusPlans & TradingTransactions & RecordsInformation & SupportHelpThe displayed total may differ from the sum of the parts, as values have been rounded off to 2 or 3 decimal places, depending on the currency.Last purchased5.278414 SharesPurchase price€ 69.15763Purchase dateMar. 18, 2029Collecting fundsShares purchasedShares allocatedHide purchase historyContribution datePlan cycleContribution typeStatusContribution amountAmount available to purchasePurchase datePurchased sharesDec. 31, 2023Own contributionYour contributionAllocated$ 532.20€ 363.48Jan. 1, 20242.638316Dec. 31, 2023Own contributionMatching contributionAllocated$ 223.10€ 152.37Jan. 1, 20241.105984Nov. 30, 2023Own contributionYour contributionAllocated$ 608.22€ 409.02Dec. 2, 20232.755402Nov. 30, 2023Own contributionMatching contributionAllocated$ 254.97€ 171.46Dec. 2, 20231.155072Oct. 31, 2023Own contributionYour contributionAllocated$ 7,602.80€ 1,033.56Nov. 7, 20237.928071€ 70,588.45123.654321Market price€ 67.45 as of April 25, 2028 (XETRA)€ 67.45 as of April 25, 2028 at 08:37 AM (XETRA)flatexDEGIRO Bank AGHelpYour assets are held by flatexDEGIRO Bank AGSee lessDateActivityVehicle DescriptionPurchase/Sell priceQuantityMar. 10, 2029Sell–€ 80.10105-1.000000Jan. 1, 2024MatchOwn€ 48.218711.105984Jan. 1, 2024PurchaseOwn€ 48.218712.638316Dec. 2, 2023MatchOwn€ 59.377741.155072Dec. 33, 2023PurchaseOwn€ 59.377742.7554020.001234Profile"
    private let invalidPurchaseTransactionMapping = "Powered by EquatePlusPlans & TradingTransactions & RecordsInformation & SupportHelpThe displayed total may differ from the sum of the parts, as values have been rounded off to 2 or 3 decimal places, depending on the currency.Last purchased5.278414 SharesPurchase price€ 69.15763Purchase dateMar. 18, 2029Collecting fundsShares purchasedShares allocatedHide purchase historyContribution datePlan cycleContribution typeStatusContribution amountAmount available to purchasePurchase datePurchased sharesDec. 31, 2023Own contributionYour contributionAllocated$ 532.20€ 363.48Jan. 1, 20242.638316Dec. 31, 2023Own contributionMatching contributionAllocated$ 223.10€ 152.37Jan. 1, 20241.105984Nov. 30, 2023Own contributionYour contributionAllocated$ 608.22€ 409.02Dec. 2, 20232.755402Nov. 30, 2023Own contributionMatching contributionAllocated$ 254.97€ 171.46Dec. 2, 20231.155072Oct. 31, 2023Own contributionYour contributionAllocated$ 7,602.80€ 1,033.56Nov. 7, 20237.928071€ 70,588.45123.654321Market price€ 67.45 as of April 25, 2028 (XETRA)€ 67.45 as of April 25, 2028 at 08:37 AM (XETRA)flatexDEGIRO Bank AGHelpYour assets are held by flatexDEGIRO Bank AGSee lessDateActivityVehicle DescriptionPurchase/Sell priceQuantityMar. 10, 2029Sell–€ 80.10105-1.000000Jan. 1, 2024MatchOwn€ 48.218711.105984Jan. 1, 2024PurchaseOwn€ 48.218712.638316Dec. 2, 2023MatchOwn€ 48.218711.105984Jan. 1, 2024PurchaseOwn€ 48.218712.638316Dec. 2, 2023MatchOwn€ 59.377741.155072Dec. 2, 2023PurchaseOwn€ 59.377742.7554020.001234Profile"
    private let invalidMatchTransactionMapping = "Powered by EquatePlusPlans & TradingTransactions & RecordsInformation & SupportHelpThe displayed total may differ from the sum of the parts, as values have been rounded off to 2 or 3 decimal places, depending on the currency.Last purchased5.278414 SharesPurchase price€ 69.15763Purchase dateMar. 18, 2029Collecting fundsShares purchasedShares allocatedHide purchase historyContribution datePlan cycleContribution typeStatusContribution amountAmount available to purchasePurchase datePurchased sharesDec. 31, 2023Own contributionYour contributionAllocated$ 532.20€ 363.48Jan. 1, 20242.638316Dec. 31, 2023Own contributionMatching contributionAllocated$ 223.10€ 152.37Jan. 1, 20241.105984Nov. 30, 2023Own contributionYour contributionAllocated$ 608.22€ 409.02Dec. 2, 20232.755402Nov. 30, 2023Own contributionMatching contributionAllocated$ 254.97€ 171.46Dec. 2, 20231.155072Oct. 31, 2023Own contributionYour contributionAllocated$ 7,602.80€ 1,033.56Nov. 7, 20237.928071€ 70,588.45123.654321Market price€ 67.45 as of April 25, 2028 (XETRA)€ 67.45 as of April 25, 2028 at 08:37 AM (XETRA)flatexDEGIRO Bank AGHelpYour assets are held by flatexDEGIRO Bank AGSee lessDateActivityVehicle DescriptionPurchase/Sell priceQuantityMar. 10, 2029Sell–€ 80.10105-1.000000Jan. 1, 2024MatchOwn€ 48.218711.105984Jan. 1, 2024MatchOwn€ 48.218711.105984Jan. 1, 2024PurchaseOwn€ 48.218712.638316Dec. 2, 2023MatchOwn€ 48.218711.105984Jan. 1, 2024PurchaseOwn€ 48.218712.638316Dec. 2, 2023MatchOwn€ 59.377741.155072Dec. 2, 2023PurchaseOwn€ 59.377742.7554020.001234Profile"
    private let invalidYouContributionMapping = "Powered by EquatePlusPlans & TradingTransactions & RecordsInformation & SupportHelpThe displayed total may differ from the sum of the parts, as values have been rounded off to 2 or 3 decimal places, depending on the currency.Last purchased5.278414 SharesPurchase price€ 69.15763Purchase dateMar. 18, 2029Collecting fundsShares purchasedShares allocatedHide purchase historyContribution datePlan cycleContribution typeStatusContribution amountAmount available to purchasePurchase datePurchased sharesDec. 31, 2023Own contributionYour contributionAllocated$ 532.20€ 363.48Jan. 1, 20242.638316Jan. 1, 20241.105984Dec. 31, 2023Own contributionYour contributionAllocated$ 532.20€ 363.48Jan. 1, 20242.638316Dec. 31, 2023Own contributionMatching contributionAllocated$ 223.10€ 152.37Jan. 1, 20241.105984Nov. 30, 2023Own contributionYour contributionAllocated$ 608.22€ 409.02Dec. 2, 20232.755402Nov. 30, 2023Own contributionMatching contributionAllocated$ 254.97€ 171.46Dec. 2, 20231.155072Oct. 31, 2023Own contributionYour contributionAllocated$ 7,602.80€ 1,033.56Nov. 7, 20237.928071€ 70,588.45123.654321Market price€ 67.45 as of April 25, 2028 (XETRA)€ 67.45 as of April 25, 2028 at 08:37 AM (XETRA)flatexDEGIRO Bank AGHelpYour assets are held by flatexDEGIRO Bank AGSee lessDateActivityVehicle DescriptionPurchase/Sell priceQuantityMar. 10, 2029Sell–€ 80.10105-1.000000Jan. 1, 2024MatchOwn€ 48.218711.105984Jan. 1, 2024PurchaseOwn€ 48.218712.638316Dec. 2, 2023MatchOwn€ 59.377741.155072Dec. 2, 2023PurchaseOwn€ 59.377742.7554020.001234Profile"
    private let invalidEmployerContributionMapping = "Powered by EquatePlusPlans & TradingTransactions & RecordsInformation & SupportHelpThe displayed total may differ from the sum of the parts, as values have been rounded off to 2 or 3 decimal places, depending on the currency.Last purchased5.278414 SharesPurchase price€ 69.15763Purchase dateMar. 18, 2029Collecting fundsShares purchasedShares allocatedHide purchase historyContribution datePlan cycleContribution typeStatusContribution amountAmount available to purchasePurchase datePurchased sharesDec. 31, 2023Own contributionYour contributionAllocated$ 532.20€ 363.48Jan. 1, 20242.638316Dec. 31, 2023Own contributionMatching contributionAllocated$ 223.10€ 152.37Jan. 1, 20241.105984Dec. 31, 2023Own contributionMatching contributionAllocated$ 223.10€ 152.37Jan. 1, 20241.105984Nov. 30, 2023Own contributionYour contributionAllocated$ 608.22€ 409.02Dec. 2, 20232.755402Nov. 30, 2023Own contributionMatching contributionAllocated$ 254.97€ 171.46Dec. 2, 20231.155072Oct. 31, 2023Own contributionYour contributionAllocated$ 7,602.80€ 1,033.56Nov. 7, 20237.928071€ 70,588.45123.654321Market price€ 67.45 as of April 25, 2028 (XETRA)€ 67.45 as of April 25, 2028 at 08:37 AM (XETRA)flatexDEGIRO Bank AGHelpYour assets are held by flatexDEGIRO Bank AGSee lessDateActivityVehicle DescriptionPurchase/Sell priceQuantityMar. 10, 2029Sell–€ 80.10105-1.000000Jan. 1, 2024MatchOwn€ 48.218711.105984Jan. 1, 2024PurchaseOwn€ 48.218712.638316Dec. 2, 2023MatchOwn€ 59.377741.155072Dec. 2, 2023PurchaseOwn€ 59.377742.7554020.001234Profile"
    // swiftlint:enable line_length

    private var parkingAccountDelegate: InputProviderDelegate!

    override func setUpWithError() throws {
        parkingAccountDelegate = InputProviderDelegate(names: ["Account"], types: [.text([])], returnValues: [TestUtils.parking.fullName])
        try super.setUpWithError()
    }

   @Test
   func testImporterName() {
        #expect(EquatePlusImporter.importerName == "EquatePlus")
    }

   @Test
   func testImporterType() {
        #expect(EquatePlusImporter.importerType == "equateplus")
    }

   @Test
   func testHelpText() {
        #expect(EquatePlusImporter.helpText.contains("importer-type: \"equateplus\""))
    }

   @Test
   func testImportName() {
        #expect(loadedImporter().importName == "EquatePlus Text")
    }

   @Test
   func testBalanceImport() {
        let importer = EquatePlusImporter(ledger: nil, transaction: "", balance: "TEST")
        let delegate = ErrorDelegate(error: EquatePlusImporterError.balanceImportNotSupported("TEST"))
        importer.delegate = delegate
        importer.load()
        #expect(delegate.verified)
    }

   @Test
   func testParseEmpty() {
        let importer = loadedImporter()
        #expect(importer.nextTransaction() == nil)
        #expect(importer.balancesToImport().isEmpty)
        #expect(importer.pricesToImport().isEmpty)
    }

   @Test
   func testWrongContributionDate() {
        let importer = EquatePlusImporter(ledger: nil, transaction: wrongContributionDate, balance: "")
        let delegate = ErrorDelegate(error: EquatePlusImporterError.failedToParseDate("Nov. 32, 2023"))
        importer.delegate = delegate
        importer.load()
        #expect(delegate.verified)
    }

   @Test
   func testWrongPurchaseDate() {
        let importer = EquatePlusImporter(ledger: nil, transaction: wrongPurchaseDate, balance: "")
        let delegate = ErrorDelegate(error: EquatePlusImporterError.failedToParseDate("Dec. 32, 2023"))
        importer.delegate = delegate
        importer.load()
        #expect(delegate.verified)
    }

   @Test
   func testWrongTransactionDate() {
        let importer = EquatePlusImporter(ledger: nil, transaction: wrongTransactionDate, balance: "")
        let delegate = ErrorDelegate(error: EquatePlusImporterError.failedToParseDate("Dec. 33, 2023"))
        importer.delegate = delegate
        importer.load()
        #expect(delegate.verified)
    }

   @Test
   func testInvalidPurchaseTransactionMapping() {
        let importer = EquatePlusImporter(ledger: nil, transaction: invalidPurchaseTransactionMapping, balance: "")
        let delegate = ErrorDelegate(error: EquatePlusImporterError.invalidTransactionMapping(
            "Purchase", // swiftlint:disable:next line_length
            "EquatePlusTransaction(date: \(TestUtils.date20240101), type: SwiftBeanCountImporter.EquatePlusImporter.TransactionType.purchase, price: 48.21871 UNKNOWN, amount: 2.638316 UNKNOWN)"))
        importer.delegate = delegate
        importer.load()
        #expect(delegate.verified)
    }

   @Test
   func testInvalidMatchTransactionMapping() {
        let importer = EquatePlusImporter(ledger: nil, transaction: invalidMatchTransactionMapping, balance: "")
        let delegate = ErrorDelegate(error: EquatePlusImporterError.invalidTransactionMapping(
            "Match", // swiftlint:disable:next line_length
            "EquatePlusTransaction(date: \(TestUtils.date20240101), type: SwiftBeanCountImporter.EquatePlusImporter.TransactionType.match, price: 48.21871 UNKNOWN, amount: 1.105984 UNKNOWN)"))
        importer.delegate = delegate
        importer.load()
        #expect(delegate.verified)
    }

   @Test
   func testInvalidYouContributionMapping() {
        let importer = EquatePlusImporter(ledger: nil, transaction: invalidYouContributionMapping, balance: "")
        let delegate = ErrorDelegate(error: EquatePlusImporterError.invalidContributionMapping(
            "you", // swiftlint:disable:next line_length
            "Contribution(date: \(TestUtils.date20231231), type: SwiftBeanCountImporter.EquatePlusImporter.ContributionType.you, amount: 532.20 UNKNOWN, amountAvailable: 363.48 UNKNOWN, purchaseDate: \(TestUtils.date20240101), purchasedShares: 2.638316 UNKNOWN)"))
        importer.delegate = delegate
        importer.load()
        #expect(delegate.verified)
    }

   @Test
   func testinvalidEmployerContributionMapping() {
        let importer = EquatePlusImporter(ledger: nil, transaction: invalidEmployerContributionMapping, balance: "")
        let delegate = ErrorDelegate(error: EquatePlusImporterError.invalidContributionMapping(
            "employer", // swiftlint:disable:next line_length
            "Contribution(date: \(TestUtils.date20231231), type: SwiftBeanCountImporter.EquatePlusImporter.ContributionType.employer, amount: 223.10 UNKNOWN, amountAvailable: 152.37 UNKNOWN, purchaseDate: \(TestUtils.date20240101), purchasedShares: 1.105984 UNKNOWN)"))
        importer.delegate = delegate
        importer.load()
        #expect(delegate.verified)
    }

   @Test
   func testSuccess() { // swiftlint:disable:this function_body_length
        let importer = loadedImporter(ledger: nil, transaction: fullString, balance: "")
        let transaction1 = importer.nextTransaction()
        #expect(transaction1 != nil)
        #expect(!(transaction1!.shouldAllowUserToEdit))
        #expect(transaction1!.accountName == nil)
        #expect(transaction1!.possibleDuplicate == nil)
        #expect(transaction1!.originalDescription.isEmpty)
        let transaction2 = importer.nextTransaction()
        #expect(transaction2 != nil)
        #expect(!(transaction2!.shouldAllowUserToEdit))
        #expect(transaction2!.accountName == nil)
        #expect(transaction2!.possibleDuplicate == nil)
        #expect(transaction2!.originalDescription.isEmpty)

        let beancountTransaction1 = [transaction1!.transaction, transaction2!.transaction].first { $0.metaData.date == TestUtils.date20231202 }
        let beancountTransaction2 = [transaction1!.transaction, transaction2!.transaction].first { $0.metaData.date == TestUtils.date20240101 }
        #expect(beancountTransaction1 != nil)
        #expect(beancountTransaction2 != nil)
        #expect(beancountTransaction1!.metaData.narration.isEmpty)
        #expect(beancountTransaction1!.metaData.payee.isEmpty)
        #expect(beancountTransaction1!.metaData.flag == .complete)
        #expect(beancountTransaction1!.metaData.date == TestUtils.date20231202)
        #expect(beancountTransaction1!.postings.contains {
            $0.accountName == TestUtils.parking && $0.amount.description == "-863.19 UNKNOWN" && $0.price?.description == "-0.67 UNKNOWN"
        })
        #expect(beancountTransaction1!.postings.contains {
            $0.accountName.fullName == "Assets:Cash:UNKNOWN" && $0.amount.description == "3.910474 UNKNOWN" && $0.cost!.amount!.description == "59.37774 UNKNOWN"
        })
        #expect(beancountTransaction2!.metaData.narration.isEmpty)
        #expect(beancountTransaction2!.metaData.payee.isEmpty)
        #expect(beancountTransaction2!.metaData.flag == .complete)
        #expect(beancountTransaction2!.metaData.date == TestUtils.date20240101)
        #expect(beancountTransaction2!.postings.contains {
            $0.accountName == TestUtils.parking && $0.amount.description == "-755.30 UNKNOWN" && $0.price?.description == "-0.68 UNKNOWN"
        })
        #expect(beancountTransaction2!.postings.contains {
            $0.accountName.fullName == "Assets:Cash:UNKNOWN" && $0.amount.description == "3.744300 UNKNOWN" && $0.cost!.amount!.description == "48.21871 UNKNOWN"
        })

        #expect(importer.nextTransaction() == nil)
        #expect(importer.balancesToImport().isEmpty)
        #expect(importer.pricesToImport().isEmpty)
    }

   @Test
   func testLedgerMapping() throws {
        let ledger = Ledger()
        try ledger.add(Account(name: try AccountName("Assets:EP:Cash"), commoditySymbol: "STOCK", metaData: [
            Settings.importerTypeKey: EquatePlusImporter.importerType, "stock": "STOCK", "purchase-currency": "USD", "contribution-currency": "EUR"
        ]))
        let importer = loadedImporter(ledger: ledger, transaction: fullString, balance: "")
        let transaction1 = importer.nextTransaction()
        #expect(transaction1 != nil)
        let transaction2 = importer.nextTransaction()
        #expect(transaction2 != nil)

        let beancountTransaction1 = [transaction1!.transaction, transaction2!.transaction].first { $0.metaData.date == TestUtils.date20231202 }
        let beancountTransaction2 = [transaction1!.transaction, transaction2!.transaction].first { $0.metaData.date == TestUtils.date20240101 }
        #expect(beancountTransaction1 != nil)
        #expect(beancountTransaction2 != nil)
        print(beancountTransaction1!.postings)
        #expect(beancountTransaction1!.postings.contains {
            $0.accountName.fullName == "Assets:EP:Cash" && $0.amount.description == "-863.19 EUR" && $0.price!.description == "-0.67 USD"
        })
        #expect(beancountTransaction1!.postings.contains {
            $0.accountName.fullName == "Assets:EP:STOCK" && $0.amount.description == "3.910474 STOCK" && $0.cost!.amount!.description == "59.37774 USD"
        })
        #expect(beancountTransaction2!.postings.contains {
            $0.accountName.fullName == "Assets:EP:Cash" && $0.amount.description == "-755.30 EUR" && $0.price?.description == "-0.68 USD"
        })
        #expect(beancountTransaction2!.postings.contains {
            $0.accountName.fullName == "Assets:EP:STOCK" && $0.amount.description == "3.744300 STOCK" && $0.cost!.amount!.description == "48.21871 USD"
        })

        #expect(importer.nextTransaction() == nil)
    }

   @Test
   func testInvalidStockName() throws {
        let ledger = Ledger()
        try ledger.add(Account(name: try AccountName("Assets:EP:Cash"), commoditySymbol: "STOCK", metaData: [
            Settings.importerTypeKey: EquatePlusImporter.importerType, "stock": "TEST:", "purchase-currency": "USD", "contribution-currency": "EUR"
        ]))
        let importer = EquatePlusImporter(ledger: ledger, transaction: fullString, balance: "")
        let delegate = ErrorDelegate(error: AccountNameError.invaildName("Assets:TEST:"))
        importer.delegate = delegate
        importer.load()
        #expect(delegate.verified)
    }

   @Test
   func testErrorDescription() {
        #expect(
            EquatePlusImporterError.balanceImportNotSupported("BAL").errorDescription ==
            "This importer does not support importing balances. Trying to import: BAL"
        )
        #expect(
            EquatePlusImporterError.failedToParseDate("DATE").errorDescription ==
            "Failed to parse date: DATE"
        )
        #expect(
            EquatePlusImporterError.unknownContributionType("TYPE").errorDescription ==
            "Unknow contribution type: TYPE"
        )
        #expect(
            EquatePlusImporterError.unknownTransactionType("TYPE").errorDescription ==
            "Unknow transaction type: TYPE"
        )
        #expect(
            EquatePlusImporterError.invalidContributionMapping("TYPE", "CONT").errorDescription ==
            "Unable to map contributions correctly. Found second contribtuion for type TYPE: CONT"
        )
        #expect(
            EquatePlusImporterError.invalidTransactionMapping("TYPE", "TRANS").errorDescription ==
            "Unable to map transactions correctly. Found second transaction for type TYPE: TRANS"
        )
    }

    private func loadedImporter(ledger: Ledger? = nil, transaction: String = "", balance: String = "") -> EquatePlusImporter {
        let importer = EquatePlusImporter(ledger: ledger, transaction: transaction, balance: balance)
        importer.delegate = parkingAccountDelegate
        importer.load()
        return importer
    }
}

extension EquatePlusImporterError: EquatableError {
}

extension AccountNameError: EquatableError {
}
