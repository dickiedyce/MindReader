import XCTest
import CoreGraphics
@testable import MindReader

final class VisionOCRExtractorTests: XCTestCase {
    func testExtractsTextFromRasterImage() throws {
        let url = makeTempPNGWithText("ACME CORP INVOICE")
        defer { try? FileManager.default.removeItem(at: url) }

        let extractor = VisionOCRExtractor()
        let result = try extractor.extractText(from: url)

        let text = try XCTUnwrap(result, "Expected OCR to return text, got nil")
        XCTAssertTrue(text.uppercased().contains("ACME"), "Expected 'ACME' in OCR output, got: \(text)")
    }

    func testReturnsNilForUnsupportedExtension() throws {
        let url = URL(fileURLWithPath: "/tmp/archive.zip")
        let extractor = VisionOCRExtractor()
        let result = try extractor.extractText(from: url)
        XCTAssertNil(result)
    }

    func testReturnsNilForPDFThatAlreadyHasTextLayer() throws {
        // PDFKit-extractable PDFs should be handled by the document extractor, not OCR.
        let url = makeTempSearchablePDF(text: "Hello World")
        defer { try? FileManager.default.removeItem(at: url) }

        let extractor = VisionOCRExtractor()
        let result = try extractor.extractText(from: url)
        // Searchable PDFs return nil from OCR extractor (document extractor handles them).
        XCTAssertNil(result, "Expected nil for searchable PDF, got: \(result ?? "")")
    }
}

// MARK: - Helpers

/// Renders text as a raster PNG (no text layer) using CoreGraphics, simulating a scanned page.
private func makeTempPNGWithText(_ text: String) -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString + ".png")

    let width = 600
    let height = 200
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let ctx = CGContext(data: nil, width: width, height: height,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: colorSpace, bitmapInfo: bitmapInfo) else { return url }

    // White background
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // Black text via Core Text
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 36, nil)
    let attrs: [NSAttributedString.Key: Any] = [.font: font,
                                                 .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1)]
    let attrStr = CFAttributedStringCreate(kCFAllocatorDefault, text as CFString, attrs as CFDictionary)!
    let line = CTLineCreateWithAttributedString(attrStr)
    ctx.textPosition = CGPoint(x: 40, y: 80)
    CTLineDraw(line, ctx)

    guard let image = ctx.makeImage() else { return url }
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    return url
}

/// Creates a PDF with a real searchable text layer via Core Text.
private func makeTempSearchablePDF(text: String) -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString + ".pdf")
    var bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let ctx = CGContext(url as CFURL, mediaBox: &bounds, nil) else { return url }
    ctx.beginPDFPage(nil)
    let font = CTFontCreateWithName("Helvetica" as CFString, 14, nil)
    let attrs: [NSAttributedString.Key: Any] = [.font: font]
    let attrStr = CFAttributedStringCreate(kCFAllocatorDefault, text as CFString, attrs as CFDictionary)!
    let line = CTLineCreateWithAttributedString(attrStr)
    ctx.textPosition = CGPoint(x: 50, y: 600)
    CTLineDraw(line, ctx)
    ctx.endPDFPage()
    ctx.closePDF()
    return url
}
