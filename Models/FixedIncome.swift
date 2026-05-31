import Foundation
import SwiftData

@Model
final class FixedExpense {
    var id: UUID
    var name: String
    var amount: Double
    var dueDate: Date
    var frequency: String
    var category: String
    var createdAt: Date

    init(
        name: String,
        amount: Double,
        dueDate: Date = .now,
        frequency: String = "Monthly",
        category: String = "Fixed Expense",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.dueDate = dueDate
        self.frequency = frequency
        self.category = category
        self.createdAt = createdAt
    }
}
