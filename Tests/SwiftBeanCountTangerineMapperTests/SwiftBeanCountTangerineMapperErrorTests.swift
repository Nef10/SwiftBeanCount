@testable import SwiftBeanCountTangerineMapper
import XCTest

final class SwiftBeanCountTangerineMapperErrorTests: XCTestCase {

    func testDownloadErrorString() {
         XCTAssertEqual(
            "\(SwiftBeanCountTangerineMapperError.missingAccount(account: "abc").localizedDescription)",
            "Missing account in ledger: abc"
        )
         XCTAssertEqual(
            "\(SwiftBeanCountTangerineMapperError.invalidDate(date: "abcd").localizedDescription)",
            "Found invalid date in parsed transaction: abcd"
        )
    }

}
