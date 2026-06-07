import Foundation
import SwiftData

@Model
final class UserSettings {
    var id: UUID
    var hasCompletedOnboarding: Bool
    var hasLinkedPlaid: Bool
    var checkingBalance: Double
    var minimumCheckingBuffer: Double
    var estimatedVariableSpendingRemaining: Double
    var savingsAllocationPercent: Double
    var investmentAllocationPercent: Double
    var retirementAllocationPercent: Double
    var bufferAllocationPercent: Double
    var moneyDestinationsData: Data?
    var createdAt: Date

    init(
        hasCompletedOnboarding: Bool = false,
        hasLinkedPlaid: Bool = false,
        checkingBalance: Double = 5000,
        minimumCheckingBuffer: Double = 30,
        estimatedVariableSpendingRemaining: Double = 1200,
        savingsAllocationPercent: Double = 0.40,
        investmentAllocationPercent: Double = 0.35,
        retirementAllocationPercent: Double = 0.15,
        bufferAllocationPercent: Double = 0.10,
        moneyDestinationsData: Data? = nil,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.hasLinkedPlaid = hasLinkedPlaid
        self.checkingBalance = checkingBalance
        self.minimumCheckingBuffer = minimumCheckingBuffer
        self.estimatedVariableSpendingRemaining = estimatedVariableSpendingRemaining
        self.savingsAllocationPercent = savingsAllocationPercent
        self.investmentAllocationPercent = investmentAllocationPercent
        self.retirementAllocationPercent = retirementAllocationPercent
        self.bufferAllocationPercent = bufferAllocationPercent
        self.moneyDestinationsData = moneyDestinationsData
        self.createdAt = createdAt
    }

    var allocationTotal: Double {
        savingsAllocationPercent
        + investmentAllocationPercent
        + retirementAllocationPercent
        + bufferAllocationPercent
    }

    func applyBalancedAllocation() {
        applyBalancedMoneyDestinations()
    }

    func applyConservativeAllocation() {
        applyConservativeMoneyDestinations()
    }

    func applyGrowthAllocation() {
        applyGrowthMoneyDestinations()
    }
}
