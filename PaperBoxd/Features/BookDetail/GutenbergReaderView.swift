import SwiftUI
import WebKit

/// Public-domain reader: Project Gutenberg's own HTML page for the book in a
/// WKWebView, under a close bar. Presented as a fullScreenCover from
/// BookDetailView's "Read free" button. Navigation is pinned to gutenberg.org.
struct GutenbergReaderView: View {
    let title: String
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(BK.ink)
                        .frame(width: 40, height: 40)
                }
                Text(title.uppercased())
                    .font(.system(size: 13, weight: .black)).tracking(0.5)
                    .foregroundStyle(BK.ink)
                    .lineLimit(1)
                Spacer()
                if loading { ProgressView().tint(BK.ink) }
            }
            .padding(.horizontal, 8)
            .frame(height: 52)
            .background(BK.paper)
            .overlay(alignment: .bottom) { Rectangle().fill(BK.ink).frame(height: 2) }

            GutenbergWebView(url: url, loading: $loading)
                .ignoresSafeArea(edges: .bottom)
        }
        .background(BK.paper)
    }
}

private struct GutenbergWebView: UIViewRepresentable {
    let url: URL
    @Binding var loading: Bool

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let parent: GutenbergWebView
        init(_ parent: GutenbergWebView) { self.parent = parent }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let host = action.request.url?.host ?? ""
            decisionHandler(host == "www.gutenberg.org" || host == "gutenberg.org" ? .allow : .cancel)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { parent.loading = false }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { parent.loading = false }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { parent.loading = false }
    }
}
