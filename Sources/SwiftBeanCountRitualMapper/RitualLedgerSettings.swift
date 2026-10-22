import SwiftBeanCountModel

struct RitualLedgerSettings {
    let expense: AccountName
    let companyBenefit: AccountName
    let bonusProgram: AccountName

    init(ledger: Ledger) throws {
        expense = try Self.account(for: "expense", type: .expense, ledger: ledger)
        companyBenefit = try Self.account(for: "company-benefit", type: .income, ledger: ledger)
        bonusProgram = try Self.account(for: "bonus-program", type: .income, ledger: ledger)
    }

    private static func account(for role: String, type: AccountType, ledger: Ledger) throws -> AccountName {
        let accounts = ledger.accounts.filter { $0.metaData["ritual-role"] == role }
        guard accounts.count == 1, let account = accounts.first, account.name.accountType == type,
            account.commoditySymbol == nil || account.commoditySymbol == "CAD"
        else {
            throw RitualMappingError.invalidRole(role)
        }
        return account.name
    }
}
