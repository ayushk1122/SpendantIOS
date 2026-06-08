import Foundation

extension UserSettings {
    private static let destinationsEncoder = JSONEncoder()
    private static let destinationsDecoder = JSONDecoder()

    func resolvedMoneyDestinations() -> [MoneyDestinationConfig] {
        if let data = moneyDestinationsData,
           let decoded = try? Self.destinationsDecoder.decode([MoneyDestinationConfig].self, from: data),
           !decoded.isEmpty {
            return MoneyDestinationAllocator.normalized(decoded)
        }

        return migratedLegacyDestinations()
    }

    func setMoneyDestinations(_ destinations: [MoneyDestinationConfig]) {
        let normalized = MoneyDestinationAllocator.normalized(destinations)
        moneyDestinationsData = try? Self.destinationsEncoder.encode(normalized)
        syncLegacyAllocationFields(from: normalized)
    }

    func applyBalancedMoneyDestinations() {
        setMoneyDestinations(MoneyDestinationAllocator.resetToDefaults())
    }

    func applyConservativeMoneyDestinations() {
        setMoneyDestinations([
            MoneyDestinationConfig(name: "Savings Account", percent: 0.50, icon: "banknote.fill"),
            MoneyDestinationConfig(name: "Investments", percent: 0.20, icon: "chart.pie.fill"),
            MoneyDestinationConfig(name: "Retirement", percent: 0.10, icon: "building.columns.fill"),
            MoneyDestinationConfig(name: "Extra Buffer", percent: 0.20, icon: "shield.fill")
        ])
    }

    func applyGrowthMoneyDestinations() {
        setMoneyDestinations([
            MoneyDestinationConfig(name: "Savings Account", percent: 0.25, icon: "banknote.fill"),
            MoneyDestinationConfig(name: "Investments", percent: 0.45, icon: "chart.pie.fill"),
            MoneyDestinationConfig(name: "Retirement", percent: 0.20, icon: "building.columns.fill"),
            MoneyDestinationConfig(name: "Extra Buffer", percent: 0.10, icon: "shield.fill")
        ])
    }

    private func migratedLegacyDestinations() -> [MoneyDestinationConfig] {
        let migrated = [
            MoneyDestinationConfig(
                name: "Savings Account",
                percent: savingsAllocationPercent,
                icon: "banknote.fill"
            ),
            MoneyDestinationConfig(
                name: "Investments",
                percent: investmentAllocationPercent,
                icon: "chart.pie.fill"
            ),
            MoneyDestinationConfig(
                name: "Retirement",
                percent: retirementAllocationPercent,
                icon: "building.columns.fill"
            ),
            MoneyDestinationConfig(
                name: "Extra Buffer",
                percent: bufferAllocationPercent,
                icon: "shield.fill"
            )
        ]

        setMoneyDestinations(migrated)
        return MoneyDestinationAllocator.normalized(migrated)
    }

    private func syncLegacyAllocationFields(from destinations: [MoneyDestinationConfig]) {
        savingsAllocationPercent = percent(for: "Savings Account", in: destinations, fallback: 0.40)
        investmentAllocationPercent = percent(for: "Investments", in: destinations, fallback: 0.35)
        retirementAllocationPercent = percent(for: "Retirement", in: destinations, fallback: 0.15)
        bufferAllocationPercent = percent(for: "Extra Buffer", in: destinations, fallback: 0.10)
    }

    private func percent(
        for name: String,
        in destinations: [MoneyDestinationConfig],
        fallback: Double
    ) -> Double {
        destinations.first(where: { $0.name == name })?.percent ?? fallback
    }
}
