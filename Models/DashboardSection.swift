import Foundation

enum DashboardSection: String, Codable, CaseIterable, Identifiable {
    case projectionChart
    case income
    case housing
    case expenses
    case subscriptions
    case transfers
    case destinations

    var id: String { rawValue }

    var cashFlowBucket: CashFlowBucket? {
        switch self {
        case .income:
            return .income
        case .housing:
            return .housing
        case .expenses:
            return .expenses
        case .subscriptions:
            return .subscriptions
        case .transfers:
            return .transfers
        case .projectionChart, .destinations:
            return nil
        }
    }

    static var defaultOrder: [DashboardSection] {
        [
            .projectionChart,
            .income,
            .housing,
            .expenses,
            .subscriptions,
            .transfers,
            .destinations
        ]
    }
}
