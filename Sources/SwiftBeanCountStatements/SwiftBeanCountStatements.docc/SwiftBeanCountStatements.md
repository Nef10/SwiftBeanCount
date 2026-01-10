# ``SwiftBeanCountStatements``

Track and validate statement files for completeness.

## Overview

This is a library to help you track your statement files and check for completeness. Please note right now statement file names must start with `YYMMDD`.

## Beancount Meta Data

The library relies on meta data and custom directives in your Beancount file for configuration.

### Settings

There are two settings you will need to add as custom directive:
```
YYYY-MM-DD custom "statements-settings" "root-folder" "~/Documents/Finance/"
YYYY-MM-DD custom "statements-settings" "file-names" "statement"
```

The first one is the root folder with all your (financial) documents. The code will need access to this folder, and all account folders (see below) must be under this root.

The second one is the file names to check for, set as a space separated list. Please note that it will check for file containing these strings, so `"statement"` will find files named `"yearly statement"` as well.

### Account Meta Data

On each account you want to check add `folder: "Bank/Account"` specifying a folder relative to the root folder where documents for this specific account are. There are no specific requirements for the folder structure, expect it being under the root folder.

If you want to have a `folder` meta data set on the account for other purposes but not trigger the statement check, add `statements: "disable"`.

## How to Use

1) Load your ledger, e.g. via  [SwiftBeanCountParser](https://github.com/Nef10/SwiftBeanCountParser)
2) Call `StatementValidator.getRootFolder`
3) Obtain a security scoped URL for this folder
4) Call `StatementValidator.validate`

The library exposes some of its helper functions used in this validate workflow as well. You can use them directly if you only want to do partial or other custom checks.

## Topics

### Validation
