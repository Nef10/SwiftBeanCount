import Foundation

enum RitualFormEncoder {

    static func encoded(_ values: [String: String]) -> Data {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let form = values.keys.sorted().map { $0 + "=" + values[$0]!.addingPercentEncoding(withAllowedCharacters: allowed)! }.joined(separator: "&")
        return Data(form.utf8)
    }

}
