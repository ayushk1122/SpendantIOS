import SwiftUI

struct CashFlowView: View {
    let bucket: CashFlowBucket
    let breakdown: MonthlyBucketBreakdown
    let transactions: [NormalizedTransaction]
    let recurringStreams: [RecurringStream]
    var creditCardObligations: [CreditCardObligation] = []
    var cashFlowEvents: [CashFlowEvent] = []
    var selectedMonth: DashboardMonth = .current
    var isHistoricalMode: Bool = false

    private var currentMonthTransactionIDs: Set<String> {
        Set(transactions.map(\.transactionID))
    }

    private var postedTransactions: [NormalizedTransaction] {
        bucket.transactions(from: transactions)
    }

    private var upcomingRecurringStreams: [RecurringStream] {
        guard !isHistoricalMode else {
            return []
        }

        return bucket.recurringStreams(
            from: recurringStreams,
            currentMonthTransactionIDs: currentMonthTransactionIDs,
            month: selectedMonth
        )
    }

    private var coveredRecurringEventKeys: Set<String> {
        Set(
            upcomingRecurringStreams.compactMap { stream -> String? in
                guard let date = stream.predictedNextDate else {
                    return nil
                }

                return "\(date)-\(stream.bucket)"
            }
        )
    }

    private var upcomingProjectedEvents: [CashFlowEvent] {
        guard !isHistoricalMode, bucket.supportsUpcomingRecurring, bucket != .transfers else {
            return []
        }

        let today = Calendar.current.startOfDay(for: Date())

        return cashFlowEvents
            .filter { event in
                guard event.bucket == bucket.rawValue else {
                    return false
                }

                guard CashFlowDate.isInMonth(event.date, month: selectedMonth) else {
                    return false
                }

                guard let eventDate = CashFlowDate.date(from: event.date), eventDate >= today else {
                    return false
                }

                let eventKey = "\(event.date)-\(event.bucket)"
                return !coveredRecurringEventKeys.contains(eventKey)
            }
            .sorted { $0.date < $1.date }
    }

    private var cardPaymentGroups: [CardPaymentGroup] {
        let groups = creditCardObligations.map { obligation in
            CardPaymentGroup(
                obligation: obligation,
                postedPayments: postedCardPayments(for: obligation)
            )
        }

        let groupedPostedIDs = Set(groups.flatMap { group in
            group.postedPayments.map(\.id)
        })
        let unmatchedPostedPayments = postedTransactions
            .filter { !groupedPostedIDs.contains($0.id) }
            .map { PostedCardPayment(transaction: $0) }

        let knownGroups = groups.sorted { lhs, rhs in
            lhs.cardName < rhs.cardName
        }

        guard !unmatchedPostedPayments.isEmpty else {
            return knownGroups
        }

        return knownGroups + [
            CardPaymentGroup(
                cardName: "Other Card Payments",
                institutionName: nil,
                postedPayments: unmatchedPostedPayments.sorted { $0.date > $1.date },
                expectedPayment: nil
            )
        ]
    }

