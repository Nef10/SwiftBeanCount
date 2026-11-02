import Foundation
@testable import SwiftBeanCountModel
import Testing

struct LedgerSnapshotTests {
    @Test
    func reusingSnapshotAccountDoesNotMutateItsBalancesOrDiagnostics() throws {
        let source = LedgerBuilder()
        try source.add(Account(name: TestUtils.cash))
        let originalBalance = Balance(
            date: TestUtils.date20170608,
            accountName: TestUtils.cash,
            amount: Amount(number: 0, commoditySymbol: TestUtils.cad)
        )
        source.add(originalBalance)
        let snapshot = source.build()
        let snapshotAccount = try #require(snapshot.accounts.first)
        #expect(snapshot.errors.isEmpty)

        let reused = LedgerBuilder()
        try reused.add(snapshotAccount)
        let failingBalance = Balance(
            date: TestUtils.date20170609,
            accountName: TestUtils.cash,
            amount: Amount(number: 1, commoditySymbol: TestUtils.cad)
        )
        reused.add(failingBalance)

        #expect(snapshotAccount.balances == [originalBalance])
        #expect(snapshotAccount.validateBalance(in: snapshot) == .valid)
        #expect(snapshot.errors.isEmpty)
        #expect(reused.accounts.first?.balances == [originalBalance, failingBalance])
        let reusedAssets = try #require(reused.accountGroups.first { $0.nameItem == "Assets" })
        #expect(reusedAssets.accounts["Cash"] === reused.accounts.first)
        #expect(!reused.build().errors.isEmpty)
    }

    @Test
    func builderReuseDoesNotMutatePublishedAccountsOrGroups() throws {
        let builder = LedgerBuilder()
        let cash = Account(name: TestUtils.cash)
        try builder.add(cash)
        let firstBalance = Balance(
            date: TestUtils.date20170608,
            accountName: TestUtils.cash,
            amount: Amount(number: 1, commoditySymbol: TestUtils.cad)
        )
        builder.add(firstBalance)
        let firstSnapshot = builder.build()

        builder.add(Balance(
            date: TestUtils.date20170609,
            accountName: TestUtils.cash,
            amount: Amount(number: 2, commoditySymbol: TestUtils.cad)
        ))
        try builder.add(Account(name: try AccountName("Assets:Investments:Brokerage")))
        let secondSnapshot = builder.build()

        let firstCash = try #require(firstSnapshot.accounts.first { $0.name == TestUtils.cash })
        let secondCash = try #require(secondSnapshot.accounts.first { $0.name == TestUtils.cash })
        #expect(firstCash.balances == [firstBalance])
        #expect(secondCash.balances.count == 2)

        let firstAssets = try #require(firstSnapshot.accountGroups.first { $0.nameItem == "Assets" })
        let secondAssets = try #require(secondSnapshot.accountGroups.first { $0.nameItem == "Assets" })
        #expect(firstAssets.children().map(\.nameItem) == ["Cash"])
        #expect(secondAssets.children().map(\.nameItem) == ["Cash", "Investments"])
    }

    @Test
    func bookingIsCompleteBeforeTheFirstDiagnosticRead() throws {
        let (builder, sale) = try lotBuilder()
        let snapshot = builder.build()

        let firstBalance = try sale.balance(in: snapshot)
        #expect(firstBalance.isZeroWithTolerance())
        let firstErrors = snapshot.errors
        #expect(firstErrors.isEmpty)
        #expect(snapshot.ledgerErrors.isEmpty)
        #expect(try sale.balance(in: snapshot) == firstBalance)
        #expect(snapshot.errors == firstErrors)
    }

    private func lotBuilder() throws -> (LedgerBuilder, Transaction) {
        let builder = LedgerBuilder()
        let stock = try AccountName("Assets:Stock")
        try builder.add(Account(name: stock, commoditySymbol: TestUtils.eur, opening: TestUtils.date20170608))
        try builder.add(Account(name: TestUtils.cash, commoditySymbol: TestUtils.usd, opening: TestUtils.date20170608))
        let cost = try Cost(amount: Amount(number: 5, commoditySymbol: TestUtils.usd), date: nil, label: nil)
        let reductionCost = try Cost(amount: nil, date: nil, label: nil)
        let purchase = Transaction(metaData: TransactionMetaData(date: TestUtils.date20170608, narration: "Buy"), postings: [
            Posting(accountName: stock, amount: Amount(number: 2, commoditySymbol: TestUtils.eur), cost: cost),
            Posting(accountName: TestUtils.cash, amount: Amount(number: -10, commoditySymbol: TestUtils.usd)),
        ])
        let sale = Transaction(metaData: TransactionMetaData(date: TestUtils.date20170609, narration: "Sell"), postings: [
            Posting(accountName: stock, amount: Amount(number: -1, commoditySymbol: TestUtils.eur), cost: reductionCost),
            Posting(accountName: TestUtils.cash, amount: Amount(number: 5, commoditySymbol: TestUtils.usd)),
        ])
        builder.add(purchase)
        builder.add(sale)
        return (builder, sale)
    }
}
