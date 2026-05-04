import Foundation
import PDFKit
import UIKit

/// Stamps a signature PNG onto the last page of a consent PDF, matching the Flutter app's output.
enum PDFSigner {

    /// Embed `signaturePNG` near the bottom-right of the last page of the template PDF.
    /// Returns the flattened PDF data.
    ///
    /// Anchored to the page bottom (rather than a hardcoded top-Y) so the signature
    /// always lands below the text regardless of how long the template runs.
    static func embedSignature(
        templateData: Data,
        signaturePNG: Data
    ) throws -> Data {
        guard let doc = PDFDocument(data: templateData),
              let lastPage = doc.page(at: doc.pageCount - 1),
              let sigImage = UIImage(data: signaturePNG)?.cgImage
        else {
            throw NSError(domain: "PDFSigner", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not load PDF or signature image."])
        }

        let pageBounds = lastPage.bounds(for: .mediaBox)

        let sigWidth: CGFloat    = 234.67
        let sigHeight: CGFloat   = 98.67
        let rightMargin: CGFloat = 16
        let bottomMargin: CGFloat = 40
        let originX = max(0, pageBounds.width - sigWidth - rightMargin)
        let originY = bottomMargin   // PDFKit bottom-left coords
        let drawRect = CGRect(x: originX, y: originY, width: sigWidth, height: sigHeight)

        // Render a new PDF with every page copied; overlay signature on the final page.
        let format = UIGraphicsPDFRendererFormat()
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds, format: format)
        let output = renderer.pdfData { ctx in
            for i in 0..<doc.pageCount {
                guard let page = doc.page(at: i) else { continue }
                let b = page.bounds(for: .mediaBox)
                ctx.beginPage(withBounds: b, pageInfo: [:])
                let cg = ctx.cgContext
                cg.saveGState()
                // PDFKit pages draw upside-down in UIKit's coord space; flip.
                cg.translateBy(x: 0, y: b.height)
                cg.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: cg)
                cg.restoreGState()

                if i == doc.pageCount - 1 {
                    ctx.cgContext.draw(sigImage, in: drawRect)
                }
            }
        }
        return output
    }
}
