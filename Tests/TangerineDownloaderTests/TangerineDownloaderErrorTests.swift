@testable import TangerineDownloader
import Testing

@Suite
struct TangerineDownloaderErrorTests {

    @Test
    func testDownloadErrorString() {
        #expect("\(TangerineDownloaderError.accountsLoadingFailed.localizedDescription)" == "Could not parse the accounts from the server")
        #expect("\(TangerineDownloaderError.transactionLoadingFailed.localizedDescription)" == "Could not parse the transactions from the server")
    }

}
