# SwiftBeanCountSheetSync

[![CI Status](https://github.com/Nef10/SwiftBeanCountSheetSync/workflows/CI/badge.svg?event=push)](https://github.com/Nef10/SwiftBeanCountSheetSync/actions?query=workflow%3A%22CI%22) [![Documentation percentage](https://nef10.github.io/SwiftBeanCountSheetSync/badge.svg)](https://nef10.github.io/SwiftBeanCountSheetSync/) [![License: MIT](https://img.shields.io/github/license/Nef10/SwiftBeanCountSheetSync)](https://github.com/Nef10/SwiftBeanCountSheetSync/blob/master/LICENSE) [![Latest version](https://img.shields.io/github/v/release/Nef10/SwiftBeanCountSheetSync?label=SemVer&sort=semver)](https://github.com/Nef10/SwiftBeanCountSheetSync/releases) ![platforms supported: macOS](https://img.shields.io/badge/platform-macOS-blue) ![SPM compatible](https://img.shields.io/badge/SPM-compatible-blue)

### ***This project is part for SwiftBeanCount, please check out the main documentation [here](https://github.com/Nef10/SwiftBeanCount).***

## What

This library synchronizes transactions from Beancount files to a Google Sheets with shared transactions. This is helpful when you share expenses with another person who does not use beancount.

## How to use

1) Create an instance of `Uploader` or `Downloader` depending on which way you want to sync, providing the HTTP URL of the Sheet as well as the file URL of the beancount file.
2) Authenticate the user to Google via [GoogleAuthentication](https://github.com/Nef10/GoogleAuthentication).
2) Call `start` on the instance you created in step 1, passing in the authentication instance from step 2.
3) Your completion handler will get a `SyncResult` if the sync was successful. This will include:
    - the transactions which need to be added (to the sheet for upload or the ledger for download)
    - parsing errors occured while reading the sheet
    - configuration which was used for syncing

Please check out the complete documentation [here](https://nef10.github.io/SwiftBeanCountSheetSync/), or have a look at the [SwiftBeanCountSheetSyncApp](https://github.com/Nef10/SwiftBeanCountSheetSyncApp) which uses this library.

## Beancount meta data

The synchronization relies on meta data in your beancount file for configuration. Please add these to your beancount file.

### General configuration

- `commoditySymbol`: The synchronization only works with one commodity which needs to be specified here
- `account`: Account which is used to keep track of the balance between the people
- `tag`: Tag which is appended to all transactions which are or should be synchronized
- `name`: Your name - this will be used to identify the colunms of the sheet
- `dateTolerance` Tolerance in days which will be used when checking if a transactions already exists

These options are specified globally via `customs` like this (the date does not matter and will be ignored):

```
YYYY-MM-DD custom "sheet-sync-settings" "commoditySymbol" "CAD"
```

### Account configuration

You can attatch `sheet-sync-category` metadata to accounts to map categories from the sheet to accounts and vice-versa in a 1-1 relationship. This is optional, in case no mapping could be found a fallback account / an empty category will be used.

Example:

```
2020-12-26 open Expenses:Communication:Internet
  sheet-sync-category: "Internet"
```

## Usage

The library supports the Swift Package Manger, so simply add a dependency in your `Package.swift`:

```
.package(url: "https://github.com/Nef10/SwiftBeanCountSheetSync.git", .upToNextMajor(from: "1.0.2")),
```
