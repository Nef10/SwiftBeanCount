@testable import SwiftBeanCountCompassCardMapper
import XCTest

final class SwiftBeanCountCompassCardMapperErrorTests: XCTestCase {

    func testDownloadErrorString() {
         XCTAssertEqual(
            "\(SwiftBeanCountCompassCardMapperError.missingAccount(cardNumber: "123").localizedDescription)",
            "Missing account in ledger for compass card: 123. Make sure to add importer-type: \"compass-card\" and card-number: \"123\" to it."
        )
    }

}
