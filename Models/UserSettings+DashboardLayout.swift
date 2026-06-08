import Foundation

extension UserSettings {
    private static let sectionOrderEncoder = JSONEncoder()
    private static let sectionOrderDecoder = JSONDecoder()

    func resolvedDashboardSectionOrder() -> [DashboardSection] {
        guard let data = dashboardSectionOrderData else {
            return DashboardSection.defaultOrder
        }

        if let decoded = try? Self.sectionOrderDecoder.decode([DashboardSection].self, from: data),
           Set(decoded) == Set(DashboardSection.allCases) {
            return decoded
        }

        if let legacyValues = try? Self.sectionOrderDecoder.decode([String].self, from: data) {
            let migrated = Self.normalizeSectionOrder(legacyValues)
            if Set(migrated) == Set(DashboardSection.allCases) {
                setDashboardSectionOrder(migrated)
                return migrated
            }
        }

        return DashboardSection.defaultOrder
    }

    func setDashboardSectionOrder(_ order: [DashboardSection]) {
        guard Set(order) == Set(DashboardSection.allCases) else {
            return
        }

        dashboardSectionOrderData = try? Self.sectionOrderEncoder.encode(order)
    }

    private static func normalizeSectionOrder(_ rawValues: [String]) -> [DashboardSection] {
        var result: [DashboardSection] = []
        let legacyBreakdown: [DashboardSection] = [
            .income,
            .housing,
            .expenses,
            .subscriptions,
            .transfers
        ]

        for value in rawValues {
            if value == "breakdown" {
                result.append(contentsOf: legacyBreakdown)
            } else if let section = DashboardSection(rawValue: value),
                      !result.contains(section) {
                result.append(section)
            }
        }

        for section in DashboardSection.allCases where !result.contains(section) {
            result.append(section)
        }

        return result
    }
}
