import Foundation

struct MoneyDestinationConfig: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var percent: Double
    var icon: String

    init(
        id: UUID = UUID(),
        name: String,
        percent: Double,
        icon: String
    ) {
        self.id = id
        self.name = name
        self.percent = percent
        self.icon = icon
    }

    var percentPoints: Int {
        Int((percent * 100).rounded())
    }

    static let defaultIconOptions = [
        "banknote.fill",
        "chart.pie.fill",
        "building.columns.fill",
        "shield.fill",
        "dollarsign.circle.fill",
        "creditcard.fill",
        "house.fill",
        "arrow.up.right.circle.fill",
        "leaf.fill"
    ]

    static var defaults: [MoneyDestinationConfig] {
        [
            MoneyDestinationConfig(name: "Savings Account", percent: 0.40, icon: "banknote.fill"),
            MoneyDestinationConfig(name: "Investments", percent: 0.35, icon: "chart.pie.fill"),
            MoneyDestinationConfig(name: "Retirement", percent: 0.15, icon: "building.columns.fill"),
            MoneyDestinationConfig(name: "Extra Buffer", percent: 0.10, icon: "shield.fill")
        ]
    }
}
