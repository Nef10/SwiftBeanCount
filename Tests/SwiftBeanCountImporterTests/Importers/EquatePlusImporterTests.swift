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
import XCTest

final class EquatePlusImporterTests: XCTestCase {

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

    private var parkingAccountDelegate: InputProviderDelegate! // swiftlint:disable:this weak_delegate

    override func setUpWithError() throws {
        parkingAccountDelegate = InputProviderDelegate(names: ["Account"], types: [.text([])], returnValues: [TestUtils.parking.fullName])
        try super.setUpWithError()
    }

    func testImporterName() {
        XCTAssertEqual(EquatePlusImporter.importerName, "EquatePlus")
    }

    func testImporterType() {
        XCTAssertEqual(EquatePlusImporter.importerType, "equateplus")
    }

    func testHelpText() {
        XCTAssert(EquatePlusImporter.helpText.contains("importer-type: \"equateplus\""))
    }

    func testImportName() {
        XCTAssertEqual(loadedImporter().importName, "EquatePlus Text")
    }

    func testBalanceImport() {
        let importer = EquatePlusImporter(ledger: nil, transaction: "", balance: "TEST")
        let delegate = ErrorDelegate(error: EquatePlusImporterError.balanceImportNotSupported("TEST"))
        importer.delegate = delegate
        importer.load()
        XCTAssert(delegate.verified)
    }

    func testParseEmpty() {
        let importer = loadedImporter()
        XCTAssertNil(importer.nextTransaction())
        XCTAssertEqual(importer.balancesToImport(), [])
        XCTAssertEqual(importer.pricesToImport(), [])
    }

    func testWrongContributionDate() {
        let importer = EquatePlusImporter(ledger: nil, transaction: wrongContributionDate, balance: "")
        let delegate = ErrorDelegate(error: EquatePlusImporterError.failedToParseDate("Nov. 32, 2023"))
        importer.delegate = delegate
        importer.load()
        XCTAssert(delegate.verified)
    }

    func testWrongPurchaseDate() {
        let importer = EquatePlusImporter(ledger: nil, transaction: wrongPurchaseDate, balance: "")
        let delegate = ErrorDelegate(error: EquatePlusImporterError.failedToParseDate("Dec. 32, 2023"))
        importer.delegate = delegate
        importer.load()
        XCTAssert(delegate.verified)
    }

    func testWrongTransactionDate() {
        let importer = EquatePlusImporter(ledger: nil, transaction: wrongTransactionDate, balance: "")
        let delegate = ErrorDelegate(error: EquatePlusImporterError.failedToParseDate("Dec. 33, 2023"))
        importer.delegate = delegate
        importer.load()
        XCTAssert(delegate.verified)
    }

    func testInvalidPurchaseTransactionMapping() {
        let importer = EquatePlusImporter(ledger: nil, transaction: invalidPurchaseTransactionMapping, balance: "")
        let delegate = ErrorDelegate(error: EquatePlusImporterError.invalidTransactionMapping(
            "Purchase", // swiftlint:disable:next line_length
            "EquatePlusTransaction(date: \(TestUtils.date20240101), type: SwiftBeanCountImporter.EquatePlusImporter.TransactionType.purchase, price: 48.21871 UNKNOWN, amount: 2.638316 UNKNOWN)"))
        importer.delegate = delegate
        importer.load()
        XCTAssert(delegate.verified)
    }

    func testInvalidMatchTransactionMapping() {
        let importer = EquatePlusImporter(ledger: nil, transaction: invalidMatchTransactionMapping, balance: "")
        let delegate = ErrorDelegate(error: EquatePlusImporterError.invalidTransactionMapping(
            "Match", // swiftlint:disable:next line_length
            "EquatePlusTransaction(date: \(TestUtils.date20240101), type: SwiftBeanCountImporter.EquatePlusImporter.TransactionType.match, price: 48.21871 UNKNOWN, amount: 1.105984 UNKNOWN)"))
        importer.delegate = delegate
        importer.load()
        XCTAssert(delegate.verified)
    }

    func testInvalidYouContributionMapping() {
        let importer = EquatePlusImporter(ledger: nil, transaction: invalidYouContributionMapping, balance: "")
        let delegate = ErrorDelegate(error: EquatePlusImporterError.invalidContributionMapping(
            "you", // swiftlint:disable:next line_length
            "Contribution(date: \(TestUtils.date20231231), type: SwiftBeanCountImporter.EquatePlusImporter.ContributionType.you, amount: 532.20 UNKNOWN, amountAvailable: 363.48 UNKNOWN, purchaseDate: \(TestUtils.date20240101), purchasedShares: 2.638316 UNKNOWN)"))
        importer.delegate = delegate
        importer.load()
        XCTAssert(delegate.verified)
    }

