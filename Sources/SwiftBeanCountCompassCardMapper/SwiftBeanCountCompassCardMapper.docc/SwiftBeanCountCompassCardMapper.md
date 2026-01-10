# ``SwiftBeanCountCompassCardMapper``

Convert Compass Card data to Beancount format.

## Overview

This is a small library to convert downloaded data from a Compass Card (via [CompassCardDownloader](https://github.com/Nef10/CompassCardDownloader)) to the Beancount format (via [SwiftBeanCountModel](https://github.com/Nef10/SwiftBeanCountModel)).

## Beancount Meta Data

The library relies on meta data in your Beancount file to find your accounts. Please add `importer-type: "compass-card"` and `card-number: "XXXXXXXXXXXXXXXXXXXX"` to your Compass Card Asset account. To automatically add the expense account, add `compass-card-expense: "XXXXXXXXXXXXXXXXXXXX"` with the card number to an account - for auto load, use `compass-card-load: "XXXXXXXXXXXXXXXXXXXX"`.

## How to Use

1) Load your ledger, e.g. via  [SwiftBeanCountParser](https://github.com/Nef10/SwiftBeanCountParser)
2) Create an instance of `SwiftBeanCountCompassCardMapper` using the ledger
3) Download the balance and transactions you want to convert via the [CompassCardDownloader](https://github.com/Nef10/CompassCardDownloader)
4) Use `createBalance` and `createTransactions` on the mapper to convert the downloaded data

## Copyright

While my code is licensed under the [MIT License](https://github.com/Nef10/SwiftBeanCountCompassCardMapper/blob/main/LICENSE), the source repository may include names or other trademarks of CompassCard, TransLink or other entities; potential usage restrictions for these elements still apply and are not touched by the software license. Same applies for the API design. I am in no way affiliated with TransLink other than being customer.

## Topics

### Mapping
