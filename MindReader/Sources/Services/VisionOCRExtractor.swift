import Foundation
import Vision
import PDFKit

/// Extracts text from raster images and scanned PDFs (no searchable text layer)
/// using the Vision framework's VNRecognizeTextRequest.
struct VisionOCRExtractor: OCRTextExtracting {
    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "tiff", "tif", "bmp", "gif", "heic", "heif"
    ]

    func extractText(from fileURL: URL) throws -> String? {
        let ext = fileURL.pathExtension.lowercased()

        if Self.imageExtensions.contains(ext) {
            guard
                let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
                let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else { return nil }
            return try recognizeText(in: [cgImage])
        }

        if ext == "pdf" {
            guard let doc = PDFDocument(url: fileURL) else { return nil }
            // If the PDF already has a searchable text layer, let the document
            // extractor handle it — skip OCR.
            let existingText = doc.string ?? ""
            if !existingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return nil
            }
            let images = renderedPages(from: doc)
            guard !images.isEmpty else { return nil }
            return try recognizeText(in: images)
        }

        return nil
    }

    // MARK: - Private

    private func renderedPages(from doc: PDFDocument, scale: CGFloat = 2.0) -> [CGImage] {
        var images: [CGImage] = []
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let width = Int(bounds.width * scale)
            let height = Int(bounds.height * scale)
            guard let ctx = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: colorSpace, bitmapInfo: bitmapInfo)
            else { continue }
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            ctx.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: ctx)
            if let img = ctx.makeImage() { images.append(img) }
        }
        return images
    }

    private func recognizeText(in images: [CGImage]) throws -> String? {
        var parts: [String] = []
        for image in images {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            let lines = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
            if !lines.isEmpty { parts.append(lines) }
        }
        let combined = parts.joined(separator: "\n\n")
        return combined.isEmpty ? nil : combined
    }
}
