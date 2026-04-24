import SwiftUI
import PDFKit

/// Simple PDFKit-backed PDF viewer. Fits width, vertical scrolling.
/// Prefer `init(url:)` — it memory-maps the file and skips copying bytes into RAM.
struct PDFViewer: UIViewRepresentable {
    enum Source: Equatable {
        case url(URL)
        case data(Data)
    }
    let source: Source

    init(url: URL)  { self.source = .url(url) }
    init(data: Data) { self.source = .data(data) }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.usePageViewController(false)
        view.backgroundColor = .white
        view.document = makeDocument()
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        // Only rebuild the document if the source identity changed.
        if context.coordinator.lastSource != source {
            context.coordinator.lastSource = source
            uiView.document = makeDocument()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(source: source) }

    final class Coordinator {
        var lastSource: Source
        init(source: Source) { self.lastSource = source }
    }

    private func makeDocument() -> PDFDocument? {
        switch source {
        case .url(let u):  return PDFDocument(url: u)
        case .data(let d): return PDFDocument(data: d)
        }
    }
}
