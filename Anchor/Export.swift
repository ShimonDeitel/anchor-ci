import Foundation
import UIKit

/// Builds the 1-year export files (a Pro feature). Pure given the supplied text — easy to test.
enum Export {

    /// Write the plain-text export to a temp `.txt` file and return its URL.
    static func writeText(_ body: String) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Anchor-Intentions.txt")
        do {
            try body.data(using: .utf8)?.write(to: url, options: .atomic)
            return url
        } catch { return nil }
    }

    /// Render the same text into a simple, paginated A4-ish PDF and return its URL.
    @MainActor
    static func writePDF(_ body: String) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter @72dpi
        let margin: CGFloat = 48
        let textRect = pageRect.insetBy(dx: margin, dy: margin)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph
        ]
        let attributed = NSAttributedString(string: body, attributes: attrs)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Anchor-Intentions.pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        do {
            try renderer.writePDF(to: url) { ctx in
                let framesetter = CTFramesetterCreateWithAttributedString(attributed)
                var range = CFRange(location: 0, length: 0)
                let total = attributed.length
                repeat {
                    ctx.beginPage()
                    let cgCtx = ctx.cgContext
                    // Flip coordinates for Core Text.
                    cgCtx.textMatrix = .identity
                    cgCtx.translateBy(x: 0, y: pageRect.height)
                    cgCtx.scaleBy(x: 1, y: -1)

                    let flippedTextRect = CGRect(
                        x: textRect.minX,
                        y: pageRect.height - textRect.maxY,
                        width: textRect.width,
                        height: textRect.height
                    )
                    let path = CGPath(rect: flippedTextRect, transform: nil)
                    let frame = CTFramesetterCreateFrame(
                        framesetter, CFRange(location: range.location, length: 0), path, nil)
                    CTFrameDraw(frame, cgCtx)

                    let visible = CTFrameGetVisibleStringRange(frame)
                    range.location += visible.length
                    if visible.length == 0 { break } // safety: avoid an infinite loop
                } while range.location < total
            }
            return url
        } catch { return nil }
    }
}
