#if canImport(WebKit) && (canImport(UIKit) || canImport(AppKit))
import Foundation
import Testing
import WebKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@testable import RitualDownloader

#if canImport(UIKit)
@Suite(.disabled("WKWebView requires a UIApplication-hosted test process on iOS"))
#else
@Suite(.serialized)
#endif
struct RitualVerificationViewTests {
    @MainActor
    private func configuration() async throws -> WKWebViewConfiguration {
        // No remote page is rendered. Block every HTTP resource even if a test document is changed accidentally.
        let rules = #"[{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}}]"#
        let list: WKContentRuleList = try await withCheckedThrowingContinuation { continuation in
            WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "RitualOfflineVerificationTests", encodedContentRuleList: rules) { list, error in
                if let list {
                    continuation.resume(returning: list)
                } else {
                    continuation.resume(throwing: error ?? RitualAuthenticationError.verificationFailed)
                }
            }
        }
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(list)
        return configuration
    }

    @Test
    @MainActor
    func acceptsLocalMainFrameAndRemovesView() async throws {
        let configuration = try await configuration()
        let parent = RitualVerificationContainer(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        let view = RitualVerificationView(configuration: configuration)
        let html = """
        <!doctype html><script>
        window.webkit.messageHandlers.ritualVerification.postMessage({token:'local-synthetic-token'});
        </script>
        """
        let token: String = try await withCheckedThrowingContinuation { continuation in
            view.start(in: parent, html: html, timeout: 60) { continuation.resume(with: $0) }
        }
        #expect(token == "local-synthetic-token")
        #expect(parent.subviews.isEmpty)
    }

    @Test
    @MainActor
    func ignoresChildFrameMessages() async throws {
        let configuration = try await configuration()
        let parent = RitualVerificationContainer(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        let view = RitualVerificationView(configuration: configuration)
        let html = """
        <!doctype html>
        <iframe srcdoc="<script>window.webkit.messageHandlers.ritualVerification.postMessage({token:'child-frame'});</script>"></iframe>
        <script>window.onload=function(){window.webkit.messageHandlers.ritualVerification.postMessage({token:'main-frame'});};</script>
        """
        let token: String = try await withCheckedThrowingContinuation { continuation in
            view.start(in: parent, html: html, timeout: 60) { continuation.resume(with: $0) }
        }
        #expect(token == "main-frame")
        #expect(parent.subviews.isEmpty)
    }

    @Test
    @MainActor
    func cancellationRemovesView() async throws {
        let configuration = try await configuration()
        let parent = RitualVerificationContainer(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        let view = RitualVerificationView(configuration: configuration)
        let html = "<script>window.webkit.messageHandlers.ritualVerification.postMessage({cancel:true});</script>"
        let result: Result<String, Error> = await withCheckedContinuation { continuation in
            view.start(in: parent, html: html, timeout: 10) { continuation.resume(returning: $0) }
        }
        #expect(throws: RitualAuthenticationError.cancelled) { try result.get() }
        #expect(parent.subviews.isEmpty)
    }

    @Test
    @MainActor
    func timeoutRemovesView() async throws {
        let configuration = try await configuration()
        let parent = RitualVerificationContainer(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
        let view = RitualVerificationView(configuration: configuration)
        let result: Result<String, Error> = await withCheckedContinuation { continuation in
            view.start(in: parent, html: "<!doctype html><p>Local test only</p>", timeout: 0.05) { continuation.resume(returning: $0) }
        }
        #expect(throws: RitualAuthenticationError.verificationFailed) { try result.get() }
        #expect(parent.subviews.isEmpty)
    }
}
#endif
