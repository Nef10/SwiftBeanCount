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

## Beancount Meta Data

The synchronization relies on meta data in your beancount file for configuration. Please add these to your beancount file.

### General Configuration

- `commoditySymbol`: The synchronization only works with one commodity which needs to be specified here
- `account`: Account which is used to keep track of the balance between the people
- `tag`: Tag which is appended to all transactions which are or should be synchronized
- `name`: Your name - this will be used to identify the columns of the sheet
- `dateTolerance`: Tolerance in days which will be used when checking if a transactions already exists

These options are specified globally via `customs` like this (the date does not matter and will be ignored):

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

The Google sheet needs to be in a specific format in order to be read. The tab must be named `Expenses`.

The following columns are required to be within columns A-I, other columns are ignored:
- `Date` in yyyy-MM-dd format
- `Paid to` e.g. Store name, can be an empty string
- `Amount` Use `.` as decimal point. `,` to separate thousand is ok, accounting style with brackets for negative values is supported
- `Category` See account configuration above
- `Part Name1` and `Part Name2`. `Name1` and `Name2` should be the name of the people (e.g. replace them). One of them must be the same as configured as name in the ledger (see above). Each column must contain a number which represents the amount this party is paying for the purchase. Same formatting rules as for amount apply.
- `Who paid` One of the two names
- `Comment` While the column is required, it can be an empty string
