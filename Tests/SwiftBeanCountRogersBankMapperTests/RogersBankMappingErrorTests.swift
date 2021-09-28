import RogersBankDownloader
@testable import SwiftBeanCountRogersBankMapper
import XCTest

final class RogersBankMappingErrorTests: XCTestCase {

    func testSRogersBankMappingErrorString() {
        XCTAssertEqual(
            "\(RogersBankMappingError.missingAccount(lastFour: "4320").localizedDescription)",
            "The account with the last four digits 4320 was not found in your ledger. Please make sure you add \(MetaDataKeys.account): \"4320\" to it."
        )
        let activity = TestActivity()
        XCTAssertEqual(
            "\(RogersBankMappingError.missingActivityData(activity: activity, key: "keyName").localizedDescription)",
            "A downloaded activty ist missing keyName data: \(activity)"
        )
    }

}
