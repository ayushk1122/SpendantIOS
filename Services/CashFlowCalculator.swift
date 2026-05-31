import Foundation

struct CashFlowInputs {
    let checkingBalance: Double
    let remainingIncomeThisMonth: Double
    let upcomingFixedExpenses: Double
    let upcomingSubscriptions: Double
    let creditCardPaymentAmount: Double
    let minimumCheckingBuffer: Double
    let estimatedVariableSpendingRemaining: Double
}

struct CashFlowResult {
    let safeToMoveAmount: Double
    let savingsAllocation: Double
    let investmentAllocation: Double
    let extraBufferAllocation: Double
    let projectedEndOfMonthBalance: Double
    let insightMessage: String
}

struct CashFlowCalculator {
    static func calculate(inputs: CashFlowInputs) -> CashFlowResult {
        let projectedEndOfMonthBalance =
            inputs.checkingBalance
            + inputs.remainingIncomeThisMonth
            - inputs.upcomingFixedExpenses
            - inputs.upcomingSubscriptions
            - inputs.creditCardPaymentAmount
            - inputs.estimatedVariableSpendingRemaining

        let safeToMoveAmount = max(
            0,
            projectedEndOfMonthBalance - inputs.minimumCheckingBuffer
        )

        let savings = safeToMoveAmount * 0.50
        let investments = safeToMoveAmount * 0.35
        let buffer = safeToMoveAmount * 0.15

        let insight: String

        if safeToMoveAmount <= 0 {
            insight = "Your spending is reducing your safe-to-save amount this month."
        } else if safeToMoveAmount < 500 {
            insight = "You have some room, but keep spending tight this month."
        } else {
            insight = "You’re on track this month."
        }

        return CashFlowResult(
            safeToMoveAmount: safeToMoveAmount,
            savingsAllocation: savings,
            investmentAllocation: investments,
            extraBufferAllocation: buffer,
            projectedEndOfMonthBalance: projectedEndOfMonthBalance,
            insightMessage: insight
        )
    }
}
