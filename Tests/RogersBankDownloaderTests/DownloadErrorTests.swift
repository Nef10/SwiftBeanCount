@testable import RogersBankDownloader
import Testing
@Suite
struct DownloadErrorTests {
   @Test
   func downloadErrorString() {
       #expect("\(DownloadError.invalidJson(error: "ABC").localizedDescription)" == "The server response contained invalid JSON: ABC")
       #expect("\(DownloadError.invalidParameters(parameters: ["a": "b"]).localizedDescription)" == """
           The give parameters could not be converted to JSON: ["a": "b"]
           """)
       #expect("\(DownloadError.httpError(error: "failed").localizedDescription)" == "An HTTP error occurred: failed")
       #expect("\(DownloadError.noDataReceived.localizedDescription)" == "No data was received from the server")
       #expect("\(DownloadError.invalidStatementNumber(-1).localizedDescription)" == "-1 is not a valid statement number to download")
   }
}
