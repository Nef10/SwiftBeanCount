import RogersBankDownloader
@testable import SwiftBeanCountRogersBankMapper
import XCTest

final class RogersBankMappingErrorTests: XCTestCase {

    func testSRogersBankMappingErrorString() {
        XCTAssertEqual(
            "\(RogersBankMappingError.missingAccount(lastFour: "4320").localizedDescription)",
            "The account with the last four digits 4320 was not found in your ledger. Please make sure you add importer-type: \"rogers\" and last-four: \"4320\" to it."
        )
        let activity = TestActivity()
        XCTAssertEqual(
            "\(RogersBankMappingError.missingActivityData(activity: activity, key: "keyName").localizedDescription)",
            "A downloaded activty ist missing keyName data: \(activity)"
        )
    }

}
