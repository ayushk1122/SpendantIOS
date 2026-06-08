import Foundation

struct DashboardMonth: Equatable, Hashable, Identifiable {
    let year: Int
    let month: Int

    var id: String { apiValue }

    var apiValue: String {
        String(format: "%04d-%02d", year, month)
    }

    var isCurrentMonth: Bool {
        let today = Date()
        let calendar = Calendar.current
        return calendar.component(.year, from: today) == year
            && calendar.component(.month, from: today) == month
    }

    var isHistorical: Bool {
        !isCurrentMonth && startDate < Calendar.current.startOfDay(for: Date())
    }

    var startDate: Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? .now
    }

    var endDate: Date {
        let calendar = Calendar.current
        let start = startDate
        let range = calendar.range(of: .day, in: .month, for: start) ?? 1..<29
        return calendar.date(
            from: DateComponents(year: year, month: month, day: range.upperBound - 1)
        ) ?? start
    }

    var menuLabel: String {
        if isCurrentMonth {
            return "This Month"
        }

        return shortLabel
    }

    var shortLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: startDate)
    }

    var heroTitle: String {
        isHistorical ? "Safe to Move at Month End" : "Safe to Move Today"
    }

    var heroSubtitle: String {
        if isHistorical {
            return "How much room you had to move money after \(shortLabel) spending settled."
        }

        return "Amount you can safely move while maintaining your account balance buffer."
    }

    static var current: DashboardMonth {
        let today = Date()
        let calendar = Calendar.current
        return DashboardMonth(
            year: calendar.component(.year, from: today),
            month: calendar.component(.month, from: today)
        )
    }

    static var previous: DashboardMonth? {
        let calendar = Calendar.current
        guard let date = calendar.date(byAdding: .month, value: -1, to: Date()) else {
            return nil
        }

        return DashboardMonth(
            year: calendar.component(.year, from: date),
            month: calendar.component(.month, from: date)
        )
    }

    static func recentMonths(count: Int = 12) -> [DashboardMonth] {
        let calendar = Calendar.current
        let today = Date()

        return (0..<count).compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: -offset, to: today) else {
                return nil
            }

            return DashboardMonth(
                year: calendar.component(.year, from: date),
                month: calendar.component(.month, from: date)
            )
        }
    }
}
