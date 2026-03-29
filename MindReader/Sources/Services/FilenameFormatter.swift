import Foundation

enum DatePrecision: Equatable {
    case day
    case year
    case none
}

struct FileNamingContext {
    let date: Date?
    let datePrecision: DatePrecision
    let entity: String
    let description: String
    let originalExtension: String
}

struct FilenameFormatter {
    private let timeZone: TimeZone
    private let calendar: Calendar

    init(timeZone: TimeZone = .current, calendar: Calendar = .current) {
        self.timeZone = timeZone
        var adjustedCalendar = calendar
        adjustedCalendar.timeZone = timeZone
        self.calendar = adjustedCalendar
    }

    func format(context: FileNamingContext) -> String {
        let datePart = formattedDate(date: context.date, precision: context.datePrecision)
        let entityPart = sanitizeComponent(context.entity)
        let descriptionPart = sanitizeComponent(context.description)
        let fileExtension = sanitizeExtension(context.originalExtension)

        return "\(datePart) — \(entityPart) — \(descriptionPart).\(fileExtension)"
    }

    private func formattedDate(date: Date?, precision: DatePrecision) -> String {
        guard let date else {
            return "Undated"
        }

        switch precision {
        case .day:
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            guard let year = components.year, let month = components.month, let day = components.day else {
                return "Undated"
            }
            return String(format: "%04d-%02d-%02d", year, month, day)
        case .year:
            let year = calendar.component(.year, from: date)
            return String(format: "%04d", year)
        case .none:
            return "Undated"
        }
    }

    private func sanitizeComponent(_ input: String) -> String {
        var cleaned = input.replacingOccurrences(of: "/", with: "-")
        let removableCharacters = CharacterSet(charactersIn: ":\\?%*|\"<>\n\r")
        cleaned = String(cleaned.unicodeScalars.filter { !removableCharacters.contains($0) })

        let normalized = cleaned
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.isEmpty ? "Unknown" : normalized
    }

    private func sanitizeExtension(_ input: String) -> String {
        let cleaned = input.replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "txt" : cleaned
    }
}
