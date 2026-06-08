import Foundation

struct DashboardSummaryResponse: Decodable {
    let month: String?
    let isHistorical: Bool
    let snapshotSource: String
    let snapshotFinalizedAt: String?
    let checkingBalance: Double
    let incomeTotal: Double
    let housingTotal: Double
    let expensesTotal: Double
    let subscriptionsTotal: Double
    let transferTotal: Double
    let incomePostedTotal: Double
    let housingPostedTotal: Double
    let expensesPostedTotal: Double
    let subscriptionsPostedTotal: Double
    let creditCardPaymentsPostedTotal: Double
    let incomeUpcomingTotal: Double
    let housingUpcomingTotal: Double
    let subscriptionsUpcomingTotal: Double
    let creditCardPaymentsUpcomingTotal: Double
    let protectedBalance: Double
    let projectedMonthEndBalance: Double
    let safeToMoveAmount: Double
    let safeToMoveToday: Double
    let lowestProjectedBalance: Double
    let lowestProjectedBalanceDate: String?
    let transactions: [NormalizedTransaction]
    let recurringStreams: [RecurringStream]
    let creditCardObligations: [CreditCardObligation]
    let cashFlowEvents: [CashFlowEvent]
    let moneyDestinations: [MoneyDestinationSnapshot]?

    enum CodingKeys: String, CodingKey {
        case month
        case isHistorical = "is_historical"
        case snapshotSource = "snapshot_source"
        case snapshotFinalizedAt = "snapshot_finalized_at"
        case checkingBalance = "checking_balance"
        case incomeTotal = "income_total"
        case housingTotal = "housing_total"
        case expensesTotal = "expenses_total"
        case subscriptionsTotal = "subscriptions_total"
        case transferTotal = "transfer_total"
        case incomePostedTotal = "income_posted_total"
        case housingPostedTotal = "housing_posted_total"
        case expensesPostedTotal = "expenses_posted_total"
        case subscriptionsPostedTotal = "subscriptions_posted_total"
        case creditCardPaymentsPostedTotal = "credit_card_payments_posted_total"
        case incomeUpcomingTotal = "income_upcoming_total"
        case housingUpcomingTotal = "housing_upcoming_total"
        case subscriptionsUpcomingTotal = "subscriptions_upcoming_total"
        case creditCardPaymentsUpcomingTotal = "credit_card_payments_upcoming_total"
        case protectedBalance = "protected_balance"
        case projectedMonthEndBalance = "projected_month_end_balance"
        case safeToMoveAmount = "safe_to_move_amount"
        case safeToMoveToday = "safe_to_move_today"
        case lowestProjectedBalance = "lowest_projected_balance"
        case lowestProjectedBalanceDate = "lowest_projected_balance_date"
        case transactions
        case recurringStreams = "recurring_streams"
        case creditCardObligations = "credit_card_obligations"
        case cashFlowEvents = "cash_flow_events"
        case moneyDestinations = "money_destinations"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        month = try container.decodeIfPresent(String.self, forKey: .month)
        isHistorical = try container.decodeIfPresent(Bool.self, forKey: .isHistorical) ?? false
        snapshotSource = try container.decodeIfPresent(String.self, forKey: .snapshotSource) ?? "live"
        snapshotFinalizedAt = try container.decodeIfPresent(String.self, forKey: .snapshotFinalizedAt)
        checkingBalance = try container.decode(Double.self, forKey: .checkingBalance)
        incomeTotal = try container.decode(Double.self, forKey: .incomeTotal)
        housingTotal = try container.decode(Double.self, forKey: .housingTotal)
        expensesTotal = try container.decode(Double.self, forKey: .expensesTotal)
        subscriptionsTotal = try container.decode(Double.self, forKey: .subscriptionsTotal)
        transferTotal = try container.decode(Double.self, forKey: .transferTotal)
        incomePostedTotal = try container.decodeIfPresent(Double.self, forKey: .incomePostedTotal) ?? incomeTotal
        housingPostedTotal = try container.decodeIfPresent(Double.self, forKey: .housingPostedTotal) ?? housingTotal
        expensesPostedTotal = try container.decodeIfPresent(Double.self, forKey: .expensesPostedTotal) ?? expensesTotal
        subscriptionsPostedTotal = try container.decodeIfPresent(Double.self, forKey: .subscriptionsPostedTotal) ?? 0
        creditCardPaymentsPostedTotal = try container.decodeIfPresent(
            Double.self,
            forKey: .creditCardPaymentsPostedTotal
        ) ?? 0
        incomeUpcomingTotal = try container.decodeIfPresent(Double.self, forKey: .incomeUpcomingTotal) ?? 0
        housingUpcomingTotal = try container.decodeIfPresent(Double.self, forKey: .housingUpcomingTotal) ?? 0
        subscriptionsUpcomingTotal = try container.decodeIfPresent(
            Double.self,
            forKey: .subscriptionsUpcomingTotal
        ) ?? max(0, subscriptionsTotal - subscriptionsPostedTotal)
        creditCardPaymentsUpcomingTotal = try container.decodeIfPresent(
            Double.self,
            forKey: .creditCardPaymentsUpcomingTotal
        ) ?? max(0, transferTotal - creditCardPaymentsPostedTotal)
        protectedBalance = try container.decode(Double.self, forKey: .protectedBalance)
        projectedMonthEndBalance = try container.decode(Double.self, forKey: .projectedMonthEndBalance)
        safeToMoveAmount = try container.decode(Double.self, forKey: .safeToMoveAmount)
        safeToMoveToday = try container.decodeIfPresent(Double.self, forKey: .safeToMoveToday)
            ?? safeToMoveAmount
        lowestProjectedBalance = try container.decodeIfPresent(
            Double.self,
            forKey: .lowestProjectedBalance
        ) ?? checkingBalance
        lowestProjectedBalanceDate = try container.decodeIfPresent(
            String.self,
            forKey: .lowestProjectedBalanceDate
        )
        transactions = try container.decode([NormalizedTransaction].self, forKey: .transactions)
        recurringStreams = try container.decodeIfPresent(
            [RecurringStream].self,
            forKey: .recurringStreams
        ) ?? []
        creditCardObligations = try container.decodeIfPresent(
            [CreditCardObligation].self,
            forKey: .creditCardObligations
        ) ?? []
        cashFlowEvents = try container.decodeIfPresent(
            [CashFlowEvent].self,
            forKey: .cashFlowEvents
        ) ?? []
        moneyDestinations = try container.decodeIfPresent(
            [MoneyDestinationSnapshot].self,
            forKey: .moneyDestinations
        )
    }

