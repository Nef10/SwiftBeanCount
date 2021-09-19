import Foundation

/// extension to convert strings from camelCase to kebab-case
extension String {

    func camelCaseToKebabCase() -> String {
        ["([A-Z]+)([A-Z][a-z]|[0-9])", "([a-z])([A-Z]|[0-9])", "([0-9])([A-Z])"]
        .map { try! NSRegularExpression(pattern: $0, options: []) } // swiftlint:disable:this force_try
        .reduce(self) { $1.stringByReplacingMatches(in: $0, range: NSRange($0.startIndex..., in: $0), withTemplate: "$1-$2") }
        .lowercased()
    }

}
