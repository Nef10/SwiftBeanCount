import SwiftBeanCountModel
import SwiftBeanCountParser
import Testing

struct LedgerBookingTests {
    @Test(arguments: ["STRICT", "FIFO", "LIFO"], ["-1001.32", "-500.00"])
    func loadingLotWithoutCostCompletes(bookingMethod: String, reduction: String) throws {
        let ledger = Parser.parse(string: """
            2024-01-01 open Assets:Stock WSE300 "\(bookingMethod)"
            2024-01-05 * "Test" "Unresolved cost"
              Assets:Stock 1001.32 WSE300 {2024-01-05}
            2024-01-06 * "Test" "Reduce lot"
              Assets:Stock \(reduction) WSE300 {2024-01-05}
            """)

        #expect(ledger.parsingErrors.isEmpty)
        #expect(ledger.transactions.count == 2)
        #if RustLedger
        #expect(ledger.errors.isEmpty)
        for transaction in ledger.transactions {
            _ = try transaction.balance(in: ledger)
        }
        #else
        let error = ledger.ledgerErrors.first { $0.contains("has no cost amount") }
        #expect(error != nil, "\(ledger.ledgerErrors)")
        #expect(error?.contains("WSE300 {2024-01-05}") == true)
        #endif
    }
}
