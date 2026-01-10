# ``SwiftBeanCountCompassCardMapper``

Convert Compass Card data to Beancount format.

## Overview

This is a small library to convert downloaded data from a Compass Card (via [CompassCardDownloader](https://github.com/Nef10/CompassCardDownloader)) to the Beancount format (via [SwiftBeanCountModel](/SwiftBeanCount/documentation/swiftbeancountmodel)).

## Beancount Meta Data

The library relies on meta data in your Beancount file to find your accounts. Please add the following two attributes to your Compass Card Asset account:
```
importer-type: "compass-card"`
card-number: "XXXXXXXXXXXXXXXXXXXX"
```

Optionally, to configure the expense account, add `compass-card-expense: "XXXXXXXXXXXXXXXXXXXX"` with the card number to an account. To confgiure the account a load is coming from, use `compass-card-load: "XXXXXXXXXXXXXXXXXXXX"`.

## How to Use

1) Load your ledger, e.g. via  [SwiftBeanCountParser](/SwiftBeanCount/documentation/swiftbeancountparser)
2) Create an instance of `SwiftBeanCountCompassCardMapper` using the ledger
3) Download the balance and transactions you want to convert via the [CompassCardDownloader](https://github.com/Nef10/CompassCardDownloader)
4) Use `createBalance` and `createTransactions` on the mapper to convert the downloaded data

For more details, check out the code of the `CompassCardDownloadImporter` file in the SwiftBeanCountImporter.
