import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountSheetSync
import Testing

@Suite
struct SyncErrorTests {

    @Test
    func unknownErrorDescription() {
        let error = SyncError.unknowError
        #expect(error.localizedDescription == "An unknown Error occured")
    }

    @Test
    func missingSettingErrorDescription() {
        let error = SyncError.missingSetting("testSetting")
        #expect(error.localizedDescription == "Missing setting in your ledger: testSetting")
    }

    @Test
    func invalidSettingErrorDescription() {
        let error = SyncError.invalidSetting("testSetting", "invalidValue")
        #expect(error.localizedDescription == "Invalid setting in your ledger: invalidValue is invalid for testSetting")
    }
}
