import SwiftUI
import WebKit
import UIKit

struct ContentView: View {
    @State private var webView: WKWebView?
    @State private var downloadedFile: URL?
    @State private var showShareSheet = false
    @State private var alertMessage: String?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(red: 0.68, green: 0.57, blue: 1.0))

                    Text("ShareMeFiles")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                if isLoading {
                    ProgressView()
                        .tint(.white.opacity(0.8))
                        .scaleEffect(0.8)
                }

                Button {
                    pasteInviteLink()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    webView?.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(Color(red: 0.045, green: 0.055, blue: 0.08))

            ShareMeWebView(
                webView: $webView,
                onDownload: { url in
                    downloadedFile = url
                    showShareSheet = true
                },
                onLoadingChanged: { loading in
                    isLoading = loading
                }
            )
        }
        .background(Color(red: 0.045, green: 0.055, blue: 0.08).ignoresSafeArea())
        .sheet(isPresented: $showShareSheet, onDismiss: {
            if let url = downloadedFile {
                try? FileManager.default.removeItem(at: url)
            }
            downloadedFile = nil
        }) {
            if let url = downloadedFile {
                ActivityView(activityItems: [url])
                    .ignoresSafeArea()
            }
        }
        .alert("ShareMeFiles", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("ОК", role: .cancel) {
                alertMessage = nil
            }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func pasteInviteLink() {
        guard let value = UIPasteboard.general.string,
              let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host,
              host == "sharemefiles.com" || host == "www.sharemefiles.com" else {
            alertMessage = "Скопируй ссылку ShareMeFiles и нажми эту кнопку ещё раз."
            return
        }

        webView?.load(URLRequest(url: url))
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ controller: UIActivityViewController,
        context: Context
    ) {}
}
