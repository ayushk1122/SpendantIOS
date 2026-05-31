import Foundation
import SwiftData

@Model
final class IncomeSource {
    var id: UUID
    var name: String
    var amount: Double
    var frequency: String
    var nextPayDate: Date
    var createdAt: Date

    init(
        name: String,
        amount: Double,
        frequency: String = "Monthly",
        nextPayDate: Date = .now,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.frequency = frequency
        self.nextPayDate = nextPayDate
        self.createdAt = createdAt
    }
}
