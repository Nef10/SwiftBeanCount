import CryptoKit
import Foundation

/// Matches one path component using the Rust glob crate's Unicode-scalar
/// semantics. Directory traversal handles `**` separately.
private struct GlobComponentMatcher {
    private enum Token {
        case literal(UInt32)
        case any
        case sequence
        case characterClass(negated: Bool, ranges: [(UInt32, UInt32)])
    }

    private enum ParseResult {
        case valid([Token])
        case invalid
    }

    private let tokens: [Token]

    init?(pattern: String) {
        guard case let .valid(tokens) = Self.parse(Array(pattern.unicodeScalars.map(\.value))) else {
            return nil
        }
        self.tokens = tokens
    }

    private static func parse(_ scalars: [UInt32]) -> ParseResult {
        var tokens = [Token]()
        var index = 0
        while index < scalars.count {
            let parsed: (Token, Int)?
            switch scalars[index] {
            case 42:
                parsed = sequenceToken(in: scalars, at: index)
            case 63:
                parsed = (.any, index + 1)
            case 91:
                parsed = characterClassToken(in: scalars, at: index)
            default:
                parsed = (.literal(scalars[index]), index + 1)
            }
            guard let (token, nextIndex) = parsed else {
                return .invalid
            }
            tokens.append(token)
            index = nextIndex
        }
        return .valid(tokens)
    }

    private static func sequenceToken(in scalars: [UInt32], at index: Int) -> (Token, Int)? {
        var end = index + 1
        while end < scalars.count, scalars[end] == 42 {
            end += 1
        }
        guard end - index == 1 else {
            return nil
        }
        return (.sequence, end)
    }

    private static func characterClassToken(in scalars: [UInt32], at index: Int) -> (Token, Int)? {
        let negated = index + 1 < scalars.count && scalars[index + 1] == 33
        let contentStart = index + (negated ? 2 : 1)
        let searchStart = contentStart + 1
        guard searchStart < scalars.count,
              let close = scalars[searchStart...].firstIndex(of: 93) else {
            return nil
        }
        let ranges = characterRanges(in: scalars[contentStart..<close])
        return (.characterClass(negated: negated, ranges: ranges), close + 1)
    }

    private static func characterRanges(in scalars: ArraySlice<UInt32>) -> [(UInt32, UInt32)] {
        let scalars = Array(scalars)
        var ranges = [(UInt32, UInt32)]()
        var index = 0
        while index < scalars.count {
            if index + 2 < scalars.count, scalars[index + 1] == 45 {
                ranges.append((scalars[index], scalars[index + 2]))
                index += 3
            } else {
                ranges.append((scalars[index], scalars[index]))
                index += 1
            }
        }
        return ranges
    }

    func matches(_ value: String) -> Bool {
        let scalars = Array(value.unicodeScalars.map(\.value))
        var previous = Array(repeating: false, count: scalars.count + 1)
        previous[0] = true
        for token in tokens {
            var next = Array(repeating: false, count: scalars.count + 1)
            apply(token, to: scalars, previous: previous, next: &next)
            previous = next
        }
        return previous[scalars.count]
    }

    private func apply(_ token: Token, to scalars: [UInt32], previous: [Bool], next: inout [Bool]) {
        switch token {
        case .literal(let expected):
            for offset in 1..<(scalars.count + 1) where previous[offset - 1] && scalars[offset - 1] == expected {
                next[offset] = true
            }
        case .any:
            for offset in 1..<(scalars.count + 1) where previous[offset - 1] {
                next[offset] = true
            }
        case .sequence:
            next[0] = previous[0]
            for offset in 1..<(scalars.count + 1) {
                next[offset] = previous[offset] || next[offset - 1]
            }
        case let .characterClass(negated, ranges):
            for offset in 1..<(scalars.count + 1) where previous[offset - 1] {
                let contained = ranges.contains { lower, upper in
                    lower <= scalars[offset - 1] && scalars[offset - 1] <= upper
                }
                next[offset] = negated ? !contained : contained
            }
        }
    }
}

private enum SourceFileContents {
    case available(Data)
    case unavailable
}

/// A fingerprint of the authored root and its include dependencies, including glob membership.
/// The parser reads files independently; compare snapshots before and after parsing before publishing.
struct LedgerSourceSnapshot {
    let hash: SHA256.Digest

    init(url: URL) throws {
        var sources = [String: SourceFileContents]()
        var visited = Set<String>()
        try Self.collect(url: url.standardizedFileURL, root: true, into: &sources, visited: &visited)
        var hasher = SHA256()
        for path in sources.keys.sorted() {
            switch sources[path]! {
            case .available(let data):
                hasher.update(data: Data("\(path.utf8.count):\(path):available:\(data.count):".utf8))
                hasher.update(data: data)
            case .unavailable:
                hasher.update(data: Data("\(path.utf8.count):\(path):unavailable:".utf8))
            }
        }
        hash = hasher.finalize()
    }

