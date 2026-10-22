import Foundation
import RitualDownloader
import SwiftBeanCountModel
import SwiftBeanCountParser
import Testing

@testable import SwiftBeanCountImporter

private final class TestRitualDownloader: RitualDownloaderProvider {
    weak var delegate: RitualDownloaderDelegate?
    let receipts: [RitualReceipt]
    var since: Date?
    var knownIDs: Set<String> = []
    var calls = 0
    var onDownload: ((RitualDownloaderDelegate) -> Void)?
    var error: Error?

    init(receipts: [RitualReceipt] = []) { self.receipts = receipts }

    func download(since: Date, knownReceiptIDs: Set<String>) async throws -> RitualDownloadResult {
        self.since = since
        knownIDs = knownReceiptIDs
        calls += 1
        if let error { throw error }
        onDownload?(try #require(delegate))
        return RitualDownloadResult(receipts: receipts)
    }
}

private final class RitualTestDelegate: BaseTestImporterDelegate {
    var credentials: [String: String] = [:]
    var inputs: [String] = []
    var errors: [Error] = []
    var codePrompt = "SMS code (phone ending 1234)"

    override func readCredential(_ key: String) -> String? { credentials[key] }

    override func saveCredential(_ value: String, for key: String) { credentials[key] = value }

    override func requestInput(name: String, type: ImporterInputRequestType, completion: (String) -> Bool) {
        inputs.append(name)
        if name == "Phone number (+1)" {
            #expect(type == .text([]))
            #expect(!completion("invalid phone"))
            #expect(completion("+1 (555) 555-0123"))
        } else {
            #expect(name == codePrompt)
            #expect(type == .otp)
            #expect(!completion("123"))
            #expect(completion("123456"))
        }
    }

    override func error(_ error: Error, completion: () -> Void) {
        errors.append(error)
        completion()
    }
}

private func configuredLedger() -> Ledger {
    Parser.parse(
        string: """
            2020-01-01 open Expenses:Food CAD
              ritual-role: "expense"
            2020-01-01 open Income:Benefit CAD
              ritual-role: "company-benefit"
            2020-01-01 open Income:Bonus CAD
              ritual-role: "bonus-program"
            """
    )
}

extension TestsUsingStorage {
    @Suite
    struct RitualDownloadImporterTests {
        @Test
        func mappingAndTransactionIteration() throws {
            let receipt = try RitualReceipt(
                receiptID: String(repeating: "a", count: 32),
                dateTime: "Oct. 7, 2026",
                merchantName: "Test Cafe",
                status: "Order Completed",
                items: [RitualReceiptItem(quantity: 1, itemName: " Cake [GF] ", price: "15.00")],
                totals: [
                    RitualTotalsLine(label: "Subtotal", amount: "15.00"), RitualTotalsLine(label: "Voucher", amount: "-15.00"),
                    RitualTotalsLine(label: "Total", amount: "0.00")
                ]
            )
            let downloader = TestRitualDownloader(receipts: [receipt])
            let today = Date.now
            let importer = RitualDownloadImporter(ledger: configuredLedger(), downloader: downloader) { today }
            let delegate = RitualTestDelegate()
            importer.delegate = delegate
            importer.load()
            #expect(downloader.calls == 1)
            #expect(downloader.since == Calendar.current.date(byAdding: .day, value: -60, to: Calendar.current.startOfDay(for: today)))
            #expect(importer.nextTransaction()?.transaction.metaData.narration == "Cake")
            #expect(importer.nextTransaction() == nil)
            #expect(importer.balancesToImport().isEmpty)
            #expect(importer.pricesToImport().isEmpty)
            #expect(delegate.errors.isEmpty)
        }

        @Test
        func knownReceiptIDs() {
            let ledger = configuredLedger()
            ledger.add(Transaction(metaData: TransactionMetaData(date: Date(), metaData: ["ritual-id": String(repeating: "b", count: 32)]), postings: []))
            let downloader = TestRitualDownloader()
            let importer = RitualDownloadImporter(ledger: ledger, downloader: downloader)
            let delegate = RitualTestDelegate()
            importer.delegate = delegate
            importer.load()
            #expect(delegate.inputs.isEmpty)
            #expect(downloader.knownIDs == [String(repeating: "b", count: 32)])
        }

