#if RustLedger
import Foundation
import SwiftBeanCountModel
import SwiftBeanCountRustLedgerBindings

enum RustLedgerValueMapper {

    private enum ProjectionError: Error {
        case invalidAmount
    }

    static func addCommodities(_ directives: [DirectiveRecord], to builder: LedgerBuilder, diagnostics: inout [String]) {
        for directive in directives where directive.kind.lowercased() == "commodity" {
            guard let symbol = directive.currency, let date = date(from: directive) else {
                diagnostics.append("RustLedger could not represent a commodity declaration (\(sourceLocation(directive))).")
                continue
            }
            let commodity = Commodity(symbol: symbol, opening: date, metaData: metadata(directive.metadata))
            do {
                try builder.add(commodity)
            } catch {
                diagnostics.append("Error with commodity \(commodity): \(error.localizedDescription) in \(sourceLocation(directive))")
            }
        }
    }

    static func addAccounts(
        _ directives: [DirectiveRecord],
        postingAccounts: [String],
        options: [OptionRecord],
        to builder: LedgerBuilder,
        diagnostics: inout [String]
    ) -> Set<String> {
        let declarations = directives.filter { ["open", "close"].contains($0.kind.lowercased()) }
        var grouped = [String: [DirectiveRecord]]()
        var accountOrder = [String]()
        for directive in declarations {
            guard let name = directive.account else { continue }
            if grouped[name] == nil {
                accountOrder.append(name)
            }
            grouped[name, default: []].append(directive)
        }
        for name in postingAccounts where grouped[name] == nil {
            accountOrder.append(name)
            grouped[name] = []
        }
        var unrepresentable = Set<String>()
        let defaultBooking = options.first { $0.name == "booking_method" }?.value
        for name in accountOrder {
            guard let accountDeclarations = grouped[name] else { continue }
            guard let account = makeAccount(name, declarations: accountDeclarations, defaultBooking: defaultBooking, diagnostics: &diagnostics) else {
                unrepresentable.insert(name)
                continue
            }
            do {
                try builder.add(account)
            } catch {
                diagnostics.append("Error with account \(name): \(error.localizedDescription)")
            }
        }
        return unrepresentable
    }

    static func addPricesAndBalances(_ directives: [DirectiveRecord], to builder: LedgerBuilder, diagnostics: inout [String]) {
        for directive in directives {
            if directive.kind.lowercased() == "price" {
                addPrice(directive, to: builder, diagnostics: &diagnostics)
            } else if directive.kind.lowercased() == "balance" {
                addBalance(directive, to: builder, diagnostics: &diagnostics)
            }
        }
    }

    static func addSimpleDirectives(_ result: LedgerResult, to builder: LedgerBuilder) {
        builder.option = result.options.map { Option(name: $0.name, value: $0.value) }
        builder.plugins = result.plugins.map(\.name)
        for directive in result.directives {
            guard let date = date(from: directive) else { continue }
            if directive.kind.lowercased() == "event", let name = directive.name, let value = directive.value {
                let event = Event(date: date, name: name, value: value, metaData: metadata(directive.metadata))
                builder.events.append(event)
            } else if directive.kind.lowercased() == "custom", let name = directive.name {
                let values = directive.customValues.map(\.value)
                builder.custom.append(Custom(date: date, name: name, values: values, metaData: metadata(directive.metadata)))
            }
        }
    }

    static func amount(_ record: AmountRecord?) throws -> Amount {
        guard let record,
              let decimal = Decimal(string: record.number, locale: Locale(identifier: "en_US_POSIX")),
              !decimal.isNaN,
              let scale = Int(exactly: record.scale), scale >= 0 else {
            throw ProjectionError.invalidAmount
        }
        var mutableDecimal = decimal
        let roundTripped = NSDecimalString(&mutableDecimal, Locale(identifier: "en_US_POSIX"))
        guard Decimal(string: roundTripped, locale: Locale(identifier: "en_US_POSIX")) == decimal else {
            throw ProjectionError.invalidAmount
        }
        return Amount(number: decimal, commoditySymbol: record.currency, decimalDigits: scale)
    }

    static func exactWeight(_ record: AmountRecord?) throws -> MultiCurrencyAmount {
        let value = try amount(record)
        return value.multiCurrencyAmount
    }

    static func date(from directive: DirectiveRecord) -> Date? {
        guard directive.dateYear > 0, (1...12).contains(directive.dateMonth), (1...31).contains(directive.dateDay) else {
            return nil
        }
        var components = DateComponents()
        components.calendar = Calendar.current
        components.year = Int(directive.dateYear)
        components.month = Int(directive.dateMonth)
        components.day = Int(directive.dateDay)
        components.hour = 0
        components.minute = 0
        guard components.isValidDate(in: Calendar.current) else {
            return nil
        }
        return Calendar.current.date(from: components)
    }

