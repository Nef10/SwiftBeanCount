# ``SwiftBeanCountParser``

Parse plain text Beancount files into [SwiftBeanCountModel](/SwiftBeanCount/documentation/swiftbeancountmodel) objects.

## Overview

This is the parser of SwiftBeanCount. It takes a string or a file and returns a `Ledger` (from SwiftBeanCountModel).

## How to Use

Either call `Parser.parse(contentOf: URL)` or `Parser.parse(string: String)`.
