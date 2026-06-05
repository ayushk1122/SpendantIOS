import Foundation
import SwiftData

@Model
final class UserSettings {
    var id: UUID
    var checkingBalance: Double
    var minimumCheckingBuffer: Double
    var estimatedVariableSpendingRemaining: Double
    var savingsAllocationPercent: Double
    var investmentAllocationPercent: Double
    var bufferAllocationPercent: Double
    var createdAt: Date

    init(
        checkingBalance: Double = 5000,
        minimumCheckingBuffer: Double = 30,
        estimatedVariableSpendingRemaining: Double = 1200,
        savingsAllocationPercent: Double = 0.50,
        investmentAllocationPercent: Double = 0.35,
        bufferAllocationPercent: Double = 0.15,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.checkingBalance = checkingBalance
        self.minimumCheckingBuffer = minimumCheckingBuffer
        self.estimatedVariableSpendingRemaining = estimatedVariableSpendingRemaining
        self.savingsAllocationPercent = savingsAllocationPercent
        self.investmentAllocationPercent = investmentAllocationPercent
        self.bufferAllocationPercent = bufferAllocationPercent
        self.createdAt = createdAt
    }
}
