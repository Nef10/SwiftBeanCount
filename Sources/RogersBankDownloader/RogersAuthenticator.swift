import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Protocol of the class for authenticating with Rogers Bank
public protocol Authenticator {

    /// Delegate for authentication
    var delegate: RogersAuthenticatorDelegate? { get set }

    /// Initializer
    init()

    /// Login and load a user account
    /// - Parameters:
    ///   - username: username to login
    ///   - password: password to login
    ///   - deviceId: deviceId to use if saved - otherwise a new random one will be generated
    ///   - completion: returns a User or a Download Error
    func login(username: String, password: String, deviceId: String?, completion: @escaping (Result<User, DownloadError>) -> Void)
}

/// Delegate for the `RogersAuthenticator`
public protocol RogersAuthenticatorDelegate: AnyObject {

    /// Select a way to do two factor authentication, e.g. email or text
    /// - Parameter preferences: available preferences
    /// - Returns: selected preference from the argement to use
    func selectTwoFactorPreference(_ preferences: [TwoFactorPreference]) -> TwoFactorPreference

    /// Get the two factor code from the user
    /// - Returns: two factor code
    func getTwoFactorCode() -> String

    /// Save the device id
    /// When the device id is saved and passed to the login function,
    /// the user might be able to skip entering a two factor code again
    /// - Parameter deviceId: device id to save
    func saveDeviceId(_ deviceId: String)
}

struct ErrorMessage: Codable {
    let title: String
    let status: Int
    let detail: String
}

struct TwoFactorPreferences: Codable {
    let preferences: [TwoFactorPreference]
    let cardLast4: String
    let accountId: String
    let customerId: String
    let productName: String
    let productExternalCode: String
}

/// Two factor preference, e.g. email or text
public struct TwoFactorPreference: Codable {

    /// Type of the preference, e.g. email or text
    public let type: String

    /// Value of the preference, e.g. email address or phone number
    public let value: String
}

struct TwoFactorCodeGenerationResult: Codable {
    let success: Bool
}

/// Class to authenticate with Rogers Bank
///
/// Call `login` to authenticate and receive a `User` instance
public class RogersAuthenticator: Authenticator {

    private static var startURL = URL(string: "https://rbaccess.rogersbank.com/?product=ROGERSBRAND")!
    private static var authenticationURL = URL(string: "https://rbaccess.rogersbank.com/issuing/digital/authenticate/user")!
    private static var twoFactorPreferenceURL = URL(string: "https://rbaccess.rogersbank.com/issuing/digital/twofactorpasscode/preferences/user")!
    private static var validateTwoFactorCodeURL = URL(string: "https://rbaccess.rogersbank.com/issuing/digital/authenticate/validatepasscode")!
    private static let twoFactorRequiredErrorTitle = "Device Not Found"
    private static let twoFactorRequiredErrorStatus = 412
    // swiftlint:disable:next line_length
    private static let defaultDeviceInfo = "[{\"key\":\"language\",\"value\":\"en-US\"},{\"key\":\"color_depth\",\"value\":30},{\"key\":\"device_memory\",\"value\":8},{\"key\":\"hardware_concurrency\",\"value\":10},{\"key\":\"resolution\",\"value\":[1728,1117]},{\"key\":\"available_resolution\",\"value\":[1728,1005]},{\"key\":\"timezone_offset\",\"value\":420},{\"key\":\"session_storage\",\"value\":1},{\"key\":\"local_storage\",\"value\":1},{\"key\":\"indexed_db\",\"value\":1},{\"key\":\"cpu_class\",\"value\":\"unknown\"},{\"key\":\"navigator_platform\",\"value\":\"MacIntel\"},{\"key\":\"regular_plugins\",\"value\":[\"PDF Viewer::Portable Document Format::application/pdf~pdf,text/pdf~pdf\",\"Chrome PDF Viewer::Portable Document Format::application/pdf~pdf,text/pdf~pdf\",\"Chromium PDF Viewer::Portable Document Format::application/pdf~pdf,text/pdf~pdf\",\"WebKit built-in PDF::Portable Document Format::application/pdf~pdf,text/pdf~pdf\"]},{\"key\":\"webgl_vendor\",\"value\":\"Google Inc. (Apple)~ANGLE (Apple, ANGLE Metal Renderer: Apple M1 Pro, Unspecified Version)\"},{\"key\":\"adblock\",\"value\":false},{\"key\":\"has_lied_languages\",\"value\":false},{\"key\":\"has_lied_resolution\",\"value\":false},{\"key\":\"has_lied_os\",\"value\":false},{\"key\":\"has_lied_browser\",\"value\":false},{\"key\":\"touch_support\",\"value\":[0,false,false]},{\"key\":\"js_fonts\",\"value\":[\"Arial\",\"Arial Black\",\"Arial Hebrew\",\"Arial Narrow\",\"Arial Rounded MT Bold\",\"Arial Unicode MS\",\"Comic Sans MS\",\"Courier\",\"Courier New\",\"Geneva\",\"Georgia\",\"Helvetica\",\"Helvetica Neue\",\"Impact\",\"Microsoft Sans Serif\",\"Monaco\",\"Palatino\",\"Tahoma\",\"Times\",\"Times New Roman\",\"Trebuchet MS\",\"Verdana\",\"Wingdings\",\"Wingdings 2\",\"Wingdings 3\"]}]"

