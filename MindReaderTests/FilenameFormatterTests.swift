import XCTest
@testable import MindReader

final class FilenameFormatterTests: XCTestCase {
    func testFormatsWithDayPrecisionDate() {
        let formatter = FilenameFormatter(timeZone: TimeZone(secondsFromGMT: 0)!)
        let date = Date(timeIntervalSince1970: 1764806400) // 2025-12-04 UTC

        let context = FileNamingContext(
            date: date,
            datePrecision: .day,
            entity: "Acme Co",
            description: "Invoice #1843",
            originalExtension: "pdf"
        )

        let output = formatter.format(context: context)

        XCTAssertEqual(output, "2025-12-04 - Acme Co - Invoice #1843.pdf")
    }

    func testFormatsWithYearPrecisionDate() {
        let formatter = FilenameFormatter(timeZone: TimeZone(secondsFromGMT: 0)!)
        let date = Date(timeIntervalSince1970: 1483228800) // 2017-01-01 UTC

        let context = FileNamingContext(
            date: date,
            datePrecision: .year,
            entity: "Vaswani et al",
            description: "Attention Is All You Need",
            originalExtension: "pdf"
        )

        let output = formatter.format(context: context)

        XCTAssertEqual(output, "2017 - Vaswani et al - Attention Is All You Need.pdf")
    }

    func testSanitizesInvalidPathCharacters() {
        let formatter = FilenameFormatter(timeZone: TimeZone(secondsFromGMT: 0)!)
        let date = Date(timeIntervalSince1970: 1764806400)

        let context = FileNamingContext(
            date: date,
            datePrecision: .day,
            entity: "Acme/Corp",
            description: "Invoice: #1843",
            originalExtension: "pdf"
        )

        let output = formatter.format(context: context)

        XCTAssertEqual(output, "2025-12-04 - Acme-Corp - Invoice #1843.pdf")
    }
}
