# SwiftBeanCountTax

[![CI Status](https://github.com/Nef10/SwiftBeanCountTax/workflows/CI/badge.svg?event=push)](https://github.com/Nef10/SwiftBeanCountTax/actions?query=workflow%3A%22CI%22) [![Documentation percentage](https://nef10.github.io/SwiftBeanCountTax/badge.svg)](https://nef10.github.io/SwiftBeanCountTax/) [![License: MIT](https://img.shields.io/github/license/Nef10/SwiftBeanCountTax)](https://github.com/Nef10/SwiftBeanCountTax/blob/main/LICENSE) [![Latest version](https://img.shields.io/github/v/release/Nef10/SwiftBeanCountTax?label=SemVer&sort=semver)](https://github.com/Nef10/SwiftBeanCountTax/releases) ![platforms supported: linux | macOS | iOS | watchOS | tvOS](https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS-blue) ![SPM compatible](https://img.shields.io/badge/SPM-compatible-blue)

### ***This project is part for SwiftBeanCount, please check out the main documentation [here](https://github.com/Nef10/SwiftBeanCount).***

## What

This is a library to help you during tax season. Right now it can list taxable sales and generate expected tax slips based on your beancount file. This allows you to easily verify your received tax slips to check for errors on either the providers side or your tracking.

## Beancount meta data

The library relies on meta data and custom directives in your Beancount file for configuration.

### Taxable Sales

On the account you are selling from, add the `"tax-sale"` meta data, specifing the name the sales should show be grouped by, usually the brokers name.

### Tax Slips

#### Basic Configuration

* You first must configure the names of the slips you want to generate, and set a currency for each one
* Afterwards, add meta data to the account in the form of tax slip name: Box name + number
* Optionally, you can add a tax slip issuer, e.g. if you receive the same slip from multiple institutions - if no issuer is set, all amounts for the same slip and box will be added together

Example:

```
2020-01-01 custom "tax-slip-settings" "slip-names" "t3" "t5"
2020-01-01 custom "tax-slip-settings" "slip-currency" "t3" "CAD"
2020-01-01 custom "tax-slip-settings" "slip-currency" "t5" "CAD"

2020-01-01 open Income:Interest:Taxable:BankABC CAD
  t5: "Interest from Canadian sources (Box 13)"
  tax-slip-issuer: "BankABC"
```

#### Split Slips by Symbol

Some tax slips are split up by individual stock / ETF. To configure this, either the last or second last part of the account name must match a configured commodity or you add `tax-symbol` meta-data to the account.

Aditionally to the symbol, you can add a description. For a commodity add `name` or on an account the `tax-description` meta data.

Example:

```
2020-01-01 commodity ETFABC
  name: "ETF ABC @ Exchange"

2020-01-01 open Income:Dividend:Taxable:ETFABC:ForeignNonBusinessIncome CAD
  t3: "Foreign Non-Business Income (Box 25)"

2020-01-01 open Income:Dividend:Taxable:Portfolio:Other CAD
  t3: "Other Income (Box 26)"
  tax-symbol: "StockTicker"
  tax-description: "Stock @ Exchange"
```
If your account has the name matching to a commodity, but you don't want to treat it as one, add `tax-symbol: ""` to it.

#### Split accounts

Sometimes, if you split up your slip by stock, you don't want to create a separate account for everything. E.g. you track the dividends via different income accounts, but don't want to create separate expense accounts per stock for tax paid. To do this:

1. Configure the tax slip and box via a customs directive instead of account meta data, as shown below
1. Make sure the transaction with the posting to this account has another posting from an account configured via meta data for the same tax slip
1. Make sure the other account has a symbol configured

Example:

```
2020-01-01 custom "tax-slip-settings" "account" "t3" "Foreign Non-Business Income Tax paid (Box 34)" "Expenses:Tax:ForeignNonBusiness"

2020-01-01 * "" ""
  Income:Dividend:Taxable:ETFABC:ForeignNonBusinessIncome 10.00 CAD
  Expenses:Tax:ForeignNonBusiness -2.50 CAD
  Assets:Portfolio 7.50 CAD
```

If multiple custom directives for the same setting exist, the latest one up until the end of the tax year is used. E.g. when generating tax slips for 2021, the latest directive up until 2021-12-31 is used.

### Dates

Sometimes income is earned in one year, but only paid in another; or a sale is performed in one year but only settled in the next. You can change the year a transaction should count towards via the `tax-year` meta data on a transaction, e.g. `tax-year: "2022"`.

## How

1) Load your ledger, e.g. via  [SwiftBeanCountParser](https://github.com/Nef10/SwiftBeanCountParser)
2) Call one of the public functions on `TaxCalculator`, for example:
    1) `TaxCalculator.generateTaxSlips(from ledger: Ledger, for year: Int)`
    2) `TaxCalculator.getTaxableSales(from ledger: Ledger, for year: Int)`

Please also check out the complete documentation [here](https://nef10.github.io/SwiftBeanCountTax/).

## Usage

The library supports the Swift Package Manger, so simply add a dependency in your `Package.swift`:

```
.package(url: "https://github.com/Nef10/SwiftBeanCountTax.git", .exact(from: "X.Y.Z")),
```

*Note: as per semantic versioning all versions changes < 1.0.0 can be breaking, so please use `.exact` for now*
