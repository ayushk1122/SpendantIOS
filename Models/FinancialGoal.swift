import Foundation
import SwiftData

@Model
final class FinancialGoal {
    var id: UUID
    var name: String
    var targetAmount: Double
    var currentAmount: Double
    var monthlyContributionGoal: Double
    var goalType: String
    var createdAt: Date

    init(
        name: String,
        targetAmount: Double,
        currentAmount: Double = 0,
        monthlyContributionGoal: Double = 0,
        goalType: String = "Savings",
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.monthlyContributionGoal = monthlyContributionGoal
        self.goalType = goalType
        self.createdAt = createdAt
    }
}
