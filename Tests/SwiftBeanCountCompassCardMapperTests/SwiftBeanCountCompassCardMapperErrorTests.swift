@testable import SwiftBeanCountCompassCardMapper
import Testing

@Suite
struct SwiftBeanCountCompassCardMapperErrorTests {

    @Test
    func testDownloadErrorString() {
         #expect(
            "\(SwiftBeanCountCompassCardMapperError.missingAccount(cardNumber: "123").localizedDescription)" ==
            "Missing account in ledger for compass card: 123. Make sure to add importer-type: \"compass-card\" and card-number: \"123\" to it."
        )
    }

}
