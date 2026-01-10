import Foundation
import Rainbow
@testable import SwiftBeanCountCLI
import Testing

#if os(macOS)

struct TestColorizedCommand: ColorizedCommand {
    var colorOptions = ColorizedCommandOptions()
}

@Suite
struct ColorizedCommandTests {

   @Test
   func testHelp() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = true

        var subject = TestColorizedCommand()
        subject.colorOptions.noColor = true
        subject.adjustColorization()

        #expect(!(Rainbow.enabled))

        Rainbow.enabled = originalValue
    }

}

#endif // os(macOS)
