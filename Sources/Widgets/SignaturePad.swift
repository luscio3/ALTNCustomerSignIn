import SwiftUI
import PencilKit

/// Finger/pen signature pad powered by PencilKit. Exports a transparent PNG of the ink.
struct SignaturePad: View {

    @Binding var canvas: PKCanvasView
    var onChange: () -> Void = {}

    var body: some View {
        ZStack {
            SignatureCanvas(canvas: $canvas, onChange: onChange)
                .background(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.35), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if canvas.drawing.strokes.isEmpty {
                Text("Sign here")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            }
        }
    }

    /// Export a trimmed PNG (transparent bg) sized to `targetSize` points.
    static func exportPNG(from canvas: PKCanvasView, targetSize: CGSize = CGSize(width: 704, height: 296)) -> Data? {
        let drawing = canvas.drawing
        guard !drawing.strokes.isEmpty else { return nil }
        let sourceRect = drawing.bounds.isEmpty ? CGRect(origin: .zero, size: canvas.bounds.size) : CGRect(origin: .zero, size: canvas.bounds.size)
        let image = drawing.image(from: sourceRect, scale: UIScreen.main.scale)
        // Resize to target.
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.pngData()
    }
}

private struct SignatureCanvas: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    var onChange: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .white
        canvas.isOpaque = true
        canvas.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Keep the coordinator's captured closure up to date across rebuilds.
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: SignatureCanvas
        init(_ p: SignatureCanvas) { self.parent = p }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) { parent.onChange() }
    }
}
