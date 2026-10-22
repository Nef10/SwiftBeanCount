#if canImport(WebKit) && (canImport(UIKit) || canImport(AppKit))
import Foundation
import WebKit
#if canImport(UIKit)
import UIKit
typealias RitualVerificationContainer = UIView
#else
import AppKit
typealias RitualVerificationContainer = NSView
#endif

/// Owns a single, bounded verification attempt and removes all browser state after completion.
final class RitualVerificationView: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    private let configuration: WKWebViewConfiguration
    private var webView: WKWebView?
    private var timer: Timer?
    private var completion: ((Result<String, Error>) -> Void)?

    init(configuration: WKWebViewConfiguration = WKWebViewConfiguration()) {
        self.configuration = configuration
        configuration.websiteDataStore = .nonPersistent()
    }

    func start(
        in parent: RitualVerificationContainer,
        html: String = RitualVerificationPage.html,
        timeout: TimeInterval = 180,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        self.completion = completion
        configuration.userContentController.add(self, name: RitualVerificationPage.messageHandler)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView = webView
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            webView.topAnchor.constraint(equalTo: parent.topAnchor),
            webView.bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])
        timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.finish(.failure(RitualAuthenticationError.verificationFailed))
        }
        webView.loadHTMLString(html, baseURL: RitualVerificationPage.baseURL)
    }

    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == RitualVerificationPage.messageHandler, message.webView === webView, message.frameInfo.isMainFrame,
              message.frameInfo.securityOrigin.host == RitualVerificationPage.baseURL.host,
              message.frameInfo.securityOrigin.protocol == "https", let body = message.body as? [String: Any] else {
            return
        }
        if let token = body["token"] as? String, !token.isEmpty, token.count <= 1_048_576, !token.contains(where: \.isWhitespace) {
            finish(.success(token))
        } else if body["cancel"] as? Bool == true {
            finish(.failure(RitualAuthenticationError.cancelled))
        } else {
            finish(.failure(RitualAuthenticationError.verificationFailed))
        }
    }

    func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        failed(error)
    }

    func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        failed(error)
    }

    func webView(_: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
        // Google's verification frames may navigate; the containing document stays on its registered origin.
        guard action.targetFrame?.isMainFrame == true, let url = action.request.url else {
            decisionHandler(.allow)
            return
        }
        let allowed = url.absoluteString == "about:blank" || (url.scheme == "https" && url.host == RitualVerificationPage.baseURL.host)
        decisionHandler(allowed ? .allow : .cancel)
    }

    private func failed(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else {
            return
        }
        finish(.failure(RitualAuthenticationError.verificationFailed))
    }

    private func finish(_ result: Result<String, Error>) {
        guard let completion else {
            return
        }
        self.completion = nil
        timer?.invalidate()
        timer = nil
        webView?.stopLoading()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: RitualVerificationPage.messageHandler)
        webView?.navigationDelegate = nil
        webView?.removeFromSuperview()
        webView = nil
        completion(result)
    }
}
#endif
