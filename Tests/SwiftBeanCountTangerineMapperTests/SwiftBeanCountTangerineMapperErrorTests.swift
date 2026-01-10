import Foundation
@testable import SwiftBeanCountTangerineMapper
import Testing

@Suite
struct SwiftBeanCountTangerineMapperErrorTests {

   @Test
   func testDownloadErrorString() {
         #expect(
            "\(SwiftBeanCountTangerineMapperError.missingAccount(account: "abc").localizedDescription)" ==
            "Missing account in ledger: abc"
        )
         #expect(
            "\(SwiftBeanCountTangerineMapperError.invalidDate(date: "abcd").localizedDescription)" ==
            "Found invalid date in parsed transaction: abcd"
        )
    }

}
