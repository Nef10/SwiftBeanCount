# SwiftBeanCountStatements

[![CI Status](https://github.com/Nef10/SwiftBeanCountStatements/actions/workflows/ci.yml/badge.svg?event=push)](https://github.com/Nef10/SwiftBeanCountStatements/actions/workflows/ci.yml?query=workflow%3ACI) [![Documentation percentage](https://nef10.github.io/SwiftBeanCountStatements/badge.svg)](https://nef10.github.io/SwiftBeanCountStatements/) [![License: MIT](https://img.shields.io/github/license/Nef10/SwiftBeanCountStatements)](https://github.com/Nef10/SwiftBeanCountStatements/blob/main/LICENSE) [![Latest version](https://img.shields.io/github/v/release/Nef10/SwiftBeanCountStatements?label=SemVer&sort=semver)](https://github.com/Nef10/SwiftBeanCountStatements/releases) ![platforms supported: macOS](https://img.shields.io/badge/platform-macOS-blue) ![SPM compatible](https://img.shields.io/badge/SPM-compatible-blue)

### ***This project is part for SwiftBeanCount, please check out the main documentation [here](https://github.com/Nef10/SwiftBeanCount).***

## What

This is a library to help you track your statement files and check for completeness. Please note right now statement file names must start with `YYMMDD`.

## Beancount meta data

The library relies on meta data and custom directives in your Beancount file for configuration.

### Settings

There are two settings you will need to add as custom directive:
```
YYYY-MM-DD custom "statements-settings" "root-folder" "~/Documents/Finance/"
YYYY-MM-DD custom "statements-settings" "file-names" "statement"
```

The first one is the root folder with all your (financial) documents. The code will need access to this folder, and all account folders (see below) must be under this root.

The second one is the file names to check for, set as a space separated list. Please note that it will check for file containing these strings, so `"statement"` will find files named `"yearly statement"` as well.

### Account meta data

On each account you want to check add `folder: "Bank/Account"` specifing a folder relative to the root folder where documents for this specifc account are. There are no specific requirements for the folder structure, expect it beeing under the root folder.

If you want to have a `folder` meta data set on the account for other purposes but not trigger the statement check, add `statements: "disable"`.

## How

1) Load your ledger, e.g. via  [SwiftBeanCountParser](https://github.com/Nef10/SwiftBeanCountParser)
2) Call `StatementValidator.getRootFolder`
3) Obtain a security scoped URL for this folder
4) Call `StatementValidator.validate`

The library exposes some of its helper functions used in this validate workflow as well. You can use them directly if you only want to do partial or other custom checks. Check out the complete documentation [here](https://nef10.github.io/SwiftBeanCountStatements/).

## Usage

The library supports the Swift Package Manger, so simply add a dependency in your `Package.swift`:

```
.package(url: "https://github.com/Nef10/SwiftBeanCountStatements.git", .exact(from: "X.Y.Z")),
```

*Note: as per semantic versioning all versions changes < 1.0.0 can be breaking, so please use `.exact` for now*
