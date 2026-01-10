# ``SwiftBeanCountImporter``

Import transactions from various financial institutions into Beancount format.

## Overview

This is the importer for SwiftBeanCount. It reads files or downloads data to create transactions. This library does not include any UI, so consumers need to provide a UI for selecting accounts, settings, as well as editing of transactions.

## How to Use

### Import Transactions

1) Create an `Importer` via one of the `new` functions on the `ImporterFactory`, depending on what you want to import.
2) Set your `delegate` on the importer.
3) Call `load()` on the importer.
4) Call `nextTransaction()` to retrieve transaction after transactions till it returns `nil`. It is recommended to allow the user to edit the transactions while doing this, as long as `shouldAllowUserToEdit` is true.
5) If the user edits the transaction, and you offer and they accept to save the new mapping, call `saveMapped(description:payee:accountName:)`.
6) Get `balancesToImport()` and `pricesToImport()` from the importer.

### Settings

There are settings for the date tolerance when detecting duplicate transactions, as well as for the mapping the user saved in step 5) of importing transactions. Your app can allow the user to view and edit these via the `Settings` object. Settings are by default stored in `UserDefaults` but you can bring your own `SettingsStorage` by setting `Settings.storage`.

### Help

Each Importer provides a help text. You can access all importers via `ImporterFactory.allImporters`. They each expose an `importerName` and `helpText` on the class.
