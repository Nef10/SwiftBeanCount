# SwiftBeanCountImporter

[![CI Status](https://github.com/Nef10/SwiftBeanCountImporter/workflows/CI/badge.svg?event=push)](https://github.com/Nef10/SwiftBeanCountImporter/actions?query=workflow%3A%22CI%22) [![Documentation percentage](https://nef10.github.io/SwiftBeanCountImporter/badge.svg)](https://nef10.github.io/SwiftBeanCountImporter/) [![License: MIT](https://img.shields.io/github/license/Nef10/SwiftBeanCountImporter)](https://github.com/Nef10/SwiftBeanCountImporter/blob/main/LICENSE) [![Latest version](https://img.shields.io/github/v/release/Nef10/SwiftBeanCountImporter?label=SemVer&sort=semver)](https://github.com/Nef10/SwiftBeanCountImporter/releases) ![platforms supported: linux | macOS | iOS | watchOS | tvOS](https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS-blue) ![SPM compatible](https://img.shields.io/badge/SPM-compatible-blue)

### ***This project is part for SwiftBeanCount, please check out the main documentation [here](https://github.com/Nef10/SwiftBeanCount).***

## What

This is the importer of SwiftBeanCount. It reads files to create transactions. This library does not include any UI, so consumers need to provide a UI for selecting accounts, settings, as well as editing of transactions.

## How to use

### Import Transactions

1) Create a `FileImporter` via `ImporterFactory.new(ledger: Ledger?, url: URL?)` or a `Importer` via `ImporterFactory.new(ledger: Ledger?, transaction: String, balance: String)`, depending on what you want to import.
2) Check `possibleAccounts()` on the importer. If there is more than one or none, promt to user to enter/select the account to use.
3) Pass the result to the importer via `useAccount(name:)`.
4) If using a FileImporter call `loadFile()`.
5) If using a TextImporter, call `parse()` to get a string of the parsed transactions. If using a FileImporter, call `parseLineIntoTransaction()` to retrive transaction after transactions till it returns `nil`. It is recommended to allow the user the edit the transactions while doing this. (See [#2](https://github.com/Nef10/SwiftBeanCountImporter/issues/2))

### Settings

The different importers which are included in this library can be configured:

1) Call `ImporterFactory.allImporters` to retreive all importers
2) Call `importer.settingsName` to get the user friendly name of the importer
3) Call `importer.settings` to get the `ImporterSetting`s which an importer offers
3) Use `importer.get(setting: ImporterSetting)` and `importer.set(setting: ImporterSetting, to value: String)` to modify these settings.

Please check out the complete documentation [here](https://nef10.github.io/SwiftBeanCountImporter/), or have a look at the [SwiftBeanCountImporterApp](https://github.com/Nef10/SwiftBeanCountImporterApp/) which uses this library.

## Usage

The library supports the Swift Package Manger, so simply add a dependency in your `Package.swift`:

```
.package(url: "https://github.com/Nef10/SwiftBeanCountImporter.git", .exact("X.Y.Z")),
```

*Note: as per semantic versioning all versions changes < 1.0.0 can be breaking, so please use `.exact` for now*