    private var hasUpcomingItems: Bool {
        !upcomingRecurringStreams.isEmpty || !upcomingProjectedEvents.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                summaryCard

                if bucket == .transfers {
                    cardPaymentsByCardSection
                } else {
                    if !postedTransactions.isEmpty {
                        postedSection
                    }

                    if bucket.supportsUpcomingRecurring, hasUpcomingItems {
                        upcomingSection
                    }
                }

                if postedTransactions.isEmpty
                    && !hasUpcomingItems
                    && (bucket != .transfers || cardPaymentGroups.isEmpty) {
                    emptyState
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(isHistoricalMode ? "\(bucket.title) · \(selectedMonth.shortLabel)" : bucket.title)
    }

    private func postedCardPayments(for obligation: CreditCardObligation) -> [PostedCardPayment] {
        let lastPayment = PostedCardPayment(obligation: obligation)
        let cardName = obligation.accountName.normalizedCardPaymentText
        let matchedTransactions = postedTransactions
            .filter { transaction in
                let transactionTitle = transaction.displayTitle.normalizedCardPaymentText
                return transaction.accountID == obligation.accountID
                    || (!cardName.isEmpty && !transactionTitle.isEmpty && transactionTitle.contains(cardName))
                    || (!cardName.isEmpty && !transactionTitle.isEmpty && cardName.contains(transactionTitle))
            }
            .map { PostedCardPayment(transaction: $0) }

        var paymentsByID: [String: PostedCardPayment] = [:]
        for payment in matchedTransactions {
            paymentsByID[payment.id] = payment
        }

        if let lastPayment {
            paymentsByID[lastPayment.id] = lastPayment
        }

        return paymentsByID.values.sorted { $0.date > $1.date }
    }

    private var summaryTotalTitle: String {
        switch bucket {
        case .income:
            return "Total Income"
        case .housing:
            return "Total Housing"
        case .expenses:
            return "Total Expenses"
        case .subscriptions:
            return "Total Subscriptions"
        case .transfers:
            return "Total Card Payments"
        }
    }

    private var postedValueColor: Color {
        bucket == .income ? .green : .red
    }

    private var summaryPostedAmount: Double {
        CashFlowAmount.signed(breakdown.posted, bucket: bucket)
    }

    private var summaryExpectedAmount: Double {
        CashFlowAmount.signed(breakdown.upcoming, bucket: bucket)
    }

    private var summaryCard: some View {
        HStack(spacing: 8) {
            VStack {
                Spacer(minLength: 0)

                VStack(spacing: 4) {
                    Text(summaryTotalTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Text(CurrencyFormatter.dollars(CashFlowAmount.signed(breakdown.total, bucket: bucket)))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(spacing: 8) {
                summaryMiniCard(
                    label: "Posted",
                    amount: summaryPostedAmount,
                    color: postedValueColor
                )

                summaryMiniCard(
                    label: "Expected",
                    amount: summaryExpectedAmount,
                    color: .yellow
                )
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func summaryMiniCard(label: String, amount: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(CurrencyFormatter.dollars(amount))
                .font(.title3.bold())
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var postedSection: some View {
        bucketAmountSection(
            title: "Posted",
            amount: summaryPostedAmount,
            color: postedValueColor
        ) {
            ForEach(postedTransactions) { transaction in
                TransactionRow(transaction: transaction, bucket: bucket)
            }
        }
    }

    private var cardPaymentsByCardSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(cardPaymentGroups) { group in
                CardPaymentGroupSection(group: group)
            }
        }
    }

    private var upcomingSection: some View {
        bucketAmountSection(
            title: "Expected",
            amount: summaryExpectedAmount,
            color: .yellow
        ) {
            ForEach(upcomingRecurringStreams) { stream in
                RecurringStreamRow(stream: stream, bucket: bucket)
            }

            ForEach(upcomingProjectedEvents) { event in
                UpcomingCashFlowEventRow(event: event, bucket: bucket)
            }
        }
    }

    private func bucketAmountSection<Content: View>(
        title: String,
        amount: Double,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(color)

                Spacer()

                Text(CurrencyFormatter.dollars(amount))
                    .font(.caption.bold())
                    .foregroundStyle(color)
            }

            content()
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: bucket.icon)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text(emptyStateCopy)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyStateCopy: String {
        switch bucket {
        case .expenses:
            return "No posted expenses yet this month."
        case .transfers:
            return "No card payments posted or expected this month."
        default:
            return "No \(bucket.title.lowercased()) activity this month yet."
        }
    }
}

private struct CardPaymentGroup: Identifiable {
    let id: String
    let cardName: String
    let institutionName: String?
    let postedPayments: [PostedCardPayment]
    let expectedPayment: CreditCardObligation?

    init(obligation: CreditCardObligation, postedPayments: [PostedCardPayment]) {
        self.id = obligation.accountID
        self.cardName = obligation.accountName
        self.institutionName = obligation.institutionName
        self.postedPayments = postedPayments
        self.expectedPayment = obligation.isAlreadyPaidThisCycle ? nil : obligation
    }

    init(
        cardName: String,
        institutionName: String?,
        postedPayments: [PostedCardPayment],
        expectedPayment: CreditCardObligation?
    ) {
        self.id = cardName
        self.cardName = cardName
        self.institutionName = institutionName
        self.postedPayments = postedPayments
        self.expectedPayment = expectedPayment
    }

    var postedTotal: Double {
        postedPayments.map(\.amount).reduce(0, +)
    }

    var expectedTotal: Double {
        expectedPayment?.projectedPaymentAmount ?? 0
    }

    var cardTotal: Double {
        postedTotal + expectedTotal
    }
}

private struct PostedCardPayment: Identifiable {
    let id: String
    let title: String
    let amount: Double
    let date: String

    init(transaction: NormalizedTransaction) {
        self.id = transaction.id
        self.title = transaction.displayTitle
        self.amount = abs(transaction.amount)
        self.date = transaction.date
    }

    init?(obligation: CreditCardObligation) {
        guard obligation.isAlreadyPaidThisCycle,
              let lastPaymentDate = obligation.lastPaymentDate,
              CashFlowDate.isCurrentMonth(lastPaymentDate),
              let lastPaymentAmount = obligation.lastPaymentAmount,
              lastPaymentAmount > 0 else {
            return nil
        }

        self.id = "\(obligation.accountID)-last-payment-\(lastPaymentDate)"
        self.title = "Last card payment"
        self.amount = lastPaymentAmount
        self.date = lastPaymentDate
    }
}

private struct CardPaymentGroupSection: View {
    let group: CardPaymentGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(group.cardName)
                        .font(.headline)
                        .foregroundStyle(.white)

                    if let institutionName = group.institutionName {
                        Text(institutionName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(CurrencyFormatter.dollars(-abs(group.cardTotal)))
                    .font(.headline)
                    .foregroundStyle(.white)
            }

            if !group.postedPayments.isEmpty {
                VStack(spacing: 8) {
                    paymentStatusHeader(
                        title: "Posted",
                        amount: -abs(group.postedTotal),
                        color: .red
                    )

                    ForEach(group.postedPayments) { payment in
                        PostedCardPaymentRow(payment: payment)
                    }
                }
            }

            if let expectedPayment = group.expectedPayment {
                VStack(spacing: 8) {
                    paymentStatusHeader(
                        title: "Expected",
                        amount: -abs(group.expectedTotal),
                        color: .yellow
                    )

                    ExpectedCardPaymentRow(obligation: expectedPayment)
                }
            }

            if group.postedPayments.isEmpty && group.expectedPayment == nil {
                Text("No card payments found for this month.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func paymentStatusHeader(title: String, amount: Double, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(color)

            Spacer()

            Text(CurrencyFormatter.dollars(amount))
                .font(.caption.bold())
                .foregroundStyle(color)
        }
    }
}

private struct PostedCardPaymentRow: View {
    let payment: PostedCardPayment

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(payment.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(CashFlowDate.formatted(payment.date) ?? payment.date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(CurrencyFormatter.dollars(-abs(payment.amount)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ExpectedCardPaymentRow: View {
    let obligation: CreditCardObligation

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Statement payment")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                if let dueDate = CashFlowDate.formatted(obligation.nextPaymentDueDate) {
                    Text("Due \(dueDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(CurrencyFormatter.dollars(-abs(obligation.projectedPaymentAmount)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.yellow)
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private extension String {
    var normalizedCardPaymentText: String {
        lowercased()
            .replacingOccurrences(of: "(", with: " ")
            .replacingOccurrences(of: ")", with: " ")
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
    }
}

private struct TransactionRow: View {
    let transaction: NormalizedTransaction
    let bucket: CashFlowBucket

    private var amountColor: Color {
        bucket == .income ? .green : .red
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(CashFlowDate.formatted(transaction.date) ?? transaction.date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(CashFlowAmount.format(transaction.amount, bucket: bucket))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(amountColor)
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct UpcomingCashFlowEventRow: View {
    let event: CashFlowEvent
    let bucket: CashFlowBucket

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let nextDate = CashFlowDate.formatted(event.date) {
                    Text("Due \(nextDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(CashFlowAmount.format(event.amount, bucket: bucket))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.yellow)
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private extension CashFlowEvent {
    var sourceLabel: String {
        switch source {
        case "posted":
            return "Posted"
        case "liability":
            return "Card payment"
        case "projection":
            return "Projected"
        case "recurring":
            return "Recurring"
        default:
            return source.capitalized
        }
    }
}

private struct RecurringStreamRow: View {
    let stream: RecurringStream
    let bucket: CashFlowBucket

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(stream.displayName())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if let nextDate = CashFlowDate.formatted(stream.predictedNextDate) {
                    Text("Due \(nextDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(CashFlowAmount.format(stream.lastAmount ?? stream.averageAmount ?? 0, bucket: bucket))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.yellow)
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        CashFlowView(
            bucket: .expenses,
            breakdown: MonthlyBucketBreakdown(posted: 0, upcoming: 0, bucket: .expenses),
            transactions: [],
            recurringStreams: [],
            creditCardObligations: [],
            cashFlowEvents: []
        )
    }
    .preferredColorScheme(.dark)
}
