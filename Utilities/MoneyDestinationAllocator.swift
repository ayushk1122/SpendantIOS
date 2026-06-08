import Foundation

enum MoneyDestinationAllocator {
    static let minimumDestinationCount = 1
    static let maximumDestinationCount = 8

    static func normalized(_ destinations: [MoneyDestinationConfig]) -> [MoneyDestinationConfig] {
        guard !destinations.isEmpty else {
            return MoneyDestinationConfig.defaults
        }

        if destinations.count == 1 {
            var single = destinations
            single[0].percent = 1
            return single
        }

        let total = destinations.map(\.percent).reduce(0, +)
        guard total > 0 else {
            return distributeEvenly(destinations)
        }

        return destinations.map { destination in
            var updated = destination
            updated.percent = destination.percent / total
            return updated
        }
    }

    static func updatePercent(
        at index: Int,
        to newPercent: Double,
        in destinations: [MoneyDestinationConfig]
    ) -> [MoneyDestinationConfig] {
        guard destinations.indices.contains(index) else {
            return normalized(destinations)
        }

        if destinations.count == 1 {
            var single = destinations
            single[0].percent = 1
            return single
        }

        let clamped = min(max(newPercent, 0), 1)
        var updated = destinations
        updated[index].percent = clamped

        let remaining = max(0, 1 - clamped)
        let otherIndices = updated.indices.filter { $0 != index }
        let otherTotal = otherIndices.map { updated[$0].percent }.reduce(0, +)

        if otherTotal <= 0 {
            let evenShare = remaining / Double(otherIndices.count)
            for otherIndex in otherIndices {
                updated[otherIndex].percent = evenShare
            }
            return updated
        }

        for otherIndex in otherIndices {
            let ratio = updated[otherIndex].percent / otherTotal
            updated[otherIndex].percent = remaining * ratio
        }

        return normalized(updated)
    }

    static func addDestination(to destinations: [MoneyDestinationConfig]) -> [MoneyDestinationConfig] {
        guard destinations.count < maximumDestinationCount else {
            return normalized(destinations)
        }

        let newShare = 1.0 / Double(destinations.count + 1)
        var updated = destinations.map { destination in
            var copy = destination
            copy.percent *= 1 - newShare
            return copy
        }

        updated.append(
            MoneyDestinationConfig(
                name: "New Destination",
                percent: newShare,
                icon: "dollarsign.circle.fill"
            )
        )

        return normalized(updated)
    }

    static func removeDestination(
        at index: Int,
        from destinations: [MoneyDestinationConfig]
    ) -> [MoneyDestinationConfig] {
        guard destinations.count > minimumDestinationCount,
              destinations.indices.contains(index) else {
            return normalized(destinations)
        }

        let removedPercent = destinations[index].percent
        var updated = destinations
        updated.remove(at: index)

        if updated.count == 1 {
            updated[0].percent = 1
            return updated
        }

        let remainingTotal = updated.map(\.percent).reduce(0, +)
        if remainingTotal <= 0 {
            return distributeEvenly(updated)
        }

        updated = updated.map { destination in
            var copy = destination
            copy.percent += removedPercent * (destination.percent / remainingTotal)
            return copy
        }

        return normalized(updated)
    }

    static func resetToDefaults() -> [MoneyDestinationConfig] {
        MoneyDestinationConfig.defaults
    }

    private static func distributeEvenly(_ destinations: [MoneyDestinationConfig]) -> [MoneyDestinationConfig] {
        guard !destinations.isEmpty else {
            return MoneyDestinationConfig.defaults
        }

        let evenShare = 1.0 / Double(destinations.count)
        return destinations.map { destination in
            var updated = destination
            updated.percent = evenShare
            return updated
        }
    }
}
