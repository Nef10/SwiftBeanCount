import Foundation
import SwiftBeanCountModel

protocol FormattableLedgerCommand: FormattableCommand, LedgerCommand {
    func getResult(from ledger: Ledger, parsingDuration: Double) throws -> [FormattableResult]
}

extension FormattableLedgerCommand {

    func getResult() throws -> [FormattableResult] {
        let start = Date.timeIntervalSinceReferenceDate
        let ledger = try parseLedger()
        let end = Date.timeIntervalSinceReferenceDate
        let time = end - start
        return try getResult(from: ledger, parsingDuration: time)
    }

}
