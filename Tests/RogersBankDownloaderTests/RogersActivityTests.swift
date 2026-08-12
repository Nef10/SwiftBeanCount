import Foundation
@testable import RogersBankDownloader
import Testing

@Suite
struct RogersActivityTests {
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

   @Test
   func rogersActivity() throws {
       let decoder = JSONDecoder()
       decoder.dateDecodingStrategy = .formatted(Self.dateFormatter)
       let activity = try decoder.decode(RogersActivity.self, from: json.data(using: .utf8)!)
       #expect(activity.activityType == .authorization)
       #expect(activity.activityStatus == .pending)
       #expect(activity.activityCategory == .tokenAuthRequest)
       #expect(activity.activityClassification == "test1")
       #expect(activity.cardNumber == "xxxx xxxx xxxx 1234")
       #expect(activity.customerId == "abc123")
       #expect(activity.merchant.name == "ABC")
       #expect(activity.merchant.category == "test12")
       #expect(activity.merchant.address!.city == "Vancouver")
       #expect(activity.merchant.address!.postalCode == "XYX YXY")
       #expect(activity.merchant.address!.countryCode == "CAN")
       #expect(activity.foreign!.exchangeFee!.value == "1.35")
       #expect(activity.foreign!.exchangeFee!.currency == "CAD")
       #expect(activity.foreign!.conversionMarkupRate! == 1.23)
       #expect(activity.foreign!.conversionRate! == 1.13)
       #expect(activity.foreign!.originalAmount.value == "10.15")
       #expect(activity.foreign!.originalAmount.currency == "USD")
       #expect(activity.amount.value == "13.55")
       #expect(activity.amount.currency == "CAD")
   }
}
