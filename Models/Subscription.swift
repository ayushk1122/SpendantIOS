import Foundation
import SwiftData

@Model
final class Subscription {
    var id: UUID
    var name: String
    var amount: Double
    var renewalDate: Date
    var category: String
    var createdAt: Date

    init(
        name: String,
        amount: Double,
        renewalDate: Date = .now,
        category: String = "Subscription",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.amount = amount
        self.renewalDate = renewalDate
        self.category = category
        self.createdAt = createdAt
    }
}
