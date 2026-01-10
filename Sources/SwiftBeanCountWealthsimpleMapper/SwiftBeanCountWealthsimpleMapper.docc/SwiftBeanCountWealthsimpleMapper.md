# ``SwiftBeanCountWealthsimpleMapper``

Convert Wealthsimple account data to Beancount format.

## Overview

This is a small library to convert downloaded data from Wealthsimple (via [WealthsimpleDownloader](https://github.com/Nef10/WealthsimpleDownloader)) to the Beancount format (via [SwiftBeanCountModel](https://github.com/Nef10/SwiftBeanCountModel)).

## Limitations

1. Renames of stock tickers are not imported.
1. Return of capital and non cash distributions are also not imported, as these usually appear very late.

## Beancount Meta Data

The library relies heavily on meta data in your Beancount file to find accounts and commodities. Please add these to your Beancount file:

### Commodities

If the commodity in your ledger differs from the symbol used by Wealthsimple, simply add `wealthsimple-symbol` as meta data:

```
2011-10-18 commodity ACWVETF
  wealthsimple-symbol: "ACWV"
```

### Accounts

For Wealthsimple accounts themselves, you need to add this metadata: `importer-type: "wealthsimple"` and `number: "XXX"`. If the account can hold more than one commodity (all accounts except chequing and saving), it needs to follow this structure: `Assets:X:Y:Z:CashAccountName`, `Assets:X:Y:Z:CommodityName`, `Assets:X:Y:Z:OtherCommodityName`. The name of the cash account does not matter, but all other account must end with the commodity symbol (see above). Add the `importer-type` and `number` only to the cash account.

For accounts used in transactions to and from your Wealthsimple accounts you need to provide meta data as well. These is in the form of `wealthsimple-key: "accountNumber1 accountNumber2"`. The account number is the same as above, and you can specify one or multiple per key. As keys use these values:

* For dividend income accounts `wealthsimple-dividend-COMMODITYSYMBOL`, e.g. `wealthsimple-dividend-XGRO`
* For the asset account you are using to contribute to registered accounts from, use `wealthsimple-contribution`
* For the asset account you are using to deposit to non-registered accounts from, use `wealthsimple-deposit`
* Use `wealthsimple-fee` on an expense account to track the wealthsimple fees
* Use `wealthsimple-non-resident-withholding-tax` on an expense account for non resident withholding tax
* In case some transaction does not balance within your ledger, an expense account with `wealthsimple-rounding` will get the difference
* If you want to track contribution room, use `wealthsimple-contribution-room` on an asset and expense account (optional, if not set it will not create postings for the contribution room)
* Other values for transaction types you might incur are:
  * `wealthsimple-reimbursement`
  * `wealthsimple-interest`
  * `wealthsimple-withdrawal`
  * `wealthsimple-payment-transfer-in`
  * `wealthsimple-payment-transfer-out`
  * `wealthsimple-transfer-in`
  * `wealthsimple-transfer-out`
  * `wealthsimple-referral-bonus`
  * `wealthsimple-giveaway-bonus`
  * `wealthsimple-refund`
  * `wealthsimple-payment-spend` (optional, will use fallback account if not provided)

### Full Example

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
  wealthsimple-dividend-ACWV: "A001 B002"

2020-07-31 open Assets:Checking:Bank CAD
  wealthsimple-contribution: "A001 B002"

2020-07-31 open Expenses:FinancialInstitutions:Investment:NonRegistered:Fees
  wealthsimple-fee: "A001"

2020-07-31 open Expenses:FinancialInstitutions:Investment:Registered:Fees
  wealthsimple-fee: "B002"

2020-07-31 open Expenses:Tax:NRWT
  wealthsimple-non-resident-withholding-tax: "A001 B002"

2020-07-31 open Assets:TFSAContributionRoom TFSA.ROOM
  wealthsimple-contribution-room: "B002"

2020-07-31 open Expenses:TFSAContributionRoom TFSA.ROOM
  wealthsimple-contribution-room: "B002"
```

## How to Use

1) First create an instance of the mapper via `WealthsimpleLedgerMapper(ledger:)`, passing the ledger which contains the meta data discussed above.
2) Assign the downloaded wealthsimple accounts to the `accounts` property on the mapper.
3) Call `mapPositionsToPriceAndBalance` or `mapTransactionsToPriceAndTransactions` to map your downloaded positions / transactions to SwiftBeanCountModel Prices and Balances / Prices and Transactions.

Additionally, you can have a look at the [SwiftBeanCountImporter](https://github.com/Nef10/SwiftBeanCountImporter) which uses this library.

## Additional Limitations

Please note that I developed this library for my own needs and there may be bugs. It currently has some limitations:

* Sell Gains are not calculated
* In case a transactions does not balance it will not add a rounding posting because SwiftBeanCountModel does not yet fully supporting Beancount rounding

Pull requests to extend the scope or remove limitations are very welcome.

## Topics

### Mapping
