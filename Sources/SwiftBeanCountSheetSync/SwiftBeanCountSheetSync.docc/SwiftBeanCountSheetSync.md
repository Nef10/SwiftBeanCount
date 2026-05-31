# ``SwiftBeanCountSheetSync``

Synchronize transactions between Beancount files and Google Sheets.

## Overview

This library synchronizes transactions from Beancount files to a Google Sheets with shared transactions. This is helpful when you share expenses with another person who does not use beancount.

## How to Use

1) Create an instance of `Uploader` or `Downloader` depending on which way you want to sync, providing the HTTP URL of the Sheet as well as the file URL of the beancount file.
2) Authenticate the user to Google via [GoogleAuthentication](https://github.com/Nef10/GoogleAuthentication).
2) Call `start` on the instance you created in step 1, passing in the authentication instance from step 2.
3) Your completion handler will get a `SyncResult` if the sync was successful. This will include:
    - the transactions which need to be added (to the sheet for upload or the ledger for download)
    - parsing errors occurred while reading the sheet
    - configuration which was used for syncing
    - an optional `balance` assertion derived from the sheet's `Running Total` column, if that column is present
    - `sheetCells`: sheet-shaped `[[String]]` data with the column headers as the first row. For downloads this contains the kept rows from the live sheet after filtering; for uploads this contains the rows as they should appear in the live sheet format

## Beancount Meta Data

The synchronization relies on meta data in your beancount file for configuration. Please add these to your beancount file.

### General Configuration

- `commoditySymbol`: The synchronization only works with one commodity which needs to be specified here
- `account`: Account which is used to keep track of the balance between the people
- `tag`: Tag which is appended to all transactions which are or should be synchronized
- `name`: Your name - this will be used to identify the columns of the sheet
- `dateTolerance`: Tolerance in days which will be used when checking if a transactions already exists

These options are specified via `customs` like this. When multiple settings exist, the most recent one on or before the transaction date is used:

```
YYYY-MM-DD custom "sheet-sync-settings" "commoditySymbol" "CAD"
```

### Account Configuration

You can attach `sheet-sync-category` metadata to accounts to map categories from the sheet to accounts and vice-versa in a 1-1 relationship. This is optional, in case no mapping could be found a fallback account / an empty category will be used.

Example:

```
2020-12-26 open Expenses:Communication:Internet
  sheet-sync-category: "Internet"
```

## Google Sheet Format

The library supports two **column formats**, detected automatically from the sheet headers. Both formats require the sheet tab to be named `Expenses`.

### Total Amount Format

Uses an explicit `Amount` column and per-person `Part <Name>` columns. The following columns are required to be within columns A–I; other columns are ignored:

| Column | Description |
|--------|-------------|
| `Date` | Date in `yyyy-MM-dd` format |
| `Paid to` or `Payee` | Store name or payee; can be an empty string |
| `Amount` | Total amount paid. See [Supported Number Formats](#supported-number-formats) |
| `Category` | See account configuration above |
| `Part Name1` and `Part Name2` | Each person's share of the expense. `Name1` and `Name2` should be replaced with the actual names. One of the two names must match the `name` configured in the ledger. See [Supported Number Formats](#supported-number-formats) |
| `Who paid` or `Payor` | The name of the person who made the payment. Payment will be allocated based on if this name matches the `name` configured in the ledger |
| `Comment` or `Description` | Free-text note; the column is required but can be empty |

### Share Amount Format

Detected automatically when the `Share Other Person` header is present. Uses a single shared-amount column instead of per-person totals. The following columns are required:

| Column | Description |
|--------|-------------|
| `Date` | Date in `yyyy-MM-dd` format |
| `Payee` or `Paid to` | Store name or payee; can be an empty string |
| `Description` or `Comment` | Free-text note; can be empty |
| `Category` | See account configuration above |
| `Payor` or `Who paid` | The name of the person who made the payment. Payment will be allocated based on if this name matches the `name` configured in the ledger |
| `Share Other Person` | The share owed by the person who did **not** pay. See [Supported Number Formats](#supported-number-formats) |

> Note: The share amount format does not contain a total-amount column. When the `name` person paid, the library derives the total as `2 × Share Other Person` (an equal-split assumption). If a matching ledger transaction already exists — identified by payee, date, and the share amount fitting within the actual total — the actual amounts from the ledger are preserved. Only truly new transactions use the equal-split estimate.

### Supported Number Formats

All amount columns in both column formats accept the following representations:

| Format | Example |
|--------|---------|
| Plain decimal | `30.63` |
| Thousands separator | `1,030.63` |
| Currency symbol only | `$30.63` |
| Currency prefix + symbol | `CA$30.63` |
| Negative (leading minus) | `-30.63`, `-CA$30.63` |
| Accounting negative (parentheses) | `(30.63)`, `(CA$30.63)` |

`.` is required as the decimal separator; `,` is optional as a thousands separator.

### Optional Columns (Both Formats)

| Column | Description |
|--------|-------------|
| `Running Total` | Cumulative balance. When present, the value from the last row is used as a `Balance` assertion on `SyncResult.balance`. The sign of the value is taken as-is; set the `negateRunningTotal` ledger setting to `"true"` to negate it before it is used as the balance amount |

## Monthly vs. Long-Running Behavior

Independently of the column format, the library detects whether a sheet covers a single month or spans multiple months. This affects **upload only** — download always considers all sheet transactions against the full ledger.

- **Monthly behavior**: If 90% or more of the sheet's transactions fall in the same calendar month, only ledger transactions from that month are candidates for upload. This prevents already-synced transactions from other months being re-uploaded. Up to 10% of sheet transactions may fall outside that month (e.g. late entries) and are still downloaded correctly.
- **Long-running behavior**: If the transactions span multiple months (fewer than 90% share a single month), all ledger transactions are candidates for upload.
