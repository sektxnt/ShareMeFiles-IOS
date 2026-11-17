import SwiftUI
import WebKit
import UIKit

struct ShareMeWebView: UIViewRepresentable {
    @Binding var webView: WKWebView?
    let onDownload: (URL) -> Void
    let onLoadingChanged: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDownload: onDownload, onLoadingChanged: onLoadingChanged)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        view.scrollView.contentInsetAdjustmentBehavior = .automatic
        view.isOpaque = false
        view.backgroundColor = UIColor(red: 0.045, green: 0.055, blue: 0.08, alpha: 1)
        view.scrollView.backgroundColor = view.backgroundColor

        context.coordinator.webView = view
        DispatchQueue.main.async {
            self.webView = view
        }

        if let url = URL(string: "https://sharemefiles.com/") {
            view.load(URLRequest(
                url: url,
                cachePolicy: .useProtocolCachePolicy,
                timeoutInterval: 45
            ))
        }

        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject,
        WKNavigationDelegate,
        WKUIDelegate,
        WKDownloadDelegate {

        weak var webView: WKWebView?

        private let onDownload: (URL) -> Void
        private let onLoadingChanged: (Bool) -> Void

        private var downloadLocations: [ObjectIdentifier: URL] = [:]

        init(
            onDownload: @escaping (URL) -> Void,
            onLoadingChanged: @escaping (Bool) -> Void
        ) {
            self.onDownload = onDownload
            self.onLoadingChanged = onLoadingChanged
        }

        func webView(
            _ webView: WKWebView,
            didStartProvisionalNavigation navigation: WKNavigation!
        ) {
            onLoadingChanged(true)
        }

        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            onLoadingChanged(false)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            onLoadingChanged(false)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            onLoadingChanged(false)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard navigationAction.targetFrame == nil else {
                return nil
            }

            webView.load(navigationAction.request)
            return nil
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            if let response = navigationResponse.response as? HTTPURLResponse,
               response.value(forHTTPHeaderField: "Content-Disposition")?
                .lowercased().contains("attachment") == true {

                decisionHandler(.download)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url,
               url.host == "sharemefiles.com",
               url.path.contains("/api/"),
               url.path.contains("/files/") {

                decisionHandler(.download)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(
            _ webView: WKWebView,
            navigationAction: WKNavigationAction,
            didBecome download: WKDownload
        ) {
            download.delegate = self
        }

        func webView(
            _ webView: WKWebView,
            navigationResponse: WKNavigationResponse,
            didBecome download: WKDownload
        ) {
            download.delegate = self
        }

        func download(
            _ download: WKDownload,
            decideDestinationUsing response: URLResponse,
            suggestedFilename: String,
            completionHandler: @escaping (URL?) -> Void
        ) {
            let filename = URL(fileURLWithPath: suggestedFilename).lastPathComponent
            let safeFilename = filename.isEmpty ? "download" : filename

            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "-" + safeFilename)

            downloadLocations[ObjectIdentifier(download)] = destination
            completionHandler(destination)
        }

        func downloadDidFinish(_ download: WKDownload) {
            guard let url = downloadLocations.removeValue(
                forKey: ObjectIdentifier(download)
            ) else {
                return
            }

            DispatchQueue.main.async {
                self.onDownload(url)
            }
        }

        func download(
            _ download: WKDownload,
            didFailWithError error: Error,
            resumeData: Data?
        ) {
            downloadLocations.removeValue(forKey: ObjectIdentifier(download))
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            presentAlert(
                message: message,
                in: webView,
                completion: completionHandler
            )
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            let alert = UIAlertController(
                title: "ShareMeFiles",
                message: message,
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(
                title: "Отмена",
                style: .cancel
            ) { _ in
                completionHandler(false)
            })

            alert.addAction(UIAlertAction(
                title: "ОК",
                style: .default
            ) { _ in
                completionHandler(true)
            })

            topViewController(from: webView)?.present(alert, animated: true)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            let alert = UIAlertController(
                title: "ShareMeFiles",
                message: prompt,
                preferredStyle: .alert
            )

            alert.addTextField {
                $0.text = defaultText
            }

            alert.addAction(UIAlertAction(
                title: "Отмена",
                style: .cancel
            ) { _ in
                completionHandler(nil)
            })

            alert.addAction(UIAlertAction(
                title: "ОК",
                style: .default
            ) { _ in
                completionHandler(alert.textFields?.first?.text)
            })

            topViewController(from: webView)?.present(alert, animated: true)
        }

        private func presentAlert(
            message: String,
            in webView: WKWebView,
            completion: @escaping () -> Void
        ) {
            let alert = UIAlertController(
                title: "ShareMeFiles",
                message: message,
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(
                title: "ОК",
                style: .default
            ) { _ in
                completion()
            })

            topViewController(from: webView)?.present(alert, animated: true)
        }

        private func topViewController(from view: UIView) -> UIViewController? {
            var responder: UIResponder? = view

            while let current = responder {
                if let controller = current as? UIViewController {
                    return controller
                }

                responder = current.next
            }

            return nil
        }
    }
}
