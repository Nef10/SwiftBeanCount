#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Delegate for the CompassCardDownloader
public protocol CompassCardDownloaderDelegate: AnyObject {

    #if canImport(UIKit)

    /// Requests a view to add the webview to
    /// - Returns: UIView
    func view() -> UIView?

    #else

    /// Requests a view to add the webview to
    /// - Returns: NSView
    func view() -> NSView?

    #endif
}