        @Test
        func newestDayWindowAndInvalidSettings() throws {
            let ledger = configuredLedger()
            let today = Date.now
            ledger.custom = [
                Custom(date: today.addingTimeInterval(-1), name: "ritual-download-importer", values: ["pastDaysToLoad", "20"]),
                Custom(date: today, name: "ritual-download-importer", values: ["pastDaysToLoad", "5"])
            ]
            let downloader = TestRitualDownloader()
            let importer = RitualDownloadImporter(ledger: ledger, downloader: downloader) { today }
            #expect(try importer.dateToLoadFrom() == Calendar.current.date(byAdding: .day, value: -5, to: Calendar.current.startOfDay(for: today)))
            ledger.custom = [Custom(date: today, name: "ritual-download-importer", values: ["pastDaysToLoad", "0"])]
            #expect(try importer.dateToLoadFrom() == Calendar.current.startOfDay(for: today))
            let delegate = RitualTestDelegate()
            importer.delegate = delegate
            for values in [["pastDaysToLoad"], ["pastDaysToLoad", "-1"], ["pastDaysToLoad", "junk"]] {
                ledger.custom = [Custom(date: today, name: "ritual-download-importer", values: values)]
                importer.load()
            }
            #expect(delegate.errors.count == 3)
            #expect(downloader.calls == 0)
            #expect(delegate.inputs.isEmpty)
        }

        @Test
        func duplicateIsExposedWithoutChangingExistingBankTransaction() throws { // swiftlint:disable:this function_body_length
            let ledger = configuredLedger()
            let date = Calendar.current.date(from: DateComponents(year: 2_026, month: 10, day: 7))!
            let bank = Transaction(
                metaData: TransactionMetaData(date: date, payee: "Test Cafe", narration: "Bank description", metaData: ["bank-id": "saved"]),
                postings: [
                    Posting(accountName: try AccountName("Liabilities:Card"), amount: Amount(number: -5, commoditySymbol: "CAD", decimalDigits: 2)),
                    Posting(accountName: try AccountName("Expenses:Food"), amount: Amount(number: 5, commoditySymbol: "CAD", decimalDigits: 2))
                ]
            )
            ledger.add(bank)
            let receipt = try RitualReceipt(
                receiptID: String(repeating: "d", count: 32),
                dateTime: "Oct. 7, 2026",
                merchantName: "Test Cafe",
                status: "Order Completed",
                items: [RitualReceiptItem(quantity: 1, itemName: "Cake", price: "15.00")],
                totals: [
                    RitualTotalsLine(label: "Subtotal", amount: "15.00"), RitualTotalsLine(label: "Voucher", amount: "-10.00"),
                    RitualTotalsLine(label: "Total", amount: "5.00")
                ]
            )
            let importer = RitualDownloadImporter(ledger: ledger, downloader: TestRitualDownloader(receipts: [receipt])) { date }
            let delegate = RitualTestDelegate()
            importer.delegate = delegate
            importer.load()
            let imported = try #require(importer.nextTransaction())
            #expect(imported.possibleDuplicate === bank)
            #expect(imported.transaction.postings[0].accountName == bank.postings[0].accountName)
            #expect(imported.transaction.metaData.metaData["bank-id"] == "saved")
            #expect(bank.metaData.metaData["ritual-id"] == nil)
            #expect(delegate.errors.isEmpty)
        }

        @Test
        func missingRolesFailBeforeCredentialsOrNetwork() {
            let downloader = TestRitualDownloader()
            let importer = RitualDownloadImporter(ledger: Ledger(), downloader: downloader)
            let delegate = RitualTestDelegate()
            importer.delegate = delegate
            importer.load()
            #expect(delegate.errors.count == 1)
            #expect(delegate.inputs.isEmpty)
            #expect(downloader.calls == 0)
        }
        @Test
        func hostInputAndCredentialCallbacksAreForwarded() {
            let downloader = TestRitualDownloader()
            let importer = RitualDownloadImporter(ledger: configuredLedger(), downloader: downloader)
            let delegate = RitualTestDelegate()
            delegate.credentials["ritual-refresh-token"] = "saved-token"
            delegate.codePrompt = "Email verification code (sent to s***@example.test)"
            downloader.onDownload = { host in
                #expect(host.readCredential("ritual-refresh-token") == "saved-token")
                host.saveCredential("rotated-token", for: "ritual-refresh-token")
                host.requestPhoneNumber(callingCode: "+1") { $0 == "+1 (555) 555-0123" }
                host.requestVerificationCode(destination: .email(maskedAddress: "s***@example.test")) { $0 == "123456" }
            }
            importer.delegate = delegate
            importer.load()
            #expect(delegate.inputs == ["Phone number (+1)", delegate.codePrompt])
            #expect(delegate.credentials["ritual-refresh-token"] == "rotated-token")
            #expect(delegate.errors.isEmpty)
        }

        @Test
        func downloadErrorIsReportedToHost() {
            let downloader = TestRitualDownloader()
            downloader.error = RitualAuthenticationError.cancelled
            let importer = RitualDownloadImporter(ledger: configuredLedger(), downloader: downloader)
            let delegate = RitualTestDelegate()
            importer.delegate = delegate
            importer.load()
            #expect(delegate.errors.first as? RitualAuthenticationError == .cancelled)
            #expect(importer.nextTransaction() == nil)
        }
    }
}
