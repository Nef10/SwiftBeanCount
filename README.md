# SwiftBeanCountRogersBankMapper

[![CI Status](https://github.com/Nef10/SwiftBeanCountRogersBankMapper/workflows/CI/badge.svg?event=push)](https://github.com/Nef10/RogersBankDownloader/actions?query=workflow%3A%22CI%22) [![Documentation percentage](https://nef10.github.io/SwiftBeanCountRogersBankMapper/badge.svg)](https://nef10.github.io/SwiftBeanCountRogersBankMapper/) [![License: MIT](https://img.shields.io/github/license/Nef10/SwiftBeanCountRogersBankMapper)](https://github.com/Nef10/SwiftBeanCountRogersBankMapper/blob/main/LICENSE) [![Latest version](https://img.shields.io/github/v/release/Nef10/SwiftBeanCountRogersBankMapper?label=SemVer&sort=semver)](https://github.com/Nef10/SwiftBeanCountRogersBankMapper/releases) ![platforms supported: linux | macOS | iOS | watchOS | tvOS](https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS-blue) ![SPM compatible](https://img.shields.io/badge/SPM-compatible-blue)

### ***This project is part for SwiftBeanCount, please check out the main documentation [here](https://github.com/Nef10/SwiftBeanCount).***

## What

This is a small library to convert downloaded data from Wealthsimple (via [RogersBankDownloader](https://github.com/Nef10/RogersBankDownloader)) to the Beancount format (via [SwiftBeanCountModel](https://github.com/Nef10/SwiftBeanCountModel)).

## Beancount meta data

The library relies on meta data in your Beancount file to find your accounts. Please add `importer-type: "rogers"` and `last-four: "XXXX"` with the last four digits of your number to your Credit Card Liability account.

## How

1) Load your ledger, e.g. via  [SwiftBeanCountParser](https://github.com/Nef10/SwiftBeanCountParser)
2) Create an instance of `SwiftBeanCountRogersBankMapper` using the ledger
3) Dowload the accounts and activities you want to convert via the [RogersBankDownloader](https://github.com/Nef10/RogersBankDownloader)
4) Use `mapAccountToBalance` and `mapActivitiesToTransactions` on the mapper to convert the downloaded data

Please also check out the complete documentation [here](https://nef10.github.io/SwiftBeanCountRogersBankMapper/).

## Usage

The library supports the Swift Package Manger, so simply add a dependency in your `Package.swift`:

```
.package(url: "https://github.com/Nef10/SwiftBeanCountRogersBankMapper.git", .exact(from: "X.Y.Z")),
```

*Note: as per semantic versioning all versions changes < 1.0.0 can be breaking, so please use `.exact` for now*
