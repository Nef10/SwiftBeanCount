# ``SwiftBeanCountParser``

Parse plain text Beancount files into SwiftBeanCount model objects.

## Overview

***This project is part of SwiftBeanCount, please check out the main documentation [here](https://github.com/Nef10/SwiftBeanCount).***

This is the parser of SwiftBeanCount. It takes a string or a file and returns a `Ledger` (from [SwiftBeanCountModel](https://github.com/Nef10/SwiftBeanCountModel)).

## How to Use

Either call `Parser.parse(contentOf: URL)` or `Parser.parse(string: String)`.

## Usage

The library supports the Swift Package Manager, so simply add a dependency in your `Package.swift`:

```swift
.package(url: "https://github.com/Nef10/SwiftBeanCountParser.git", .exact("X.Y.Z")),
```

*Note: as per semantic versioning all versions changes < 1.0.0 can be breaking, so please use `.exact` for now*

## Topics

### Parsing