    private static let authenticationRequest: URLRequest = {
        var request = URLRequest(url: authenticationURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ROGERSBRAND", forHTTPHeaderField: "Brand_id")
        request.setValue("json", forHTTPHeaderField: "Datatype")
        request.setValue("web", forHTTPHeaderField: "Sourcetype")
        return request
    }()

    private static let twoFactorPreferenceRequest: URLRequest = {
        var request = URLRequest(url: twoFactorPreferenceURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("json", forHTTPHeaderField: "Datatype")
        return request
    }()

    private static let validateTwoFactorCodeRequest: URLRequest = {
        var request = URLRequest(url: validateTwoFactorCodeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("ROGERSBRAND", forHTTPHeaderField: "Brand_id")
        request.setValue("json", forHTTPHeaderField: "Datatype")
        request.setValue("web", forHTTPHeaderField: "Sourcetype")
        return request
    }()

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    private var parameters = [String: String]()

    /// Delegate for authentication
    public weak var delegate: RogersAuthenticatorDelegate?

    /// Initialize the authenticator
    public required init() {
        // Empty
    }

    private static func sendStartRequest(completion: @escaping (DownloadError?) -> Void) {
        var request = URLRequest(url: startURL)
        request.httpMethod = "GET"

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard data != nil else {
                if let error {
                    completion(DownloadError.httpError(error: error.localizedDescription))
                } else {
                    completion(DownloadError.noDataReceived)
                }
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(DownloadError.httpError(error: "No HTTPURLResponse"))
                return
            }
            guard httpResponse.statusCode == 200 else {
                completion(DownloadError.httpError(error: "Status code \(httpResponse.statusCode)"))
                return
            }
            completion(nil)
        }
        task.resume()
    }

    private static func generateTwoFactorCodeURL(accountID: String, customerID: String) -> URL {
        URL(string: "https://rbaccess.rogersbank.com/issuing/digital/twofactorpasscode/\(accountID)/customer/\(customerID)/generatecodefordevice")!
    }

    private static func generateTwoFactorCodeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("json", forHTTPHeaderField: "Datatype")
        return request
    }

    private static func generateDeviceId() -> String {
        let hex = "abcdef0123456789"
        let part1 = String((0..<32).map { _ in hex.randomElement()! })
        let part2 = String((0..<32).map { _ in hex.randomElement()! })
        return "\(part1)%7C\(part2)"
    }

    /// Authenticate with Rogers Bank
    /// - Parameters:
    ///   - username: username to login
    ///   - password: password to login
    ///   - deviceId: deviceId to use if saved - otherwise a new random one will be generated
    ///   - completion: returns a User or a Download Error
    public func login(username: String, password: String, deviceId: String?, completion: @escaping (Result<User, DownloadError>) -> Void) {
        Self.sendStartRequest {
            if let error = $0 {
                completion(.failure(error))
                return
            }
            self.parameters = [
                "username": username,
                "password": password,
                "deviceId": (deviceId == nil || deviceId!.isEmpty) ? Self.generateDeviceId() : deviceId!,
                "deviceInfo": Self.defaultDeviceInfo
            ]
            self.sendAuthenticationRequest {
                completion($0)
            }
        }
    }

    private func sendAuthenticationRequest(completion: @escaping (Result<User, DownloadError>) -> Void) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: parameters, options: []) else {
            completion(.failure(DownloadError.invalidParameters(parameters: parameters)))
            return
        }