    static func parseDate(_ value: String) -> Date? {
        let components = value.split(separator: "-").compactMap { Int($0) }
        guard components.count == 3 else {
            return nil
        }
        var date = DateComponents()
        date.calendar = Calendar.current
        date.year = components[0]
        date.month = components[1]
        date.day = components[2]
        date.hour = 0
        date.minute = 0
        guard date.isValidDate(in: Calendar.current) else {
            return nil
        }
        return Calendar.current.date(from: date)
    }

    static func metadata(_ values: [MetadataRecord]) -> [String: String] {
        Dictionary(values.map { ($0.key, $0.value) }) { _, latest in latest }
    }

    static func diagnosticMessage(_ record: DiagnosticRecord) -> String {
        let location: String
        if let path = record.path, let line = record.line {
            location = " in \(path) line \(line)"
        } else if let line = record.line {
            location = " in line \(line)"
        } else {
            location = ""
        }
        return "\(record.message)\(location)"
    }

    static func sourceLocation(_ record: DirectiveRecord) -> String {
        "source \(record.sourceFileId) bytes \(record.startByte)-\(record.endByte)"
    }

    private static func addPrice(_ directive: DirectiveRecord, to builder: LedgerBuilder, diagnostics: inout [String]) {
        guard let date = date(from: directive), let symbol = directive.currency,
              let price = try? amount(directive.amount),
              let modelPrice = try? Price(
                date: date,
                commoditySymbol: symbol,
                amount: price,
                metaData: metadata(directive.metadata)
              ) else {
            diagnostics.append("RustLedger could not represent a price declaration (\(sourceLocation(directive))).")
            return
        }
        do {
            try builder.add(modelPrice)
        } catch {
            diagnostics.append("Error with price \(modelPrice): \(error.localizedDescription) in \(sourceLocation(directive))")
        }
    }

    private static func addBalance(_ directive: DirectiveRecord, to builder: LedgerBuilder, diagnostics: inout [String]) {
        guard let date = date(from: directive), let name = directive.account,
              let accountName = try? AccountName(name), let expected = try? amount(directive.amount) else {
            diagnostics.append("RustLedger could not represent a balance assertion (\(sourceLocation(directive))).")
            return
        }
        let balance = Balance(
            date: date,
            accountName: accountName,
            amount: expected,
            metaData: metadata(directive.metadata)
        )
        builder.add(balance)
    }

    private static func makeAccount(
        _ name: String,
        declarations: [DirectiveRecord],
        defaultBooking: String?,
        diagnostics: inout [String]
    ) -> Account? {
        guard let accountName = try? AccountName(name) else {
            diagnostics.append("RustLedger returned an invalid account name: \(name)")
            return nil
        }
        let openings = declarations.filter { $0.kind.lowercased() == "open" }
        let closings = declarations.filter { $0.kind.lowercased() == "close" }
        let open = openings.first
        let close = closings.first
        diagnostics.append(contentsOf: RustLedgerDiagnosticMapper.accountStructureMessages(name, openings: openings, closings: closings))
        if let close, !close.metadata.isEmpty {
            diagnostics.append("Account close directives cannot contain metadata.")
        }
        let currencies = open?.allowedCurrencies ?? []
        guard currencies.count <= 1 else {
            diagnostics.append("Account \(name) restricts postings to multiple currencies, which the Swift model cannot represent.")
            return nil
        }
        guard let booking = bookingMethod(open?.bookingMethod ?? defaultBooking, account: name, diagnostics: &diagnostics) else {
            return nil
        }
        let metadataSource = open ?? declarations.first
        return Account(
            name: accountName,
            bookingMethod: booking,
            commoditySymbol: currencies.first,
            opening: open.flatMap(date(from:)),
            closing: close.flatMap(date(from:)),
            metaData: metadataSource.map { metadata($0.metadata) } ?? [:]
        )
    }

    private static func bookingMethod(_ rawValue: String?, account: String, diagnostics: inout [String]) -> BookingMethod? {
        guard let rawValue else {
            return .strict
        }
        switch rawValue.uppercased() {
        case "STRICT":
            return .strict
        case "FIFO":
            return .fifo
        case "LIFO":
            return .lifo
        default:
            diagnostics.append("Account \(account) uses unsupported booking method \(rawValue), which the Swift model cannot represent.")
            return nil
        }
    }

}
#endif
