# ``SwiftBeanCountRogersBankMapper``

Convert Rogers Bank Credit Card data to Beancount format.

## Overview

***This project is part of SwiftBeanCount, please check out the main documentation [here](https://github.com/Nef10/SwiftBeanCount).***

This is a small library to convert downloaded data from a Rogers Bank Credit Card (via [RogersBankDownloader](https://github.com/Nef10/RogersBankDownloader)) to the Beancount format (via [SwiftBeanCountModel](https://github.com/Nef10/SwiftBeanCountModel)).

## Beancount Meta Data

The library relies on meta data in your Beancount file to find your accounts. Please add `importer-type: "rogers"` and `last-four: "XXXX"` with the last four digits of your number to your Credit Card Liability account.

## How to Use

1) Load your ledger, e.g. via  [SwiftBeanCountParser](https://github.com/Nef10/SwiftBeanCountParser)
2) Create an instance of `SwiftBeanCountRogersBankMapper` using the ledger
3) Download the accounts and activities you want to convert via the [RogersBankDownloader](https://github.com/Nef10/RogersBankDownloader)
4) Use `mapAccountToBalance` and `mapActivitiesToTransactions` on the mapper to convert the downloaded data

## Usage

The library supports the Swift Package Manager, so simply add a dependency in your `Package.swift`:

```swift
.package(url: "https://github.com/Nef10/SwiftBeanCountRogersBankMapper.git", .exact(from: "X.Y.Z")),
```

*Note: as per semantic versioning all versions changes < 1.0.0 can be breaking, so please use `.exact` for now*

## Topics

### Mapping
