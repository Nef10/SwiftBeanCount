# ``SwiftBeanCountParser``

Parse plain text Beancount files into SwiftBeanCount model objects.

## Overview

This is the parser of SwiftBeanCount. It takes a string or a file and returns a `Ledger` (from [SwiftBeanCountModel](https://github.com/Nef10/SwiftBeanCountModel)).

## How to Use

Either call `Parser.parse(contentOf: URL)` or `Parser.parse(string: String)`.

## Topics

### Parsing
