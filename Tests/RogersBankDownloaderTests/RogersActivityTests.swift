@testable import RogersBankDownloader
import XCTest

final class RogersActivityTests: XCTestCase {

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    private let json = """
        {
            "activityType": "AUTH",
            "activityStatus": "PENDING",
            "activityCategory": "token AUTH Request",
            "activityClassification": "test1",
            "cardNumber": "xxxx xxxx xxxx 1234",
            "date": "2022-05-10",
            "customerId": "abc123",
            "merchant": {
                "name": "ABC",
                "category": "test12",
                "address": {
                    "city": "Vancouver",
                    "postalCode": "XYX YXY",
                    "countryCode": "CAN"
                }
            },
            "foreign": {
                "exchangeFee": {
                    "value": "1.35",
                    "currency": "CAD"
                },
                "conversionMarkupRate": 1.23,
                "conversionRate": 1.13,
                "originalAmount": {
                    "value": "10.15",
                    "currency": "USD"
                }
            },
            "amount": {
                "value": "13.55",
                "currency": "CAD"
            }
        }
        """

    func testRogersActivity() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(Self.dateFormatter)
        let activity = try decoder.decode(RogersActivity.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(activity.activityType, ActivityType.authorization)
        XCTAssertEqual(activity.activityStatus, ActivityStatus.pending)
        XCTAssertEqual(activity.activityCategory, ActivityCategory.tokenAuthRequest)
        XCTAssertEqual(activity.activityClassification, "test1")
        XCTAssertEqual(activity.cardNumber, "xxxx xxxx xxxx 1234")
        XCTAssertEqual(activity.customerId, "abc123")
        XCTAssertEqual(activity.merchant.name, "ABC")
        XCTAssertEqual(activity.merchant.category, "test12")
        XCTAssertEqual(activity.merchant.address!.city, "Vancouver")
        XCTAssertEqual(activity.merchant.address!.postalCode, "XYX YXY")
        XCTAssertEqual(activity.merchant.address!.countryCode, "CAN")
        XCTAssertEqual(activity.foreign!.exchangeFee!.value, "1.35")
        XCTAssertEqual(activity.foreign!.exchangeFee!.currency, "CAD")
        XCTAssertEqual(activity.foreign!.conversionMarkupRate!, 1.23)
        XCTAssertEqual(activity.foreign!.conversionRate!, 1.13)
        XCTAssertEqual(activity.foreign!.originalAmount.value, "10.15")
        XCTAssertEqual(activity.foreign!.originalAmount.currency, "USD")
        XCTAssertEqual(activity.amount.value, "13.55")
        XCTAssertEqual(activity.amount.currency, "CAD")
    }

}
