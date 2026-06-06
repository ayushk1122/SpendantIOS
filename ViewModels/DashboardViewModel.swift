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
    @Published var destinations: [MoneyDestination]

    init() {
        self.destinations = Self.makeDestinations(settings: nil)
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

    func loadDashboardSummary(settings: UserSettings? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            let summary = try await PlaidAPIService.shared.fetchDashboardSummary()
            let protectedBalance = settings?.minimumCheckingBuffer ?? summary.protectedBalance
            let safeToMoveAmount = max(
                0,
                summary.projectedMonthEndBalance - protectedBalance
            )

            checkingBalance = summary.checkingBalance
            incomeTotal = summary.incomeTotal
            housingTotal = summary.housingTotal
            expenseTotal = summary.expensesTotal
            subscriptionsTotal = summary.subscriptionsTotal
            minimumBuffer = protectedBalance
            transactions = summary.transactions
            destinations = Self.makeDestinations(settings: settings)

            result = CashFlowResult(
                safeToMoveAmount: safeToMoveAmount,
                savingsAllocation: safeToMoveAmount * (settings?.savingsAllocationPercent ?? 0.40),
                investmentAllocation: safeToMoveAmount * (settings?.investmentAllocationPercent ?? 0.35),
                extraBufferAllocation: safeToMoveAmount * (settings?.bufferAllocationPercent ?? 0.10),
                projectedEndOfMonthBalance: summary.projectedMonthEndBalance,
                insightMessage: Self.insight(
                    for: safeToMoveAmount,
                    protectedBalance: protectedBalance
                )
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

    private static func makeDestinations(settings: UserSettings?) -> [MoneyDestination] {
        [
            MoneyDestination(
                name: "Savings Account",
                percent: settings?.savingsAllocationPercent ?? 0.40,
                icon: "banknote.fill"
            ),
            MoneyDestination(
                name: "Investments",
                percent: settings?.investmentAllocationPercent ?? 0.35,
                icon: "chart.pie.fill"
            ),
            MoneyDestination(
                name: "Retirement",
                percent: settings?.retirementAllocationPercent ?? 0.15,
                icon: "building.columns.fill"
            ),
            MoneyDestination(
                name: "Extra Buffer",
                percent: settings?.bufferAllocationPercent ?? 0.10,
                icon: "shield.fill"
            )
        ]
    }

    private static func insight(for safeToMoveAmount: Double, protectedBalance: Double) -> String {
        if safeToMoveAmount <= 0 {
            return "Your projected balance is inside your protected buffer."
        }

        if safeToMoveAmount < protectedBalance {
            return "You have room to move money, but keep the month tight."
        }

        return "You are on track to move money with your protected balance intact."
    }
}

enum ColorStatus {
    case healthy
    case tight
    case risk
}
