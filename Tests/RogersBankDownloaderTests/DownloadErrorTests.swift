@testable import RogersBankDownloader
import XCTest

final class DownloadErrorTests: XCTestCase {

    func testDownloadErrorString() {
        XCTAssertEqual(
            "\(DownloadError.invalidJson(error: "ABC").localizedDescription)",
            "The server response contained invalid JSON: ABC"
        )
        XCTAssertEqual(
            "\(DownloadError.invalidParameters(parameters: ["a": "b"]).localizedDescription)",
            """
            The give parameters could not be converted to JSON: ["a": "b"]
            """
        )
         XCTAssertEqual(
            "\(DownloadError.httpError(error: "failed").localizedDescription)",
            "An HTTP error occurred: failed"
        )
         XCTAssertEqual(
            "\(DownloadError.noDataReceived.localizedDescription)",
            "No data was received from the server"
        )
         XCTAssertEqual(
            "\(DownloadError.invalidStatementNumber(-1).localizedDescription)",
            "-1 is not a valid statement number to download"
        )
    }

}
