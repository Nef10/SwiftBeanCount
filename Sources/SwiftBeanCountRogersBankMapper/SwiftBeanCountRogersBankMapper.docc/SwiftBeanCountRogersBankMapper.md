# ``SwiftBeanCountRogersBankMapper``

Convert Rogers Bank Credit Card data to Beancount format.

## Overview

This is a small library to convert downloaded data from a Rogers Bank Credit Card (via [RogersBankDownloader](https://github.com/Nef10/RogersBankDownloader)) to the Beancount format (via [SwiftBeanCountModel](/SwiftBeanCount/documentation/swiftbeancountmodel)).

## Beancount Meta Data

The library relies on meta data in your Beancount file to find your accounts. Please add `importer-type: "rogers"` and `last-four: "XXXX"` with the last four digits of your number to your Credit Card Liability account.

## How to Use

1) Load your ledger, e.g. via  [SwiftBeanCountParser](/SwiftBeanCount/documentation/swiftbeancountparser)
2) Create an instance of `SwiftBeanCountRogersBankMapper` using the ledger
3) Download the accounts and activities you want to convert via the [RogersBankDownloader](https://github.com/Nef10/RogersBankDownloader)
4) Use `mapAccountToBalance` and `mapActivitiesToTransactions` on the mapper to convert the downloaded data
