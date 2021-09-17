# SwiftBeanCountWealthsimpleMapper

[![CI Status](https://github.com/Nef10/SwiftBeanCountWealthsimpleMapper/workflows/CI/badge.svg?event=push)](https://github.com/Nef10/SwiftBeanCountWealthsimpleMapper/actions?query=workflow%3A%22CI%22) [![Documentation percentage](https://nef10.github.io/SwiftBeanCountWealthsimpleMapper/badge.svg)](https://nef10.github.io/SwiftBeanCountWealthsimpleMapper/) [![License: MIT](https://img.shields.io/github/license/Nef10/SwiftBeanCountWealthsimpleMapper)](https://github.com/Nef10/SwiftBeanCountWealthsimpleMapper/blob/main/LICENSE) [![Latest version](https://img.shields.io/github/v/release/Nef10/SwiftBeanCountWealthsimpleMapper?label=SemVer&sort=semver)](https://github.com/Nef10/SwiftBeanCountWealthsimpleMapper/releases) ![platforms supported: linux | macOS | iOS | watchOS | tvOS](https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS-blue) ![SPM compatible](https://img.shields.io/badge/SPM-compatible-blue)

### ***This project is part for SwiftBeanCount, please check out the main documentation [here](https://github.com/Nef10/SwiftBeanCount).***

## What

This is a small library to convert downloaded data from Wealthsimple (via [WealthsimpleDownloader](https://github.com/Nef10/WealthsimpleDownloader)) to the Beancount format (via [SwiftBeanCountModel](https://github.com/Nef10/SwiftBeanCountModel)).

## Beancount meta data

The library relies heavily on meta data in your Beancount file to find accounts and commodities. Please add these to your Beancount file:

### Commodities

If the commodity in your ledger differs from the symbol used by Wealthsimple, simply add `wealthsimple-symbol` as meta data:

```
2011-10-18 commodity ACWVETF
  wealthsimple-symbol: "ACWV"
```

### Accounts

For Wealthsimple accounts themselves, you need to add this metadata: `importer-type: "wealthsimple"` and `number: "XXX"`. If the account can hold more than one commodity (all accounts except chequing and saving), it needs to follow this structure: `Assets:X:Y:Z:CashAccountName`, `Assets:X:Y:Z:CommodityName`, `Assets:X:Y:Z:OtherCommodityName`. The name of the cash account does not matter, but all other account must end with the commodity symbol (see above). Only add the `importer-type` and `number` to the cash account.

For account used for transaction to and from your Wealthsimple accounts you need to add two meta data entries:
* First is the account type (`wealthsimple-account-type`), you can look up the possible values [here](https://github.com/Nef10/WealthsimpleDownloader/blob/main/Sources/Wealthsimple/Account.swift#L37)
* Second is a key (`wealthsimple-key`), for example:
  * For dividend income accounts this is the symbol as of the stock or ETF
  * For the assset account you are going to contribute from, use `contribution`
  * For the assset account you are going to deposit from, use `deposit`
  * Use `fee` on an expense account to track the wealthsimple fees
  * Use `nonResidentWithholdingTax` on an expense account for the tax
  * In case some transaction does not balance, we will look for an expense account with `rounding`
  * In case you get a refund, add `refund` to an income account
  * If you want to track contribution room, use `contribution-room` on an asset and expense account (optional)

Both keys and types can be space separated in case you have multiple Wealthsimple accounts and for example want to combine the fees into one expense account, or you contribute from the same account.

<details>
  <summary>Full Example</summary>

```
2020-07-31 open Assets:Checking:Wealthsimple CAD
  importer-type: "wealthsimple"
  number: "A001"

2020-07-31 open Assets:Investment:Wealthsimple:TFSA:Parking CAD
  importer-type: "wealthsimple"
  number: "B002"
2020-07-31 open Assets:Investment:Wealthsimple:TFSA:ACWV ACWV
2020-07-31 open Assets:Investment:Wealthsimple:TFSA:XGRO XGRO

2020-07-31 open Income:Capital:Dividend:ACWV USD
  wealthsimple-account-type: "ca_tfsa"
  wealthsimple-key: "ACWV"

2020-07-31 open Assets:Checking:Bank CAD
  wealthsimple-account-type: "ca_tfsa"
  wealthsimple-key: "contribution"

2020-07-31 open Assets:Investment:OtherCompany:TFSA
  wealthsimple-account-type: "ca_tfsa"
  wealthsimple-key: "deposit"

2020-07-31 open Expenses:FinancialInstitutions:Investment:Fees
  wealthsimple-account-type: "ca_tfsa"
  wealthsimple-key: "fee"

2020-07-31 open Expenses:Tax:NRWT
  wealthsimple-account-type: "ca_tfsa"
  wealthsimple-key: "non resident withholding tax"

2020-07-31 open Expenses:Rounding
  wealthsimple-account-type: "ca_tfsa"
  wealthsimple-key: "rounding"

2020-07-31 open Income:FinancialInstitutions
  wealthsimple-account-type: "ca_tfsa"
  wealthsimple-key: "refund"

2020-07-31 open Assets:TFSAContributionRoom TFSA.ROOM
  wealthsimple-account-type: "ca_tfsa"
  wealthsimple-key: "contribution-room"

2020-07-31 open Expenses:TFSAContributionRoom TFSA.ROOM
  wealthsimple-account-type: "ca_tfsa"
  wealthsimple-key: "contribution-room"
````
</details>

## How

Please check out the complete documentation [here](https://nef10.github.io/SwiftBeanCountWealthsimpleMapper/). You can also have a look at the [SwiftBeanCountDownloaderApp](https://github.com/Nef10/SwiftBeanCountDownloaderApp) which uses this library.

## Usage

The library supports the Swift Package Manger, so simply add a dependency in your `Package.swift`:

```
.package(url: "https://github.com/Nef10/SwiftBeanCountWealthsimpleMapper.git", .upToNextMajor(from: "X.Y.Z")),
```

## Limitations

Please note that I developed this library for my own needs and there may be bugs. It currently has some limitations:

* Sell Gains are not calculated
* If transactions do not balance, it will add a rounding posting. However, due to SwiftBeanCountModel not yet fully supporting Beancount rounding, the amount of this posting will likely be 0 and need to be adjusted manually.

Pull requests to extend the scope or remove limitations are very welcome.
