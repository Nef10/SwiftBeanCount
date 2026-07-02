#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Delegate for the TangerineDownloader
public protocol TangerineDownloaderDelegate: AnyObject {

    /// Requests the one time passcode the user received via text while the library is trying to log in
    /// - Returns:
    func getOTPCode() -> String

    #if canImport(UIKit)

    /// Requests a view to add the webview to
    /// - Returns: UIView
    func view() -> UIView?

    #endif
    #if canImport(AppKit)

    /// Requests a view to add the webview to
    /// - Returns: NSView
    func view() -> NSView?

    #endif
}
