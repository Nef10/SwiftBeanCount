# ``RitualDownloader``

Download order history and detailed receipts from Ritual.

## Overview

This is a small library to sign in to Ritual and download completed orders and their detailed receipts. It handles authentication, saved sessions and pagination, and returns structured receipt data.

To convert the downloaded receipts to Beancount transactions, use [SwiftBeanCountRitualMapper](/SwiftBeanCount/documentation/swiftbeancountritualmapper).

## How to Use

1) Create an instance of ``RitualDownloader``.
2) Implement ``RitualDownloaderDelegate`` and assign it to the downloader's `delegate` property. The delegate supplies credential storage, phone number and verification code input, and a view for browser verification.
3) Call `download(since:knownReceiptIDs:)` with the earliest date to load and any receipt IDs already imported.
4) Use the returned `receipts` and review any individual receipt `failures`.

```swift
let downloader = RitualDownloader()
downloader.delegate = host
let result = try await downloader.download(
    since: cutoff,
    knownReceiptIDs: importedReceiptIDs
)
```

Keep the delegate alive for the duration of the download. For an example of integrating this library, see `RitualDownloadImporter` in [SwiftBeanCountImporter](/SwiftBeanCount/documentation/swiftbeancountimporter).

## Authentication

The downloader reuses a saved session when available. Otherwise, it asks for a phone number, presents browser verification, and requests a six-digit code sent by SMS or email. Browser verification requires a UIKit or AppKit view.

The delegate stores `ritual-phone-number`, `ritual-device-id`, `ritual-device-context` and `ritual-refresh-token`. Use protected credential storage. Rotated refresh tokens are saved immediately, and an expired saved session triggers one new sign-in attempt.

## Downloading

The downloader loads each history page's eligible receipts before requesting the next page, stopping when it reaches the date cutoff or the end of the history. Known receipt IDs are skipped.

Each API request produces progress output, with a 500 ms wait between requests. Responses are processed in memory. Unavailable or undecodable receipts are reported in `failures`; other request errors stop the download. ``RitualResponseDecoder`` can also decode previously saved protobuf responses offline.