        let task = URLSession.shared.uploadTask(with: Self.authenticationRequest, from: jsonData) { data, response, error in
            let processedResponse = URLTaskHelper.processResponse(data: data, response: response, error: error)
            guard case let .success((data, httpResponse)) = processedResponse else {
                if case let .failure(error) = processedResponse {
                    completion(.failure(error))
                }
                return
            }
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401, let error = try? JSONDecoder().decode(ErrorMessage.self, from: data),
                    error.status == Self.twoFactorRequiredErrorStatus, error.title == Self.twoFactorRequiredErrorTitle {
                    self.twoFactorAuthPreferences(completion: completion)
                } else {
                    completion(.failure(DownloadError.httpError(error: "Status code \(httpResponse.statusCode)")))
                }
                return
            }
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .formatted(Self.dateFormatter)
                completion(.success(try decoder.decode(RogersUser.self, from: data)))
            } catch {
                completion(.failure(DownloadError.invalidJson(error: String(describing: error))))
            }
        }
        task.resume()
    }

    private func twoFactorAuthPreferences(completion: @escaping (Result<User, DownloadError>) -> Void) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: ["username": parameters["username"]], options: []) else {
            completion(.failure(DownloadError.invalidParameters(parameters: parameters)))
            return
        }
        let task = URLSession.shared.uploadTask(with: Self.twoFactorPreferenceRequest, from: jsonData) { data, response, error in
            let processedResponse = URLTaskHelper.processResponse(data: data, response: response, error: error)
            guard case let .success((data, httpResponse)) = processedResponse else {
                if case let .failure(error) = processedResponse {
                    completion(.failure(error))
                }
                return
            }
            guard httpResponse.statusCode == 200 else {
                completion(.failure(DownloadError.httpError(error: "Status code \(httpResponse.statusCode)")))
                return
            }
            do {
                let decoder = JSONDecoder()
                let twoFactorPreferences = try decoder.decode(TwoFactorPreferences.self, from: data)
                guard let preference = self.delegate?.selectTwoFactorPreference(twoFactorPreferences.preferences) else {
                    completion(.failure(DownloadError.noTwoFactorPreference))
                    return
                }
                self.generateTwoFactorCode(preferences: twoFactorPreferences, preference: preference, completion: completion)

            } catch {
                completion(.failure(DownloadError.invalidJson(error: String(describing: error))))
            }
        }
        task.resume()
    }

    private func generateTwoFactorCode(preferences: TwoFactorPreferences, preference: TwoFactorPreference, completion: @escaping (Result<User, DownloadError>) -> Void) {
        let json = parameters.filter { key, _ in key != "password" }.merging(["preferenceType": preference.type]) { _, new in new }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json, options: []) else {
            completion(.failure(DownloadError.invalidParameters(parameters: parameters)))
            return
        }
        let request = Self.generateTwoFactorCodeRequest(url: Self.generateTwoFactorCodeURL(accountID: preferences.accountId, customerID: preferences.customerId))
        let task = URLSession.shared.uploadTask(with: request, from: jsonData) { data, response, error in
            let processedResponse = URLTaskHelper.processResponse(data: data, response: response, error: error)
            guard case let .success((data, httpResponse)) = processedResponse else {
                if case let .failure(error) = processedResponse {
                    completion(.failure(error))
                }
                return
            }
            guard httpResponse.statusCode == 200 else {
                completion(.failure(DownloadError.httpError(error: "Status code \(httpResponse.statusCode)")))
                return
            }
            do {
                let result = try JSONDecoder().decode(TwoFactorCodeGenerationResult.self, from: data)
                if result.success {
                    self.loginWithTwoFactorAuthenticationCode(completion: completion)
                } else {
                    completion(.failure(DownloadError.twoFactorAuthenticationCodeGenerationFailed))
                }
            } catch {
                completion(.failure(DownloadError.invalidJson(error: String(describing: error))))
            }
        }
        task.resume()
    }

    private func loginWithTwoFactorAuthenticationCode(completion: @escaping (Result<User, DownloadError>) -> Void) {
        var json = parameters
        json.removeValue(forKey: "password")
        json["oneTimePassCode"] = delegate?.getTwoFactorCode()
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json, options: []) else {
            completion(.failure(DownloadError.invalidParameters(parameters: parameters)))
            return
        }
        let task = URLSession.shared.uploadTask(with: Self.validateTwoFactorCodeRequest, from: jsonData) { data, response, error in
            let processedResponse = URLTaskHelper.processResponse(data: data, response: response, error: error)
            guard case let .success((data, httpResponse)) = processedResponse else {
                if case let .failure(error) = processedResponse {
                    completion(.failure(error))
                }
                return
            }
            guard httpResponse.statusCode == 200 else {
                // Note: seems to return 404 when otp code is wrong
                completion(.failure(DownloadError.httpError(error: "Status code \(httpResponse.statusCode)")))
                return
            }
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .formatted(Self.dateFormatter)
                let user = try decoder.decode(RogersUser.self, from: data)
                self.delegate?.saveDeviceId(self.parameters["deviceId"] ?? "")
                completion(.success(user))
            } catch {
                completion(.failure(DownloadError.invalidJson(error: String(describing: error))))
            }
        }
        task.resume()
    }

}
