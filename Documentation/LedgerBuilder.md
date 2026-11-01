# Ledger construction and immutable snapshots

`LedgerBuilder` collects entries and `build()` returns an immutable `Ledger`. The parser also returns completed snapshots. Existing ledger getters and both `Parser.parse` signatures remain available.

This is a breaking change for callers that add entries or replace collections on `Ledger`.

## Constructing a ledger

Before:

```swift
let ledger = Ledger()
try ledger.add(account)
ledger.add(transaction)
ledger.option.append(Option(name: "operating_currency", value: "CAD"))
```

After:

```swift
let builder = LedgerBuilder()
try builder.add(account)
builder.add(transaction)
builder.option.append(Option(name: "operating_currency", value: "CAD"))
let ledger = builder.build()
```

The builder retains the addition overloads, duplicate checks, and implicit account/commodity/tag creation. Its collection getters can also be used to inspect construction in progress, such as when displaying proposed import output.

`build()` completes booking and validation before returning. The resulting `errors`, `ledgerErrors`, and `parsingErrors` arrays are read-only. Invalid input still produces a snapshot containing diagnostics; publication does not imply that the ledger is valid.

`Ledger()` remains an empty snapshot for callers that need an empty lookup context. Existing entry constructors, including `Transaction`, `Posting`, `Account`, and `Cost`, remain available.

## Updating consumers

| Previous operation | Replacement |
|---|---|
| `ledger.add(...)` | Add to a builder and call `build()`. |
| Change `plugins`, `option`, `events`, or `custom` | Change the builder's corresponding collection before publication. |
| Append parsing errors | Add them to `builder.parsingErrors`, or keep application errors separately. |
| Read errors to trigger booking | Read the completed results; booking has already finished. |
| Change input after constructing a mapper/importer | Construct a new consumer with the new snapshot. |

For example:

```swift
let first = builder.build()
// Add further entries to the builder.
let second = builder.build()
```

`first` retains its original collections, account balances, hierarchy, diagnostics, and accounting results. Consumers retaining it continue to read that version.

Transactions and postings retain their existing read-only reference objects. Building a snapshot does not promise new transaction identities, so identity comparisons remain meaningful within a snapshot. Retain a posting's parent transaction when retaining the posting: its parent link remains unowned.

## Parsing source changes

Use the existing parser entry points to obtain another snapshot after source changes:

```swift
let original = Parser.parse(string: originalSource)
let updated = Parser.parse(string: editedSource)
```

The first result remains unchanged. The app's pending import output uses a builder until entries are ready to be published or exported.
