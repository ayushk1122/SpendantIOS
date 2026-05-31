import Foundation
import Combine

struct MoneyDestination: Identifiable {
    let id = UUID()
    let name: String
    let percent: Double
    let icon: String

    func amount(from safeToMoveAmount: Double) -> Double {
        safeToMoveAmount * percent
    }

    var percentText: String {
        "\(Int(percent * 100))%"
    }
}

final class DashboardViewModel: ObservableObject {
    @Published var result: CashFlowResult

    let incomeTotal: Double = 3162
    let housingTotal: Double = 3000
    let expenseTotal: Double = 900
    let subscriptionsTotal: Double = 185
    let minimumBuffer: Double = 2000

    let destinations: [MoneyDestination] = [
        MoneyDestination(name: "Savings Account", percent: 0.40, icon: "banknote.fill"),
        MoneyDestination(name: "Investments", percent: 0.35, icon: "chart.pie.fill"),
        MoneyDestination(name: "Retirement", percent: 0.15, icon: "building.columns.fill"),
        MoneyDestination(name: "Extra Buffer", percent: 0.10, icon: "shield.fill")
    ]

    init() {
        let mockInputs = CashFlowInputs(
            checkingBalance: 6200,
            remainingIncomeThisMonth: incomeTotal,
            upcomingFixedExpenses: housingTotal,
            upcomingSubscriptions: subscriptionsTotal,
            creditCardPaymentAmount: 1450,
            minimumCheckingBuffer: minimumBuffer,
            estimatedVariableSpendingRemaining: expenseTotal
        )

        self.result = CashFlowCalculator.calculate(inputs: mockInputs)
    }

    var statusColor: ColorStatus {
        let ratio = result.safeToMoveAmount / minimumBuffer

        if ratio >= 0.75 {
            return .healthy
        } else if ratio >= 0.35 {
            return .tight
        } else {
            return .risk
        }
    }
}

enum ColorStatus {
    case healthy
    case tight
    case risk
}
