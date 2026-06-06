import SwiftUI

struct CashFlowView: View {
    let bucket: CashFlowBucket
    let breakdown: MonthlyBucketBreakdown
    let transactions: [NormalizedTransaction]
    let recurringStreams: [RecurringStream]
    var creditCardObligations: [CreditCardObligation] = []
    var cashFlowEvents: [CashFlowEvent] = []

    private var currentMonthTransactionIDs: Set<String> {
        Set(transactions.map(\.transactionID))
    }

    private var postedTransactions: [NormalizedTransaction] {
        bucket.transactions(from: transactions)
    }

    private var upcomingRecurringStreams: [RecurringStream] {
        bucket.recurringStreams(
            from: recurringStreams,
            currentMonthTransactionIDs: currentMonthTransactionIDs
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
        guard bucket.supportsUpcomingRecurring, bucket != .transfers else {
            return []
        }

        let today = Calendar.current.startOfDay(for: Date())

        return cashFlowEvents
            .filter { event in
                guard event.bucket == bucket.rawValue else {
                    return false
                }

                guard CashFlowDate.isCurrentMonth(event.date) else {
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

    private var upcomingCreditCardObligations: [CreditCardObligation] {
        creditCardObligations.filter { !$0.isAlreadyPaidThisCycle }
    }

    private var hasUpcomingItems: Bool {
        !upcomingRecurringStreams.isEmpty || !upcomingProjectedEvents.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                summaryCard

                if !postedTransactions.isEmpty {
                    postedSection
                }

                if bucket.supportsUpcomingRecurring, hasUpcomingItems {
                    upcomingSection
                }

                if bucket == .transfers, !upcomingCreditCardObligations.isEmpty {
                    creditCardSection
                }

                if postedTransactions.isEmpty
                    && !hasUpcomingItems
                    && (bucket != .transfers || upcomingCreditCardObligations.isEmpty) {
                    emptyState
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(bucket.title)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: bucket.icon)
                    .font(.title3)
                    .foregroundStyle(accentColor)
                    .frame(width: 40, height: 40)
                    .background(accentColor.opacity(0.14))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("This Month")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(CurrencyFormatter.dollars(CashFlowAmount.signed(breakdown.total, bucket: bucket)))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()
            }

            if breakdown.posted > 0 || breakdown.upcoming > 0 {
                VStack(spacing: 8) {
                    if breakdown.posted > 0 {
                        summaryBreakdownRow(
                            label: "Posted",
                            amount: CashFlowAmount.signed(breakdown.posted, bucket: bucket)
                        )
                    }

                    if breakdown.upcoming > 0 {
                        summaryBreakdownRow(
                            label: "Still expected this month",
                            amount: CashFlowAmount.signed(breakdown.upcoming, bucket: bucket)
                        )
                    }
                }
            }

            Text(summaryCopy)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var postedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Posted",
                subtitle: "\(postedTransactions.count) · \(CurrencyFormatter.dollars(CashFlowAmount.signed(breakdown.posted, bucket: bucket)))"
            )

            ForEach(postedTransactions) { transaction in
                TransactionRow(transaction: transaction, bucket: bucket)
            }
        }
    }

    private var creditCardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Statement Payments",
                subtitle: "\(upcomingCreditCardObligations.count) upcoming"
            )

            ForEach(upcomingCreditCardObligations) { obligation in
                CreditCardObligationDetailRow(obligation: obligation)
            }
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Still Expected This Month",
                subtitle: "\(upcomingRecurringStreams.count + upcomingProjectedEvents.count) · \(CurrencyFormatter.dollars(CashFlowAmount.signed(breakdown.upcoming, bucket: bucket)))"
            )

            ForEach(upcomingRecurringStreams) { stream in
                RecurringStreamRow(stream: stream, bucket: bucket)
            }

            ForEach(upcomingProjectedEvents) { event in
                UpcomingCashFlowEventRow(event: event, bucket: bucket)
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func summaryBreakdownRow(label: String, amount: Double) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(CurrencyFormatter.dollars(amount))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
        }
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

    private var accentColor: Color {
        bucket == .income ? .green : .red
    }

    private var summaryCopy: String {
        switch bucket {
        case .income:
            return "Posted deposits plus any income still expected before month end."
        case .housing:
            return "Posted housing costs plus rent or utilities still expected this month."
        case .expenses:
            return "Only posted spending counts here. Variable expenses are not projected forward."
        case .subscriptions:
            return "Posted subscription charges plus recurring bills still expected this month."
        case .transfers:
            return "Posted payments plus statement due dates and projected payoff amounts from your linked cards."
        }
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

private struct TransactionRow: View {
    let transaction: NormalizedTransaction
    let bucket: CashFlowBucket

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.displayTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(transaction.categorySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(CashFlowAmount.format(transaction.amount, bucket: bucket))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(bucket == .income ? .green : .white)
            }

            HStack {
                Text(CashFlowDate.formatted(transaction.date) ?? transaction.date)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                statusBadge(transaction.pending ? "Pending" : "Posted", color: transaction.pending ? .yellow : .green)

                Spacer()
            }
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func statusBadge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }
}

private struct CreditCardObligationDetailRow: View {
    let obligation: CreditCardObligation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(obligation.accountName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    if let institution = obligation.institutionName {
                        Text(institution)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(CurrencyFormatter.dollars(-obligation.projectedPaymentAmount))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            HStack {
                if let dueDate = CashFlowDate.formatted(obligation.nextPaymentDueDate) {
                    Text("Due \(dueDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let statementBalance = obligation.lastStatementBalance {
                    Text("Statement \(CurrencyFormatter.dollars(statementBalance))")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.14))
                        .clipShape(Capsule())
                }

                Spacer()

                statusBadge("Upcoming", color: .orange)
            }
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func statusBadge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }
}

private struct UpcomingCashFlowEventRow: View {
    let event: CashFlowEvent
    let bucket: CashFlowBucket

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(event.sourceLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(CashFlowAmount.format(event.amount, bucket: bucket))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(bucket == .income ? .green : .white)
            }

            HStack {
                if let nextDate = CashFlowDate.formatted(event.date) {
                    Text("Expected \(nextDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                statusBadge("Upcoming", color: .orange)
            }
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func statusBadge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stream.displayName())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(stream.categorySubtitle())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(CashFlowAmount.format(stream.lastAmount ?? stream.averageAmount ?? 0, bucket: bucket))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            HStack {
                if let nextDate = CashFlowDate.formatted(stream.predictedNextDate) {
                    Text("Expected \(nextDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let frequency = stream.frequency?
                    .replacingOccurrences(of: "_", with: " ")
                    .lowercased(),
                   !frequency.isEmpty {
                    Text(frequency)
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.14))
                        .clipShape(Capsule())
                }

                Spacer()

                statusBadge("Upcoming", color: .orange)
            }
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func statusBadge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
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
