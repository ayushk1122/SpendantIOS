import Foundation
import Combine

struct MoneyDestination: Identifiable {
    let id: UUID
    let name: String
    let percent: Double
    let icon: String

    init(config: MoneyDestinationConfig) {
        self.id = config.id
        self.name = config.name
        self.percent = config.percent
        self.icon = config.icon
    }

    func amount(from safeToMoveAmount: Double) -> Double {
        safeToMoveAmount * percent
    }

    var percentText: String {
        "\(Int((percent * 100).rounded()))%"
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
        events.contains { abs($0.amount) > 0.01 }
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
    @Published var selectedMonth: DashboardMonth = .current
    @Published var isHistoricalMode: Bool = false

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

    func loadDashboardSummary(
        settings: UserSettings? = nil,
        month: DashboardMonth? = nil
    ) async {
        if let month {
            selectedMonth = month
        }

        isLoading = true
        errorMessage = nil

        do {
            let requestedProtectedBalance = settings?.minimumCheckingBuffer
            let summary = try await PlaidAPIService.shared.fetchDashboardSummary(
                protectedBalance: requestedProtectedBalance,
                month: selectedMonth
            )
            let protectedBalance = requestedProtectedBalance ?? summary.protectedBalance
            isHistoricalMode = summary.isHistorical || selectedMonth.isHistorical
            let safeToMoveTodayAmount = max(
                0,
                isHistoricalMode ? summary.safeToMoveAmount : summary.safeToMoveToday
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
                protectedBalance: protectedBalance,
                selectedMonth: selectedMonth,
                isHistoricalMode: isHistoricalMode
            )
            monthlyBreakdown = summary
            destinations = Self.makeDestinations(settings: settings, summary: summary)

            result = Self.makeCashFlowResult(
                safeToMoveAmount: safeToMoveTodayAmount,
                settings: settings,
                monthEndBalance: summary.projectedMonthEndBalance,
                protectedBalance: protectedBalance,
                lowestDate: summary.lowestProjectedBalanceDate,
                selectedMonth: selectedMonth,
                isHistoricalMode: isHistoricalMode
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func finalizePreviousMonthSnapshotIfNeeded(settings: UserSettings?) async -> UserSettings? {
        guard let settings,
              let previousMonth = DashboardMonth.previous,
              settings.lastFinalizedSnapshotMonth != previousMonth.apiValue else {
            return settings
        }

        do {
            _ = try await PlaidAPIService.shared.finalizeDashboardSnapshot(
                month: previousMonth,
                protectedBalance: settings.minimumCheckingBuffer,
                destinations: settings.resolvedMoneyDestinations()
            )
            settings.lastFinalizedSnapshotMonth = previousMonth.apiValue
            return settings
        } catch {
            return settings
        }
    }

    func refreshDestinations(from settings: UserSettings?) {
        destinations = Self.makeDestinations(settings: settings, summary: monthlyBreakdown)
        result = Self.makeCashFlowResult(
            safeToMoveAmount: result.safeToMoveAmount,
            settings: settings,
            monthEndBalance: result.projectedEndOfMonthBalance,
            protectedBalance: minimumBuffer,
            lowestDate: lowestProjectedBalanceDate,
            selectedMonth: selectedMonth,
            isHistoricalMode: isHistoricalMode
        )
    }

    func selectMonth(_ month: DashboardMonth, settings: UserSettings?) async {
        await loadDashboardSummary(settings: settings, month: month)
    }

    private static func makeCashFlowResult(
        safeToMoveAmount: Double,
        settings: UserSettings?,
        monthEndBalance: Double,
        protectedBalance: Double,
        lowestDate: String?,
        selectedMonth: DashboardMonth,
        isHistoricalMode: Bool
    ) -> CashFlowResult {
        let monthEndSafeToMove = max(0, monthEndBalance - protectedBalance)

        return CashFlowResult(
            safeToMoveAmount: safeToMoveAmount,
            savingsAllocation: safeToMoveAmount * (settings?.savingsAllocationPercent ?? 0.40),
            investmentAllocation: safeToMoveAmount * (settings?.investmentAllocationPercent ?? 0.35),
            extraBufferAllocation: safeToMoveAmount * (settings?.bufferAllocationPercent ?? 0.10),
            projectedEndOfMonthBalance: monthEndBalance,
            insightMessage: Self.insight(
                for: safeToMoveAmount,
                monthEndSafeToMove: monthEndSafeToMove,
                protectedBalance: protectedBalance,
                lowestDate: lowestDate,
                selectedMonth: selectedMonth,
                isHistoricalMode: isHistoricalMode
            )
        )
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

    private static func makeDestinations(
        settings: UserSettings?,
        summary: DashboardSummaryResponse? = nil
    ) -> [MoneyDestination] {
        if summary?.isHistorical == true,
           let snapshotDestinations = summary?.moneyDestinations,
           !snapshotDestinations.isEmpty {
            return snapshotDestinations
                .map { MoneyDestination(config: $0.toConfig()) }
        }

        let configs = settings?.resolvedMoneyDestinations() ?? MoneyDestinationConfig.defaults
        return configs.map(MoneyDestination.init(config:))
    }

    private static func makeProjectedSafePoints(
        summary: DashboardSummaryResponse,
        protectedBalance: Double,
        selectedMonth: DashboardMonth,
        isHistoricalMode: Bool
    ) -> [ProjectedSafePoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = selectedMonth.startDate
        let monthEnd = selectedMonth.endDate
        let eventDates = summary.cashFlowEvents.compactMap { CashFlowDate.date(from: $0.date) }
        let latestEventDate = eventDates.max()
        let endDate = isHistoricalMode
            ? monthEnd
            : max(monthEnd, latestEventDate ?? monthEnd)
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
        let projectedEvents = isHistoricalMode
            ? []
            : summary.cashFlowEvents.compactMap { event -> (Date, ProjectedSafeEvent)? in
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

        var balance: Double
        if isHistoricalMode {
            let netMonthFlow = postedEvents
                .map(\.1.amount)
                .reduce(0, +)
            balance = summary.projectedMonthEndBalance - netMonthFlow
        } else {
            let postedThroughToday = postedEvents
                .filter { $0.0 <= today }
                .map { $0.1.amount }
                .reduce(0, +)
            balance = summary.checkingBalance - postedThroughToday
        }
        var points: [ProjectedSafePoint] = []
        var currentDate = startDate

        while currentDate <= endDate {
            let dailyEvents = eventsByDay[currentDate, default: []].map(\.1)
            let eventAmount = dailyEvents
                .map(\.amount)
                .reduce(0, +)
            balance += eventAmount

            let safeToMove = max(0, balance - protectedBalance)

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
        lowestDate: String?,
        selectedMonth: DashboardMonth,
        isHistoricalMode: Bool
    ) -> String {
        if isHistoricalMode {
            if safeToMoveAmount <= 0 {
                return "After \(selectedMonth.shortLabel) spending, your checking balance stayed inside your protected buffer."
            }

            return "You finished \(selectedMonth.shortLabel) with \(CurrencyFormatter.dollars(safeToMoveAmount)) available to move after your buffer."
        }

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
