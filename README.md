# SwiftBeanCountCLI

[![CI Status](https://github.com/Nef10/SwiftBeanCountCLI/workflows/CI/badge.svg?event=push)](https://github.com/Nef10/SwiftBeanCountCLI/actions?query=workflow%3A%22CI%22) [![License: MIT](https://img.shields.io/github/license/Nef10/SwiftBeanCountCLI)](https://github.com/Nef10/SwiftBeanCountCLI/blob/master/LICENSE) [![Latest version](https://img.shields.io/github/v/release/Nef10/SwiftBeanCountCLI?label=SemVer&sort=semver)](https://github.com/Nef10/SwiftBeanCountCLI/releases) ![platforms supported: linux | macOS](https://img.shields.io/badge/platform-linux%20%7C%20macOS-blue)

### ***This project is part for SwiftBeanCount, please check out the main documentation [here](https://github.com/Nef10/SwiftBeanCount).***

## What

This is the command line tool of SwiftBeanCount.

## Usage

As this is currently an alpha version, it only supports this very limited list of functions:

* `check` Parses your ledger and prints any errors it finds
* `stats` Statistics of a ledger (e.g. # of transactions)
* `accounts` Print all accounts

## Installation

This executable is built using the Swift Package Manger, so it can be installed via [Mint](https://github.com/yonaskolb/Mint):

```
mint install Nef10/SwiftBeanCountCLI
```