    func testinvalidEmployerContributionMapping() {
        let importer = EquatePlusImporter(ledger: nil, transaction: invalidEmployerContributionMapping, balance: "")
        let delegate = ErrorDelegate(error: EquatePlusImporterError.invalidContributionMapping(
            "employer", // swiftlint:disable:next line_length
            "Contribution(date: \(TestUtils.date20231231), type: SwiftBeanCountImporter.EquatePlusImporter.ContributionType.employer, amount: 223.10 UNKNOWN, amountAvailable: 152.37 UNKNOWN, purchaseDate: \(TestUtils.date20240101), purchasedShares: 1.105984 UNKNOWN)"))
        importer.delegate = delegate
        importer.load()
        XCTAssert(delegate.verified)
    }

    func testSuccess() { // swiftlint:disable:this function_body_length
        let importer = loadedImporter(ledger: nil, transaction: fullString, balance: "")
        let transaction1 = importer.nextTransaction()
        XCTAssertNotNil(transaction1)
        XCTAssertFalse(transaction1!.shouldAllowUserToEdit)
        XCTAssertNil(transaction1!.accountName)
        XCTAssertNil(transaction1!.possibleDuplicate)
        XCTAssertEqual(transaction1!.originalDescription, "")
        let transaction2 = importer.nextTransaction()
        XCTAssertNotNil(transaction2)
        XCTAssertFalse(transaction2!.shouldAllowUserToEdit)
        XCTAssertNil(transaction2!.accountName)
        XCTAssertNil(transaction2!.possibleDuplicate)
        XCTAssertEqual(transaction2!.originalDescription, "")

        let beancountTransaction1 = [transaction1!.transaction, transaction2!.transaction].first { $0.metaData.date == TestUtils.date20231202 }
        let beancountTransaction2 = [transaction1!.transaction, transaction2!.transaction].first { $0.metaData.date == TestUtils.date20240101 }
        XCTAssertNotNil(beancountTransaction1)
        XCTAssertNotNil(beancountTransaction2)
        XCTAssertEqual(beancountTransaction1!.metaData.narration, "")
        XCTAssertEqual(beancountTransaction1!.metaData.payee, "")
        XCTAssertEqual(beancountTransaction1!.metaData.flag, .complete)
        XCTAssertEqual(beancountTransaction1!.metaData.date, TestUtils.date20231202)
        XCTAssert(beancountTransaction1!.postings.contains {
            $0.accountName == TestUtils.parking && $0.amount.description == "-863.19 UNKNOWN" && $0.price?.description == "-0.67 UNKNOWN"
        })
        XCTAssert(beancountTransaction1!.postings.contains {
            $0.accountName.fullName == "Assets:Cash:UNKNOWN" && $0.amount.description == "3.910474 UNKNOWN" && $0.cost!.amount!.description == "59.37774 UNKNOWN"
        })
        XCTAssertEqual(beancountTransaction2!.metaData.narration, "")
        XCTAssertEqual(beancountTransaction2!.metaData.payee, "")
        XCTAssertEqual(beancountTransaction2!.metaData.flag, .complete)
        XCTAssertEqual(beancountTransaction2!.metaData.date, TestUtils.date20240101)
        XCTAssert(beancountTransaction2!.postings.contains {
            $0.accountName == TestUtils.parking && $0.amount.description == "-755.30 UNKNOWN" && $0.price?.description == "-0.68 UNKNOWN"
        })
        XCTAssert(beancountTransaction2!.postings.contains {
            $0.accountName.fullName == "Assets:Cash:UNKNOWN" && $0.amount.description == "3.744300 UNKNOWN" && $0.cost!.amount!.description == "48.21871 UNKNOWN"
        })

        XCTAssertNil(importer.nextTransaction())
        XCTAssertEqual(importer.balancesToImport(), [])
        XCTAssertEqual(importer.pricesToImport(), [])
    }

