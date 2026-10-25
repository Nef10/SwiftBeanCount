import Foundation
import RitualDownloader
import SwiftBeanCountModel
import SwiftBeanCountRitualMapper
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

protocol RitualDownloaderProvider: AnyObject {
    var delegate: RitualDownloaderDelegate? { get set }

    func download(since: Date, knownReceiptIDs: Set<String>) async throws -> RitualDownloadResult
}

class RitualDownloadImporter: BaseImporter, DownloadImporter {
    override class var importerName: String { "Ritual Download" }
    override class var importerType: String { "ritual" }
    override class var helpText: String {
        """
        Downloads completed Ritual receipts. Sign in with your phone number, complete browser verification when required, and enter the verification code sent by SMS or email.

        Configure exactly one CAD account for each role with "ritual-role" metadata:
        * "expense" on an expense account
        * "company-benefit" on an income account
        * "bonus-program" on an income account

        The largest individual voucher up to CAD 25 is assigned to company-benefit. Other vouchers and applied credits use bonus-program.
        Card payments default to Assets:TODO. A unique matching bank payment is offered as a possible duplicate; its date, tags, metadata,
        expense category and other postings are preserved in the enriched transaction, suitable for replacing the original.
        Review duplicate output: accepting it as an additional transaction would count the original card payment twice.

        The default download window is 60 calendar days. To change it, add:
        YYYY-MM-DD custom "ritual-download-importer" "pastDaysToLoad" "60"
        The newest setting is used; zero means today, and a large value can load historical receipts.
        Receipt IDs already recorded as ritual-id are skipped. No balance assertions or prices are produced.
        """
    }

    override var importName: String { Self.importerName }

    private let existingLedger: Ledger
    private let downloader: RitualDownloaderProvider
    private let now: () -> Date
    private var transactions: [ImportedTransaction] = []

    override required convenience init(ledger: Ledger?) { self.init(ledger: ledger, downloader: RitualDownloader()) }

    init(ledger: Ledger?, downloader: RitualDownloaderProvider, now: @escaping () -> Date = Date.init) {
        existingLedger = ledger ?? Ledger()
        self.downloader = downloader
        self.now = now
        super.init(ledger: ledger)
    }

    override func load() {
        transactions = []
        guard delegate != nil else {
            return
        }
        do {
            let mapper = try SwiftBeanCountRitualMapper(ledger: existingLedger)
            let since = try dateToLoadFrom()
            download(since: since, mapper: mapper)
        } catch {
            show(error)
        }
    }

    override func nextTransaction() -> ImportedTransaction? {
        guard !transactions.isEmpty else {
            return nil
        }
        return transactions.removeFirst()
    }

    func dateToLoadFrom() throws -> Date {
        let custom = existingLedger.custom.filter { $0.name == "ritual-download-importer" && $0.values.first == "pastDaysToLoad" }.max { $0.date < $1.date }
        var days = 60
        if let custom {
            guard custom.values.count == 2, let value = Int(custom.values[1]), value >= 0, value <= 100_000 else {
                throw RitualDownloadError.invalidContext("pastDaysToLoad must be an integer from 0 to 100000")
            }
            days = value
        }
        let today = Calendar.current.startOfDay(for: now())
        guard let date = Calendar.current.date(byAdding: .day, value: -days, to: today) else {
            throw RitualDownloadError.invalidContext("Invalid date window")
        }
        return date
    }

    private func download(since: Date, mapper: SwiftBeanCountRitualMapper) {
        downloader.delegate = self
        let group = DispatchGroup()
        group.enter()
        Task { [self] in
            defer { group.leave() }
            do {
                let result = try await downloader.download(
                    since: since,
                    knownReceiptIDs: mapper.knownReceiptIDs
                )
                let mapped = try mapper.map(result.receipts, dateTolerance: Settings.dateTolerance)
                transactions = mapped.map { ImportedTransaction($0.transaction, possibleDuplicate: $0.possibleDuplicate) }
                for failure in result.failures {
                    show(failure)
                }
            } catch {
                show(error)
            }
        }
        group.wait()
    }

    private func show(_ error: Error) {
        guard let delegate else {
            return
        }
        let group = DispatchGroup()
        group.enter()
        delegate.error(error) { group.leave() }
        group.wait()
    }
}

extension RitualDownloader: RitualDownloaderProvider {}

extension RitualDownloadImporter: RitualDownloaderDelegate {
    func readCredential(_ key: String) -> String? {
        delegate?.readCredential(key)
    }

    func saveCredential(_ value: String, for key: String) {
        delegate?.saveCredential(value, for: key)
    }

    func requestPhoneNumber(callingCode: String, completion: @escaping (String) -> Bool) {
        delegate?.requestInput(name: "Phone number (\(callingCode))", type: .text([]), completion: completion)
    }

    func requestVerificationCode(destination: RitualOTPDestination, completion: @escaping (String) -> Bool) {
        delegate?.requestInput(name: destination.prompt, type: .otp, completion: completion)
    }

    #if canImport(UIKit)
    func view() -> UIView? { delegate?.view() }
    #elseif canImport(AppKit)
    func view() -> NSView? { delegate?.view() }
    #endif

    #if canImport(UIKit) || canImport(AppKit)
    func removeView() { delegate?.removeView() }
    #endif
}
