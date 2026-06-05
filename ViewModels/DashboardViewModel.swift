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

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var result: CashFlowResult
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    @Published var incomeTotal: Double = 0
    @Published var housingTotal: Double = 0
    @Published var expenseTotal: Double = 0
    @Published var subscriptionsTotal: Double = 0
    @Published var checkingBalance: Double = 0
    @Published var minimumBuffer: Double = 30
    @Published var transactions: [NormalizedTransaction] = []

    let destinations: [MoneyDestination] = [
        MoneyDestination(name: "Savings Account", percent: 0.40, icon: "banknote.fill"),
        MoneyDestination(name: "Investments", percent: 0.35, icon: "chart.pie.fill"),
        MoneyDestination(name: "Retirement", percent: 0.15, icon: "building.columns.fill"),
        MoneyDestination(name: "Extra Buffer", percent: 0.10, icon: "shield.fill")
    ]

    init() {
        self.result = CashFlowCalculator.calculate(
            inputs: CashFlowInputs(
                checkingBalance: 110,
                remainingIncomeThisMonth: 0,
                upcomingFixedExpenses: 0,
                upcomingSubscriptions: 0,
                creditCardPaymentAmount: 0,
                minimumCheckingBuffer: 30,
                estimatedVariableSpendingRemaining: 0
            )
        )
    }

    func loadDashboardSummary() async {
        isLoading = true
        errorMessage = nil

        do {
            let summary = try await PlaidAPIService.shared.fetchDashboardSummary()

            checkingBalance = summary.checkingBalance
            incomeTotal = summary.incomeTotal
            housingTotal = summary.housingTotal
            expenseTotal = summary.expensesTotal
            subscriptionsTotal = summary.subscriptionsTotal
            minimumBuffer = summary.protectedBalance
            transactions = summary.transactions

            result = CashFlowResult(
                safeToMoveAmount: summary.safeToMoveAmount,
                savingsAllocation: summary.safeToMoveAmount * 0.40,
                investmentAllocation: summary.safeToMoveAmount * 0.35,
                extraBufferAllocation: summary.safeToMoveAmount * 0.10,
                projectedEndOfMonthBalance: summary.projectedMonthEndBalance,
                insightMessage: ""
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    var statusColor: ColorStatus {
        guard minimumBuffer > 0 else {
            return .healthy
        }

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
