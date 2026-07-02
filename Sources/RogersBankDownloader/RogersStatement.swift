import Foundation

/// A Statement
public protocol Statement {
    /// Type, e.g. monthly
    var statementType: String { get }
    /// ID of the statement
    var statementId: String { get }
    /// Date the statement was generated
    var statementDate: Date { get }
    /// Date the statement cycle ended
    var cycleDate: Date { get }
    /// Last 4 digits of the credit card number
    var cardLast4: String { get }
}

/// List of available statements
struct Statements: Codable {
    /// Statements
    let monthlyStatements: [RogersStatement]
}

struct RogersStatement: Statement, Codable {
    let statementType: String
    let statementId: String
    let statementDate: Date
    let cycleDate: Date
    let cardLast4: String
}
