# ``SwiftBeanCountRitualMapper``

Convert completed Ritual receipts into Ledger transactions.

## Ledger configuration

Add `ritual-role` metadata to exactly one account for each role. Accounts must allow CAD (or have no commodity restriction); the expense role must be an expense account, and both funding roles must be income accounts. For example:

```beancount
2020-01-01 open Expenses:Food:TakeOut CAD
  ritual-role: "expense"
2020-01-01 open Income:Salary:Benefits:Lunch CAD
  ritual-role: "company-benefit"
2020-01-01 open Income:BonusProgram CAD
  ritual-role: "bonus-program"
```

## Receipt translation

The largest individual voucher of at most CAD 25 funds `company-benefit`. Only one voucher qualifies, including when values tie. All other vouchers and applied credits fund `bonus-program`.
The merchant becomes the payee. 
Narration uses main item names with trimmed whitespace and separated by `;`, while trying to clean it up by removing:
* Variants
* Packaging-choice questions such as `Would you like a take-away bag?`
* Remove Menu prefixes such as `6)`
* Trailing lables like `[GF]` / `(GF)`
* and more

Entirely uppercase names become title case.

The receipt ID is stored as `ritual-id`, and IDs already in the ledger are skipped.

## Payment matching

If there is a payment associated with the transaction, the mapper tries to find it if it already exists in the ledger. Matching uses merchant, the exact CAD card-paid amount, and the configured date tolerance. A unique match becomes `possibleDuplicate`; multiple matches fail rather than selecting one.

The replacement preserves the bank payment's date, flag, tags, metadata, expense category, posting metadata, and unrelated/shared postings. Voucher and credit funding is added to its existing expense posting, preserving the bank payment and any receivable allocations. The original payee/narration are retained in metadata when changed, and a differing receipt date is stored as `ritual-order-date`.

## Usage

Choose **Ritual Download** from `ImporterFactory` and provide the usual importer delegate. It reuses saved credentials or signs in using a phone number, embedded verification, and a code delivered by SMS or email as selected by Ritual. It generates device context and saves the session through the credential delegate. Rotated refresh tokens are saved immediately.

The default window starts 60 calendar days before today. Override it using the newest dated setting:

```beancount
2026-01-01 custom "ritual-download-importer" "pastDaysToLoad" "60"
```

Zero loads today only; a larger value requests older history.
