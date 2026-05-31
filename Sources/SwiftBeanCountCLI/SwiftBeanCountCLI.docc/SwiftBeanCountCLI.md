# ``SwiftBeanCountCLI``

Command-line interface for SwiftBeanCount.

## Overview

This is the command-line tool of SwiftBeanCount.

## Usage

As this is currently an alpha version, it supports the following commands:

* `check` - Parses your ledger and prints any errors it finds
* `stats` - Statistics of a ledger (e.g. # of transactions)
* `accounts` - Print all accounts
* `tax-slips` - Outputs expected tax slips
* `taxable-sales` - Outputs capital gains from taxable sales

For detailed information about the available commands and options, run `swiftbeancount help <subcommand>`, or view the full reference: <doc:swiftbeancount>

## Installation

This executable is built using the Swift Package Manager, so it can be installed via [Mint](https://github.com/yonaskolb/Mint). Optionally, you can specify a version to use with @version, or use the latest dev with `@main`. By default the latest tagged version is used.

```bash
mint install Nef10/SwiftBeanCount
```

### Completion

Thanks to the [swift-argument-parser](https://github.com/apple/swift-argument-parser) you can generate autocompletion scripts via `swiftbeancount --generate-completion-script {zsh|bash|fish}`. The exact command for your shell may vary, but for example for zsh with ~/.zfunctions in your fpath you can use:

```bash
swiftbeancount --generate-completion-script zsh > ~/.zfunctions/_swiftbeancount
```
