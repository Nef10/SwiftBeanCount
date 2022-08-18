# SwiftBeanCountTangerineMapper

[![CI Status](https://github.com/Nef10/SwiftBeanCountTangerineMapper/workflows/CI/badge.svg?event=push)](https://github.com/Nef10/SwiftBeanCountTangerineMapper/actions?query=workflow%3A%22CI%22) [![Documentation percentage](https://nef10.github.io/SwiftBeanCountTangerineMapper/badge.svg)](https://nef10.github.io/SwiftBeanCountTangerineMapper/) [![License: MIT](https://img.shields.io/github/license/Nef10/SwiftBeanCountTangerineMapper)](https://github.com/Nef10/SwiftBeanCountTangerineMapper/blob/main/LICENSE) [![Latest version](https://img.shields.io/github/v/release/Nef10/SwiftBeanCountTangerineMapper?label=SemVer&sort=semver)](https://github.com/Nef10/SwiftBeanCountTangerineMapper/releases) ![platforms supported: linux | macOS | iOS | watchOS | tvOS](https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS-blue) ![SPM compatible](https://img.shields.io/badge/SPM-compatible-blue)

### ***This project is part for SwiftBeanCount, please check out the main documentation [here](https://github.com/Nef10/SwiftBeanCount).***

## What

This is a small library to convert downloaded data from Tangerine (via [TangerineDownloader](https://github.com/Nef10/TangerineDownloader)) to the Beancount format (via [SwiftBeanCountModel](https://github.com/Nef10/SwiftBeanCountModel)).

## Beancount meta data

The library relies on meta data in your Beancount file to find your accounts. For Credit Cards, please add `importer-type: "tangerine-card"` and `last-four: "XXXX"` with the last four digits of your number to your Credit Card Liability account. For other account types (like Checking, Savings, and LOC), please add `importer-type: "tangerine-account"` and `number: "XXXX"` with the account number as meta data to the account in your Beancount file.

## How

1) Load your ledger, e.g. via  [SwiftBeanCountParser](https://github.com/Nef10/SwiftBeanCountParser)
2) Create an instance of `SwiftBeanCountTangerineMapper` using the ledger
3) Dowload the accounts and activities you want to convert via the [TangerineDownloader](https://github.com/Nef10/TangerineDownloader)
4) Use `createBalances` and `createTransactions` on the mapper to convert the downloaded data

Please also check out the complete documentation [here](https://nef10.github.io/SwiftBeanCountTangerineMapper/).

## Usage

The library supports the Swift Package Manger, so simply add a dependency in your `Package.swift`:

```
.package(url: "https://github.com/Nef10/SwiftBeanCountTangerineMapper.git", .exact(from: "X.Y.Z")),
```

*Note: as per semantic versioning all versions changes < 1.0.0 can be breaking, so please use `.exact` for now*

## Copyright

While my code is licensed under the [MIT License](https://github.com/Nef10/SwiftBeanCountTangerineMapper/blob/main/LICENSE), the source repository may include names or other trademarks of Tangerine, Scotiabank or other entities; potential usage restrictions for these elements still apply and are not touched by the software license. Same applies for the API design. I am in no way affilliated with Tangerine other than beeing customer.
