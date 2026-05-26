import Foundation
@testable import SwiftBeanCountSheetSync
import Testing

@Suite
struct SheetParserErrorTests {

    @Test
    func missingHeaderErrorDescription() {
        let error = SheetParserError.missingHeader("Test header missing")
        #expect(error.localizedDescription == "Test header missing")
    }

    @Test
    func invalidValueErrorDescription() {
        let error = SheetParserError.invalidValue("Invalid value provided")
        #expect(error.localizedDescription == "Invalid value provided")
    }

    @Test
    func missingValueErrorDescription() {
        let error = SheetParserError.missingValue("Value is missing")
        #expect(error.localizedDescription == "Value is missing")
    }
}
