@testable import TangerineDownloader
import XCTest

final class TangerineDownloaderErrorTests: XCTestCase {

    func testDownloadErrorString() {
         XCTAssertEqual(
            "\(TangerineDownloaderError.accountsLoadingFailed.localizedDescription)",
            "Could not parse the accounts from the server"
        )
         XCTAssertEqual(
            "\(TangerineDownloaderError.transactionLoadingFailed.localizedDescription)",
            "Could not parse the transactions from the server"
        )
    }

}
