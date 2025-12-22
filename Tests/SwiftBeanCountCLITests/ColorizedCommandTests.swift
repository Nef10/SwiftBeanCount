#if os(macOS)

import Rainbow
@testable import SwiftBeanCountCLI
import XCTest

struct TestColorizedCommand: ColorizedCommand {
    var colorOptions = ColorizedCommandOptions()
}

final class ColorizedCommandTests: XCTestCase {

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

#endif // os(macOS)
