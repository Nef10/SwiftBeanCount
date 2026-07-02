#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Delegate for the CompassCardDownloader
public protocol CompassCardDownloaderDelegate: AnyObject {

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
