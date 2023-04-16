import Rainbow
@testable import SwiftBeanCountCLILibrary
import XCTest

struct TestColorizedCommand: ColorizedCommand {
    var colorOptions = ColorizedCommandOptions()
}

class ColorizedCommandTests: XCTestCase {

    func testHelp() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = true

        var subject = TestColorizedCommand()
        subject.colorOptions.noColor = true
        subject.adjustColorization()

        XCTAssertFalse(Rainbow.enabled)

        Rainbow.enabled = originalValue
    }

}