    func breakdown(for bucket: CashFlowBucket) -> MonthlyBucketBreakdown {
        switch bucket {
        case .income:
            return MonthlyBucketBreakdown(
                posted: incomePostedTotal,
                upcoming: incomeUpcomingTotal,
                bucket: bucket
            )
        case .housing:
            return MonthlyBucketBreakdown(
                posted: housingPostedTotal,
                upcoming: housingUpcomingTotal,
                bucket: bucket
            )
        case .expenses:
            return MonthlyBucketBreakdown(
                posted: expensesPostedTotal,
                upcoming: 0,
                bucket: bucket
            )
        case .subscriptions:
            return MonthlyBucketBreakdown(
                posted: subscriptionsPostedTotal,
                upcoming: subscriptionsUpcomingTotal,
                bucket: bucket
            )
        case .transfers:
            return MonthlyBucketBreakdown(
                posted: creditCardPaymentsPostedTotal,
                upcoming: creditCardPaymentsUpcomingTotal,
                bucket: bucket
            )
        }
    }
}

struct CreditCardObligation: Decodable, Identifiable {
    let accountID: String
    let accountName: String
    let institutionName: String?
    let currentBalance: Double?
    let lastStatementBalance: Double?
    let minimumPaymentAmount: Double?
    let nextPaymentDueDate: String?
    let lastStatementIssueDate: String?
    let lastPaymentAmount: Double?
    let lastPaymentDate: String?
    let projectedPaymentAmount: Double
    let paymentStrategy: String
    let isAlreadyPaidThisCycle: Bool

    var id: String { accountID }

    enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case accountName = "account_name"
        case institutionName = "institution_name"
        case currentBalance = "current_balance"
        case lastStatementBalance = "last_statement_balance"
        case minimumPaymentAmount = "minimum_payment_amount"
        case nextPaymentDueDate = "next_payment_due_date"
        case lastStatementIssueDate = "last_statement_issue_date"
        case lastPaymentAmount = "last_payment_amount"
        case lastPaymentDate = "last_payment_date"
        case projectedPaymentAmount = "projected_payment_amount"
        case paymentStrategy = "payment_strategy"
        case isAlreadyPaidThisCycle = "is_already_paid_this_cycle"
    }
}

struct CashFlowEvent: Decodable, Identifiable {
    let date: String
    let amount: Double
    let bucket: String
    let label: String
    let accountID: String?
    let source: String

    var id: String { "\(date)-\(label)-\(amount)" }

    enum CodingKeys: String, CodingKey {
        case date
        case amount
        case bucket
        case label
        case accountID = "account_id"
        case source
    }
}

struct MonthlyBucketBreakdown {
    let posted: Double
    let upcoming: Double
    let bucket: CashFlowBucket

    var total: Double {
        switch bucket {
        case .income:
            return posted + upcoming
        case .expenses:
            return posted
        default:
            return posted + upcoming
        }
    }
}

struct RecurringStream: Decodable, Identifiable {
    let streamID: String
    let accountID: String?
    let description: String
    let merchantName: String?
    let bucket: String
    let frequency: String?
    let status: String?
    let isActive: Bool
    let averageAmount: Double?
    let lastAmount: Double?
    let firstDate: String?
    let lastDate: String?
    let predictedNextDate: String?
    let transactionIDs: [String]
    let plaidPrimaryCategory: String?
    let plaidDetailedCategory: String?

