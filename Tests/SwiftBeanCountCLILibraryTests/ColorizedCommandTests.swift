import Rainbow
@testable import SwiftBeanCountCLILibrary
import XCTest

struct TestCommand: ColorizedCommand {
    var noColor: Bool = false
}

class ColorizedCommandTests: XCTestCase {

   func testHelp() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = true

        var subject = TestCommand()
        subject.noColor = true
        subject.adjustColorization()

        XCTAssertFalse(Rainbow.enabled)

        Rainbow.enabled = originalValue
    }

}