    private static func collect(
        url: URL,
        root: Bool,
        into sources: inout [String: SourceFileContents],
        visited: inout Set<String>
    ) throws {
        guard visited.insert(url.resolvingSymlinksInPath().path).inserted else {
            return
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            if root {
                throw error
            }
            // Missing or inaccessible includes are diagnosed by the backend. Fingerprint their absence
            // so granting access or creating the file causes a reload.
            sources[url.path] = .unavailable
            return
        }
        sources[url.path] = .available(data)
        guard let text = String(data: data, encoding: .utf8) else {
            return
        }
        let expression = try NSRegularExpression(pattern: #"(?m)^\h*include\h*("(?:[^"\\\r\n]|\\.)*")"#)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in expression.matches(in: text, range: range) {
            guard let valueRange = Range(match.range(at: 1), in: text),
                  let path = try? JSONDecoder().decode(String.self, from: Data(text[valueRange].utf8)) else {
                continue
            }
            let include = URL(fileURLWithPath: path, relativeTo: url.deletingLastPathComponent()).standardizedFileURL
            for dependency in expand(include) {
                try collect(url: dependency, root: false, into: &sources, visited: &visited)
            }
        }
    }

    private static func expand(_ url: URL) -> [URL] {
        let components = url.pathComponents
        guard let wildcardIndex = components.firstIndex(where: containsGlobPattern) else {
            return [url]
        }
        let base = baseURL(components: components, wildcardIndex: wildcardIndex)
        return expand(base: base, patterns: Array(components[wildcardIndex...]), index: 0, recursiveAncestors: [])
    }

    private static func baseURL(components: [String], wildcardIndex: Int) -> URL {
        var path = components.first == "/" ? "/" : ""
        for component in components[..<wildcardIndex] where component != "/" {
            path += (path.hasSuffix("/") ? "" : "/") + component
        }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    }

    private static func containsGlobPattern(_ component: String) -> Bool {
        component.contains { "*?[".contains($0) }
    }

    private static func expand(base: URL, patterns: [String], index: Int, recursiveAncestors: Set<String>) -> [URL] {
        guard index < patterns.count else {
            return [base.standardizedFileURL]
        }
        let pattern = patterns[index]
        if pattern == "**" {
            return expandRecursive(base: base, patterns: patterns, index: index, ancestors: recursiveAncestors)
        }
        guard !pattern.contains("**") else {
            return []
        }
        if containsGlobPattern(pattern) {
            return expandComponent(base: base, patterns: patterns, index: index, pattern: pattern, ancestors: recursiveAncestors)
        }
        return expandLiteral(base: base, patterns: patterns, index: index, component: pattern, ancestors: recursiveAncestors)
    }

    private static func expandRecursive(base: URL, patterns: [String], index: Int, ancestors: Set<String>) -> [URL] {
        let atEnd = index + 1 == patterns.count
        var matches = atEnd ? [] : expand(base: base, patterns: patterns, index: index + 1, recursiveAncestors: ancestors)
        let canonicalBase = base.resolvingSymlinksInPath().standardizedFileURL.path
        guard !ancestors.contains(canonicalBase), isDirectory(base) else {
            return matches
        }
        var descendants = ancestors
        descendants.insert(canonicalBase)
        for child in directoryContents(of: base).sorted(by: { $0.path < $1.path }) where isDirectory(child) {
            if atEnd { matches.append(child) }
            matches += expandRecursive(base: child, patterns: patterns, index: index, ancestors: descendants)
        }
        return matches
    }

    private static func expandComponent(base: URL, patterns: [String], index: Int, pattern: String, ancestors: Set<String>) -> [URL] {
        guard let matcher = GlobComponentMatcher(pattern: pattern) else {
            return []
        }
        return directoryContents(of: base).sorted { $0.path < $1.path }.reduce(into: [URL]()) { matches, child in
            guard matcher.matches(child.lastPathComponent) else {
                return
            }
            matches += expand(base: child, patterns: patterns, index: index + 1, recursiveAncestors: ancestors)
        }
    }

    private static func expandLiteral(base: URL, patterns: [String], index: Int, component: String, ancestors: Set<String>) -> [URL] {
        let child = base.appendingPathComponent(component).standardizedFileURL
        guard FileManager.default.fileExists(atPath: child.path) else {
            return []
        }
        return expand(base: child, patterns: patterns, index: index + 1, recursiveAncestors: ancestors)
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private static func directoryContents(of url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )) ?? []
    }
}