    var id: String { streamID }

    func displayName(linkedTransaction: NormalizedTransaction? = nil) -> String {
        if let linkedTransaction {
            return linkedTransaction.displayTitle
        }

        return TransactionTitleFormatter.title(
            merchantName: merchantName,
            name: description,
            categoryDetailed: plaidDetailedCategory,
            categoryPrimary: plaidPrimaryCategory
        )
    }

    func categorySubtitle(linkedTransaction: NormalizedTransaction? = nil) -> String {
        if let linkedTransaction {
            return linkedTransaction.categorySubtitle
        }

        return TransactionTitleFormatter.categorySubtitle(
            detailed: plaidDetailedCategory,
            primary: plaidPrimaryCategory
        )
    }

    enum CodingKeys: String, CodingKey {
        case streamID = "stream_id"
        case accountID = "account_id"
        case description
        case merchantName = "merchant_name"
        case bucket
        case frequency
        case status
        case isActive = "is_active"
        case averageAmount = "average_amount"
        case lastAmount = "last_amount"
        case firstDate = "first_date"
        case lastDate = "last_date"
        case predictedNextDate = "predicted_next_date"
        case transactionIDs = "transaction_ids"
        case plaidPrimaryCategory = "plaid_primary_category"
        case plaidDetailedCategory = "plaid_detailed_category"
    }
}

struct NormalizedTransaction: Decodable, Identifiable {
    let transactionID: String
    let accountID: String?
    let name: String
    let merchantName: String?
    let amount: Double
    let date: String
    let bucket: String
    let pending: Bool
    let plaidPrimaryCategory: String?
    let plaidDetailedCategory: String?

    var id: String { transactionID }

    var displayTitle: String {
        TransactionTitleFormatter.title(
            merchantName: merchantName,
            name: name,
            categoryDetailed: plaidDetailedCategory,
            categoryPrimary: plaidPrimaryCategory
        )
    }

    var categorySubtitle: String {
        TransactionTitleFormatter.categorySubtitle(
            detailed: plaidDetailedCategory,
            primary: plaidPrimaryCategory
        )
    }

    enum CodingKeys: String, CodingKey {
        case transactionID = "transaction_id"
        case accountID = "account_id"
        case name
        case merchantName = "merchant_name"
        case amount
        case date
        case bucket
        case pending
        case plaidPrimaryCategory = "plaid_primary_category"
        case plaidDetailedCategory = "plaid_detailed_category"
    }
}

enum CashFlowBucket: String, CaseIterable, Identifiable {
    case income = "INCOME"
    case housing = "HOUSING"
    case expenses = "EXPENSES"
    case subscriptions = "SUBSCRIPTIONS"
    case transfers = "TRANSFER"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income:
            return "Income"
        case .housing:
            return "Housing"
        case .expenses:
            return "Expenses"
        case .subscriptions:
            return "Subscriptions"
        case .transfers:
            return "Card Payments"
        }
    }

    var icon: String {
        switch self {
        case .income:
            return "arrow.down.circle.fill"
        case .housing:
            return "house.fill"
        case .expenses:
            return "creditcard.fill"
        case .subscriptions:
            return "repeat.circle.fill"
        case .transfers:
            return "arrow.left.arrow.right.circle.fill"
        }
    }

    var supportsUpcomingRecurring: Bool {
        self != .expenses
    }

    func transactions(from allTransactions: [NormalizedTransaction]) -> [NormalizedTransaction] {
        allTransactions
            .filter { $0.bucket == rawValue }
            .sorted { $0.date > $1.date }
    }

    func recurringStreams(
        from allStreams: [RecurringStream],
        currentMonthTransactionIDs: Set<String>,
        month: DashboardMonth = .current
    ) -> [RecurringStream] {
        guard supportsUpcomingRecurring else {
            return []
        }

        return allStreams.filter { stream in
            guard stream.bucket == rawValue, stream.isActive else {
                return false
            }

            guard CashFlowDate.isInMonth(stream.predictedNextDate, month: month) else {
                return false
            }

            return !stream.transactionIDs.contains { currentMonthTransactionIDs.contains($0) }
        }
    }
}

enum CashFlowDate {
    static func date(from value: String?) -> Date? {
        guard let value else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }

    static func isCurrentMonth(_ value: String?) -> Bool {
        isInMonth(value, month: DashboardMonth.current)
    }

    static func isInMonth(_ value: String?, month: DashboardMonth) -> Bool {
        guard let date = date(from: value) else {
            return false
        }

        let calendar = Calendar.current
        return calendar.component(.year, from: date) == month.year
            && calendar.component(.month, from: date) == month.month
    }

    static func formatted(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let output = DateFormatter()
        output.dateStyle = .medium

        guard let date = date(from: value) else {
            return value
        }

        return output.string(from: date)
    }
}
