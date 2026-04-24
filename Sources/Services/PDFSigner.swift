import Foundation
import PDFKit
import UIKit

/// Stamps a signature PNG onto the last page of a consent PDF, matching the Flutter app's output.
enum PDFSigner {

    /// Embed `signaturePNG` in the lower-right of the last page of the template PDF.
    /// Returns the flattened PDF data.
    ///
    /// Matches the Flutter coordinate system: A4 page-space box approximately
    /// `x=274 y=492 w=234.67 h=98.67 points` (origin top-left in Syncfusion).
    /// PDFKit origin is bottom-left, so we translate.
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

        // Signature box (~A4 lower-right). Syncfusion used 234.67×98.67 at topY=492 in top-left coords.
        // Convert to PDFKit's bottom-left coords: newY = pageHeight - (topY + height).
        let sigWidth: CGFloat  = 234.67
        let sigHeight: CGFloat = 98.67
        let topLeftY: CGFloat  = 492
        let topLeftX: CGFloat  = (pageBounds.width - sigWidth) - 16
        let originY = pageBounds.height - (topLeftY + sigHeight)
        let drawRect = CGRect(x: max(0, topLeftX), y: max(0, originY), width: sigWidth, height: sigHeight)

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
