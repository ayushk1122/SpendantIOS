import Foundation

enum CashFlowAmount {
    static func signed(_ amount: Double, bucket: CashFlowBucket) -> Double {
        switch bucket {
        case .income:
            return abs(amount)
        default:
            return -abs(amount)
        }
    }

    static func format(_ amount: Double, bucket: CashFlowBucket) -> String {
        CurrencyFormatter.dollars(signed(amount, bucket: bucket))
    }

    static func sumSigned(
        _ amounts: [Double],
        bucket: CashFlowBucket
    ) -> Double {
        amounts
            .map { signed($0, bucket: bucket) }
            .reduce(0, +)
    }
}

enum TransactionTitleFormatter {
    static func title(
        merchantName: String?,
        name: String,
        categoryDetailed: String? = nil,
        categoryPrimary: String? = nil
    ) -> String {
        let candidates = [merchantName, name]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for candidate in candidates where !looksLikeCategoryLabel(candidate, detailed: categoryDetailed, primary: categoryPrimary) {
            return formatTitle(candidate)
        }

        return formatTitle(name)
    }

    static func categorySubtitle(
        detailed: String?,
        primary: String?
    ) -> String {
        if let detailed, !detailed.isEmpty {
            return humanizeCategory(detailed)
        }

        if let primary, !primary.isEmpty {
            return humanizeCategory(primary)
        }

        return "Uncategorized"
    }

    private static func looksLikeCategoryLabel(
        _ text: String,
        detailed: String?,
        primary: String?
    ) -> Bool {
        let normalized = normalize(text)
        let normalizedDetailed = detailed.map(normalize)
        let normalizedPrimary = primary.map(normalize)

        if let normalizedDetailed, normalized == normalizedDetailed {
            return true
        }

        if let normalizedPrimary, normalized == normalizedPrimary {
            return true
        }

        let words = text.split(separator: " ")
        let hasUppercaseWord = words.contains { word in
            word.count > 1 && word == word.uppercased()
        }

        if hasUppercaseWord {
            return false
        }

        return text == text.lowercased() && text.contains(" ")
    }

    private static func formatTitle(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Transaction"
        }

        if trimmed == trimmed.uppercased() {
            return trimmed
        }

        return trimmed
            .split(separator: " ")
            .map { word -> String in
                let value = String(word)
                if value == value.uppercased() {
                    return value
                }

                return value.prefix(1).uppercased() + value.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    private static func humanizeCategory(_ value: String) -> String {
        formatTitle(value.replacingOccurrences(of: "_", with: " "))
    }

    private static func normalize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
