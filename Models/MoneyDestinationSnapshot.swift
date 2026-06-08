import Foundation

struct MoneyDestinationSnapshot: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let percent: Double
    let icon: String

    func toConfig() -> MoneyDestinationConfig {
        MoneyDestinationConfig(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            percent: percent,
            icon: icon
        )
    }
}

struct FinalizeDashboardSnapshotRequest: Encodable {
    let protectedBalance: Double?
    let moneyDestinations: [MoneyDestinationSnapshot]?

    enum CodingKeys: String, CodingKey {
        case protectedBalance = "protected_balance"
        case moneyDestinations = "money_destinations"
    }

    init(
        protectedBalance: Double?,
        destinations: [MoneyDestinationConfig]
    ) {
        self.protectedBalance = protectedBalance
        self.moneyDestinations = destinations.map { config in
            MoneyDestinationSnapshot(
                id: config.id.uuidString,
                name: config.name,
                percent: config.percent,
                icon: config.icon
            )
        }
    }
}
