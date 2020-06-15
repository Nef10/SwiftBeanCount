import Rainbow
@testable import SwiftBeanCountCLILibrary
import XCTest

struct TestColorizedCommand: ColorizedCommand {
    var noColor: Bool = false
}

class ColorizedCommandTests: XCTestCase {

    func testHelp() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = true

        var subject = TestColorizedCommand()
        subject.noColor = true
        subject.adjustColorization()

        XCTAssertFalse(Rainbow.enabled)

        Rainbow.enabled = originalValue
    }

}
