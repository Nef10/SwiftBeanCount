import Foundation
import SwiftBeanCountModel
@testable import SwiftBeanCountSheetSync
import Testing

@Suite
struct LedgerSettingsTests {

    @Test
    func ledgerSettingsInitialization() throws {
        let commoditySymbol = "USD"
        let tag = Tag(name: "test-tag")
        let name = "TestUser"
        let accountName = try AccountName("Assets:TestAccount")
        let dateTolerance: TimeInterval = 86_400
        let categoryAccountNames = ["Food": try AccountName("Expenses:Food")]
        let accountNameCategories = ["Expenses:Food": "Food"]

        let settings = LedgerSettings(
            commoditySymbol: commoditySymbol,
            tag: tag,
            name: name,
            accountName: accountName,
            dateTolerance: dateTolerance,
            categoryAccountNames: categoryAccountNames,
            accountNameCategories: accountNameCategories
        )

        #expect(settings.commoditySymbol == commoditySymbol)
        #expect(settings.tag == tag)
        #expect(settings.name == name)
        #expect(settings.accountName == accountName)
        #expect(settings.dateTolerance == dateTolerance)
        #expect(settings.categoryAccountNames == categoryAccountNames)
        #expect(settings.accountNameCategories == accountNameCategories)
    }

    @Test
    func ledgerSettingsConstants() {
        #expect(LedgerSettingsConstants.settingsKey == "sheet-sync-settings")
        #expect(LedgerSettingsConstants.categoryKey == "sheet-sync-category")
        #expect(LedgerSettingsConstants.commoditySymbolKey == "commoditySymbol")
        #expect(LedgerSettingsConstants.accountKey == "account")
        #expect(LedgerSettingsConstants.tagKey == "tag")
        #expect(LedgerSettingsConstants.nameKey == "name")
        #expect(LedgerSettingsConstants.dateToleranceKey == "dateTolerance")
    }

    @Test
    func ledgerSettingsFallbackAccountName() {
        #expect(LedgerSettings.fallbackAccountName.fullName == "Expenses:TODO")
    }

    @Test
    func ledgerSettingsOwnAccountName() {
        #expect(LedgerSettings.ownAccountName.fullName == "Assets:TODO")
    }
}
