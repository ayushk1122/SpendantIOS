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

struct ProjectedSafePoint: Identifiable {
    let id = UUID()
    let date: Date
    let accountBalance: Double
    let safeToMove: Double
    let eventAmount: Double
    let events: [ProjectedSafeEvent]

    var hasEvent: Bool {
        abs(eventAmount) > 0.01
    }

    var isCashOutflow: Bool {
        eventAmount < 0
    }
}

struct ProjectedSafeEvent: Identifiable {
    let id = UUID()
    let label: String
    let amount: Double
    let bucket: String
    let source: String

    var isCashOutflow: Bool {
        amount < 0
    }

    var displayLabel: String {
        if label.lowercased().contains("projected remaining variable spending") {
            return "Projected spending"
        }

        return label
    }

    var sourceLabel: String {
        switch source {
        case "posted":
            return "Posted"
        case "liability":
            return "Card payment"
        case "projection":
            return "Projected"
        default:
            return source.capitalized
        }
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
    @Published var transferTotal: Double = 0
    @Published var checkingBalance: Double = 0
    @Published var minimumBuffer: Double = 30
    @Published var transactions: [NormalizedTransaction] = []
    @Published var recurringStreams: [RecurringStream] = []
    @Published var creditCardObligations: [CreditCardObligation] = []
    @Published var cashFlowEvents: [CashFlowEvent] = []
    @Published var monthlyBreakdown: DashboardSummaryResponse?
    @Published var safeToMoveToday: Double = 0
    @Published var lowestProjectedBalance: Double = 0
    @Published var lowestProjectedBalanceDate: String?
    @Published var projectedSafePoints: [ProjectedSafePoint] = []
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
            let requestedProtectedBalance = settings?.minimumCheckingBuffer
            let summary = try await PlaidAPIService.shared.fetchDashboardSummary(
                protectedBalance: requestedProtectedBalance
            )
            let protectedBalance = requestedProtectedBalance ?? summary.protectedBalance
            let safeToMoveTodayAmount = max(
                0,
                summary.safeToMoveToday
            )
            let monthEndSafeToMove = max(
                0,
                summary.projectedMonthEndBalance - protectedBalance
            )

            checkingBalance = summary.checkingBalance
            incomeTotal = summary.incomeTotal
            housingTotal = summary.housingTotal
            expenseTotal = summary.expensesTotal
            subscriptionsTotal = summary.subscriptionsTotal
            transferTotal = summary.transferTotal
            minimumBuffer = protectedBalance
            transactions = summary.transactions
            recurringStreams = summary.recurringStreams
            creditCardObligations = summary.creditCardObligations
            cashFlowEvents = summary.cashFlowEvents
            safeToMoveToday = safeToMoveTodayAmount
            lowestProjectedBalance = summary.lowestProjectedBalance
            lowestProjectedBalanceDate = summary.lowestProjectedBalanceDate
            projectedSafePoints = Self.makeProjectedSafePoints(
                summary: summary,
                protectedBalance: protectedBalance
            )
            monthlyBreakdown = summary
            destinations = Self.makeDestinations(settings: settings)

            result = CashFlowResult(
                safeToMoveAmount: safeToMoveTodayAmount,
                savingsAllocation: safeToMoveTodayAmount * (settings?.savingsAllocationPercent ?? 0.40),
                investmentAllocation: safeToMoveTodayAmount * (settings?.investmentAllocationPercent ?? 0.35),
                extraBufferAllocation: safeToMoveTodayAmount * (settings?.bufferAllocationPercent ?? 0.10),
                projectedEndOfMonthBalance: summary.projectedMonthEndBalance,
                insightMessage: Self.insight(
                    for: safeToMoveTodayAmount,
                    monthEndSafeToMove: monthEndSafeToMove,
                    protectedBalance: protectedBalance,
                    lowestDate: summary.lowestProjectedBalanceDate
                )
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func breakdown(for bucket: CashFlowBucket) -> MonthlyBucketBreakdown {
        monthlyBreakdown?.breakdown(for: bucket)
            ?? MonthlyBucketBreakdown(posted: 0, upcoming: 0, bucket: bucket)
    }

    var projectedMonthEndSafe: Double {
        guard let lastPoint = projectedSafePoints.last else {
            return max(0, result.projectedEndOfMonthBalance - minimumBuffer)
        }

        return lastPoint.safeToMove
    }

    var projectedLowPoint: ProjectedSafePoint? {
        projectedSafePoints.min { $0.safeToMove < $1.safeToMove }
    }

    var largestUpcomingOutflow: CashFlowEvent? {
        cashFlowEvents
            .filter { $0.amount < 0 }
            .min { $0.amount < $1.amount }
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

    private static func makeProjectedSafePoints(
        summary: DashboardSummaryResponse,
        protectedBalance: Double
    ) -> [ProjectedSafePoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(
            from: calendar.dateComponents([.year, .month], from: today)
        ) ?? today
        let eventDates = summary.cashFlowEvents.compactMap { CashFlowDate.date(from: $0.date) }
        let latestEventDate = eventDates.max()
        let monthEnd = calendar.date(
            from: calendar.dateComponents([.year, .month], from: today)
        )
            .flatMap { calendar.date(byAdding: DateComponents(month: 1, day: -1), to: $0) }
            ?? today
        let endDate = max(monthEnd, latestEventDate ?? monthEnd)
        let postedEvents = summary.transactions.compactMap { transaction -> (Date, ProjectedSafeEvent)? in
            guard let date = CashFlowDate.date(from: transaction.date) else {
                return nil
            }

            let signedAmount = transaction.bucket == CashFlowBucket.income.rawValue
                ? abs(transaction.amount)
                : -abs(transaction.amount)
            return (
                calendar.startOfDay(for: date),
                ProjectedSafeEvent(
                    label: transaction.displayTitle,
                    amount: signedAmount,
                    bucket: transaction.bucket,
                    source: "posted"
                )
            )
        }
        let projectedEvents = summary.cashFlowEvents.compactMap { event -> (Date, ProjectedSafeEvent)? in
            guard let date = CashFlowDate.date(from: event.date) else {
                return nil
            }

            return (
                calendar.startOfDay(for: date),
                ProjectedSafeEvent(
                    label: event.label,
                    amount: event.amount,
                    bucket: event.bucket,
                    source: event.source
                )
            )
        }
        let allEvents = postedEvents + projectedEvents
        let eventsByDay = Dictionary(grouping: allEvents, by: { $0.0 })
        let postedThroughToday = postedEvents
            .filter { $0.0 <= today }
            .map { $0.1.amount }
            .reduce(0, +)

        var balance = summary.checkingBalance - postedThroughToday
        var points: [ProjectedSafePoint] = []
        var currentDate = startDate

        while currentDate <= endDate {
            let dailyEvents = eventsByDay[currentDate, default: []].map(\.1)
            let eventAmount = dailyEvents
                .map(\.amount)
                .reduce(0, +)
            balance += eventAmount

            var safeToMove = max(0, balance - protectedBalance)
            if calendar.isDate(currentDate, inSameDayAs: today) {
                safeToMove = max(0, summary.safeToMoveToday)
            }

            points.append(
                ProjectedSafePoint(
                    date: currentDate,
                    accountBalance: balance,
                    safeToMove: safeToMove,
                    eventAmount: eventAmount,
                    events: dailyEvents
                )
            )

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return points
    }

    private static func insight(
        for safeToMoveAmount: Double,
        monthEndSafeToMove: Double,
        protectedBalance: Double,
        lowestDate: String?
    ) -> String {
        if safeToMoveAmount <= 0 {
            if let lowestDate, let formatted = CashFlowDate.formatted(lowestDate) {
                return "Your checking balance is projected to dip below your protected buffer around \(formatted)."
            }

            return "Your projected balance is inside your protected buffer."
        }

        if safeToMoveAmount < protectedBalance {
            return "You have room to move money today, but upcoming bills will tighten cash flow."
        }

        if monthEndSafeToMove > safeToMoveAmount {
            return "You can move some money now, and more may open up by month-end."
        }

        return "You are on track to move money with your protected balance intact."
    }
}

enum ColorStatus {
    case healthy
    case tight
    case risk
}
