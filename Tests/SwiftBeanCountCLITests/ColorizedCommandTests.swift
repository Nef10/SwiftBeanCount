#if os(macOS)

import Foundation
import Rainbow
@testable import SwiftBeanCountCLI
import Testing

struct TestColorizedCommand: ColorizedCommand {
    var colorOptions = ColorizedCommandOptions()
}

@Suite
struct ColorizedCommandTests {

    @Test
    func help() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = true

        var subject = TestColorizedCommand()
        subject.colorOptions.noColor = true
        subject.adjustColorization()

        #expect(!Rainbow.enabled)

        Rainbow.enabled = originalValue
    }

}

#endif // os(macOS)
