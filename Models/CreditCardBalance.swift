import Foundation
import SwiftData

@Model
final class CreditCardBalance {
    var id: UUID
    var cardName: String
    var currentBalance: Double
    var minimumPayment: Double
    var dueDate: Date
    var createdAt: Date

    init(
        cardName: String,
        currentBalance: Double,
        minimumPayment: Double = 0,
        dueDate: Date = .now,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.cardName = cardName
        self.currentBalance = currentBalance
        self.minimumPayment = minimumPayment
        self.dueDate = dueDate
        self.createdAt = createdAt
    }
}
