# SwiftBeanCountCompassCardMapper

[![CI Status](https://github.com/Nef10/SwiftBeanCountCompassCardMapper/workflows/CI/badge.svg?event=push)](https://github.com/Nef10/SwiftBeanCountCompassCardMapper/actions?query=workflow%3A%22CI%22) [![Documentation percentage](https://nef10.github.io/SwiftBeanCountCompassCardMapper/badge.svg)](https://nef10.github.io/SwiftBeanCountCompassCardMapper/) [![License: MIT](https://img.shields.io/github/license/Nef10/SwiftBeanCountCompassCardMapper)](https://github.com/Nef10/SwiftBeanCountCompassCardMapper/blob/main/LICENSE) [![Latest version](https://img.shields.io/github/v/release/Nef10/SwiftBeanCountCompassCardMapper?label=SemVer&sort=semver)](https://github.com/Nef10/SwiftBeanCountCompassCardMapper/releases) ![platforms supported: linux | macOS | iOS | watchOS | tvOS](https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS-blue) ![SPM compatible](https://img.shields.io/badge/SPM-compatible-blue)

### ***This project is part for SwiftBeanCount, please check out the main documentation [here](https://github.com/Nef10/SwiftBeanCount).***

## What

This is a small library to convert downloaded data from a Compass Card (via [CompassCardDownloader](https://github.com/Nef10/CompassCardDownloader)) to the Beancount format (via [SwiftBeanCountModel](https://github.com/Nef10/SwiftBeanCountModel)).

## Beancount meta data

The library relies on meta data in your Beancount file to find your accounts. Please add `importer-type: "compass-card"` and `card-number: "XXXXXXXXXXXXXXXXXXXX"` to your Compass Card Asset account. To automatically add the expense account, add `compass-card-expense: "XXXXXXXXXXXXXXXXXXXX"` with the card number to an account - for auto load, use `compass-card-load: "XXXXXXXXXXXXXXXXXXXX"`.

## How

1) Load your ledger, e.g. via  [SwiftBeanCountParser](https://github.com/Nef10/SwiftBeanCountParser)
2) Create an instance of `SwiftBeanCountCompassCardMapper` using the ledger
3) Dowload the balance and transactions you want to convert via the [CompassCardDownloader](https://github.com/Nef10/CompassCardDownloader)
4) Use `createBalance` and `createTransactions` on the mapper to convert the downloaded data

Please also check out the complete documentation [here](https://nef10.github.io/SwiftBeanCountCompassCardMapper/).

## Usage

The library supports the Swift Package Manger, so simply add a dependency in your `Package.swift`:

```
.package(url: "https://github.com/Nef10/SwiftBeanCountCompassCardMapper.git", .exact(from: "X.Y.Z")),
```

*Note: as per semantic versioning all versions changes < 1.0.0 can be breaking, so please use `.exact` for now*

## Copyright

While my code is licensed under the [MIT License](https://github.com/Nef10/SwiftBeanCountCompassCardMapper/blob/main/LICENSE), the source repository may include names or other trademarks of CompassCard, TransLink or other entities; potential usage restrictions for these elements still apply and are not touched by the software license. Same applies for the API design. I am in no way affilliated with TransLink other than beeing customer.