    func testLedgerMapping() throws {
        let ledger = Ledger()
        try ledger.add(Account(name: try AccountName("Assets:EP:Cash"), commoditySymbol: "STOCK", metaData: [
            Settings.importerTypeKey: EquatePlusImporter.importerType, "stock": "STOCK", "purchase-currency": "USD", "contribution-currency": "EUR"
        ]))
        let importer = loadedImporter(ledger: ledger, transaction: fullString, balance: "")
        let transaction1 = importer.nextTransaction()
        XCTAssertNotNil(transaction1)
        let transaction2 = importer.nextTransaction()
        XCTAssertNotNil(transaction2)

        let beancountTransaction1 = [transaction1!.transaction, transaction2!.transaction].first { $0.metaData.date == TestUtils.date20231202 }
        let beancountTransaction2 = [transaction1!.transaction, transaction2!.transaction].first { $0.metaData.date == TestUtils.date20240101 }
        XCTAssertNotNil(beancountTransaction1)
        XCTAssertNotNil(beancountTransaction2)
        XCTAssert(beancountTransaction1!.postings.contains {
            $0.accountName.fullName == "Assets:EP:Cash" && $0.amount.description == "-863.19 EUR" && $0.price!.description == "-0.67 USD"
        })
        XCTAssert(beancountTransaction1!.postings.contains {
            $0.accountName.fullName == "Assets:EP:STOCK" && $0.amount.description == "3.910474 STOCK" && $0.cost!.amount!.description == "59.37774 USD"
        })
        XCTAssert(beancountTransaction2!.postings.contains {
            $0.accountName.fullName == "Assets:EP:Cash" && $0.amount.description == "-755.30 EUR" && $0.price?.description == "-0.68 USD"
        })
        XCTAssert(beancountTransaction2!.postings.contains {
            $0.accountName.fullName == "Assets:EP:STOCK" && $0.amount.description == "3.744300 STOCK" && $0.cost!.amount!.description == "48.21871 USD"
        })

        XCTAssertNil(importer.nextTransaction())
    }

    func testInvalidStockName() throws {
        let ledger = Ledger()
        try ledger.add(Account(name: try AccountName("Assets:EP:Cash"), commoditySymbol: "STOCK", metaData: [
            Settings.importerTypeKey: EquatePlusImporter.importerType, "stock": "TEST:", "purchase-currency": "USD", "contribution-currency": "EUR"
        ]))
        let importer = EquatePlusImporter(ledger: ledger, transaction: fullString, balance: "")
        let delegate = ErrorDelegate(error: AccountNameError.invaildName("Assets:TEST:"))
        importer.delegate = delegate
        importer.load()
        XCTAssert(delegate.verified)
    }

    func testErrorDescription() {
        XCTAssertEqual(
            EquatePlusImporterError.balanceImportNotSupported("BAL").errorDescription,
            "This importer does not support importing balances. Trying to import: BAL"
        )
        XCTAssertEqual(
            EquatePlusImporterError.failedToParseDate("DATE").errorDescription,
            "Failed to parse date: DATE"
        )
        XCTAssertEqual(
            EquatePlusImporterError.unknownContributionType("TYPE").errorDescription,
            "Unknow contribution type: TYPE"
        )
        XCTAssertEqual(
            EquatePlusImporterError.unknownTransactionType("TYPE").errorDescription,
            "Unknow transaction type: TYPE"
        )
        XCTAssertEqual(
            EquatePlusImporterError.invalidContributionMapping("TYPE", "CONT").errorDescription,
            "Unable to map contributions correctly. Found second contribtuion for type TYPE: CONT"
        )
        XCTAssertEqual(
            EquatePlusImporterError.invalidTransactionMapping("TYPE", "TRANS").errorDescription,
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

#if hasFeature(RetroactiveAttribute)
extension EquatePlusImporterError: @retroactive Equatable {}
#endif

extension EquatePlusImporterError: EquatableError {
    public static func == (lhs: EquatePlusImporterError, rhs: EquatePlusImporterError) -> Bool {
        if case let .balanceImportNotSupported(lhsString) = lhs, case let .balanceImportNotSupported(rhsString) = rhs {
            return lhsString == rhsString
        }
        if case let .failedToParseDate(lhsString) = lhs, case let .failedToParseDate(rhsString) = rhs {
            return lhsString == rhsString
        }
        if case let .unknownContributionType(lhsString) = lhs, case let .unknownContributionType(rhsString) = rhs {
            return lhsString == rhsString
        }
        if case let .unknownTransactionType(lhsString) = lhs, case let .unknownTransactionType(rhsString) = rhs {
            return lhsString == rhsString
        }
        if case let .invalidContributionMapping(lhsString1, lhsString2) = lhs, case let .invalidContributionMapping(rhsString1, rhsString2) = rhs {
            return lhsString1 == rhsString1 && lhsString2 == rhsString2
        }
        if case let .invalidTransactionMapping(lhsString1, lhsString2) = lhs, case let .invalidTransactionMapping(rhsString1, rhsString2) = rhs {
            return lhsString1 == rhsString1 && lhsString2 == rhsString2
        }
        return false
    }
}

#if hasFeature(RetroactiveAttribute)
extension AccountNameError: @retroactive Equatable {}
#endif

extension AccountNameError: EquatableError {
    public static func == (lhs: AccountNameError, rhs: AccountNameError) -> Bool {
        if case let .invaildName(lhsString) = lhs, case let .invaildName(rhsString) = rhs {
            return lhsString == rhsString
        }
        return false
    }
}
