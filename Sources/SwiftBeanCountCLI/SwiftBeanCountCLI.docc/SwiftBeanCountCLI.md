# ``SwiftBeanCountCLI``

Command-line interface for SwiftBeanCount.

## Overview

This is the command-line tool of SwiftBeanCount.

## Usage

As this is currently an alpha version, it only supports this very limited list of functions:

* `check` - Parses your ledger and prints any errors it finds
* `stats` - Statistics of a ledger (e.g. # of transactions)
* `accounts` - Print all accounts
* `tax-slips` - Outputs expected tax slips

## Installation

This executable is built using the Swift Package Manager, so it can be installed via [Mint](https://github.com/yonaskolb/Mint):

```bash
mint install Nef10/SwiftBeanCountCLI
```

### Completion

Thanks to the [swift-argument-parser](https://github.com/apple/swift-argument-parser) you can generate autocompletion scripts via `swiftbeancount --generate-completion-script {zsh|bash|fish}`. The exact command for your shell may vary, but for example for zsh with ~/.zfunctions in your fpath you can use:

```bash
swiftbeancount --generate-completion-script zsh > ~/.zfunctions/_swiftbeancount
```

## Topics

### Commands
