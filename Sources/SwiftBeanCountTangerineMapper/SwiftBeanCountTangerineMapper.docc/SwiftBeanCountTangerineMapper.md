# ``SwiftBeanCountTangerineMapper``

Convert Tangerine account data to Beancount format.

## Overview

This is a small library to convert downloaded data from Tangerine (via [TangerineDownloader](https://github.com/Nef10/TangerineDownloader)) to the Beancount format (via [SwiftBeanCountModel](/SwiftBeanCount/documentation/swiftbeancountmodel)).

## Beancount Meta Data

The library relies on meta data in your Beancount file to find your accounts. For Credit Cards, please add `importer-type: "tangerine-card"` and `last-four: "XXXX"` with the last four digits of your number to your Credit Card Liability account. For other account types (like Checking, Savings, and LOC), please add `importer-type: "tangerine-account"` and `number: "XXXX"` with the account number as meta data to the account in your Beancount file.

Optionally, you can add `tangerine-interest` with the number of an account (or multiple, space separated) to the metadata of an income account where you want to book the interest. You can also add `tangerine-rewards` with the number of the (savings) account the Credit Card cashback rewards are being deposited to, to the metadata of the income account where you want to book the rewards / cashback income.

## How to Use

1) Load your ledger, e.g. via  [SwiftBeanCountParser](/SwiftBeanCount/documentation/swiftbeancountparser)
2) Create an instance of `SwiftBeanCountTangerineMapper` using the ledger
3) Download the accounts and activities you want to convert via the [TangerineDownloader](https://github.com/Nef10/TangerineDownloader)
4) Use `createBalances` and `createTransactions` on the mapper to convert the downloaded data
