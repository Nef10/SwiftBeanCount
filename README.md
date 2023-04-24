# SwiftBeanCountParser

[![CI Status](https://github.com/Nef10/SwiftBeanCountParser/workflows/CI/badge.svg?event=push)](https://github.com/Nef10/SwiftBeanCountParser/actions?query=workflow%3A%22CI%22) [![Documentation percentage](https://nef10.github.io/SwiftBeanCountParser/badge.svg)](https://nef10.github.io/SwiftBeanCountParser/) [![License: MIT](https://img.shields.io/github/license/Nef10/SwiftBeanCountParser)](https://github.com/Nef10/SwiftBeanCountParser/blob/main/LICENSE) [![Latest version](https://img.shields.io/github/v/release/Nef10/SwiftBeanCountParser?label=SemVer&sort=semver)](https://github.com/Nef10/SwiftBeanCountParser/releases) ![platforms supported: linux | macOS | iOS | watchOS | tvOS](https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS-blue) ![SPM compatible](https://img.shields.io/badge/SPM-compatible-blue)

### ***This project is part for SwiftBeanCount, please check out the main documentation [here](https://github.com/Nef10/SwiftBeanCount).***

## What

This is the parser of SwiftBeanCount. It takes a string or a file and returns a `Ledger` (from [SwiftBeanCountModel](https://github.com/Nef10/SwiftBeanCountModel)).

## How

Either call `Parser.parse(contentOf: URL)` or `Parser.parse(string: String)`. You can check out the complete documentation [here](https://nef10.github.io/SwiftBeanCountParser/).

## Usage

The library supports the Swift Package Manger, so simply add a dependency in your `Package.swift`:

```
.package(url: "https://github.com/Nef10/SwiftBeanCountParser.git", .exact("X.Y.Z")),
```

*Note: as per semantic versioning all versions changes < 1.0.0 can be breaking, so please use `.exact` for now*
