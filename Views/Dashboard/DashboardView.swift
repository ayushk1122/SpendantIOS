import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \UserSettings.createdAt) private var settings: [UserSettings]
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroCard
                    projectionChartSection
                    breakdownSection
                    destinationsCard

                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.loadDashboardSummary(settings: settings.first)
            }
            .onChange(of: settings.first?.minimumCheckingBuffer) { _, _ in
                Task {
                    await viewModel.loadDashboardSummary(settings: settings.first)
                }
            }
            .onChange(of: settings.first?.savingsAllocationPercent) { _, _ in
                Task {
                    await viewModel.loadDashboardSummary(settings: settings.first)
                }
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Safe to Move Today")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.72))

                Spacer()

                Text(statusLabel)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.14))
                    .clipShape(Capsule())
            }

            Text(CurrencyFormatter.dollars(viewModel.result.safeToMoveAmount))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Amount you can safely move while maintaining your account balance buffer.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .background(heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var projectionChartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if viewModel.projectedSafePoints.isEmpty {
                Text("Projection will appear once cash-flow data is available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                projectionChart
                    .frame(height: 285)
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var projectionChart: some View {
        ProjectedSafeLineGraph(
            points: viewModel.projectedSafePoints,
            today: Date(),
            protectedBalance: viewModel.minimumBuffer
        )
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date)
    }

    private var breakdownSection: some View {
        VStack(spacing: 14) {
            breakdownLink(
                bucket: .income,
                amount: viewModel.incomeTotal
            )

            breakdownLink(
                bucket: .housing,
                amount: viewModel.housingTotal
            )

            breakdownLink(
                bucket: .expenses,
                amount: viewModel.expenseTotal
            )

            breakdownLink(
                bucket: .subscriptions,
                amount: viewModel.subscriptionsTotal
            )

            breakdownLink(
                bucket: .transfers,
                amount: viewModel.transferTotal
            )
        }
    }

    private func breakdownLink(bucket: CashFlowBucket, amount: Double) -> some View {
        NavigationLink {
            CashFlowView(
                bucket: bucket,
                breakdown: viewModel.breakdown(for: bucket),
                transactions: viewModel.transactions,
                recurringStreams: viewModel.recurringStreams,
                creditCardObligations: viewModel.creditCardObligations,
                cashFlowEvents: viewModel.cashFlowEvents
            )
        } label: {
            BreakdownCard(
                title: bucket.title,
                amount: CashFlowAmount.signed(amount, bucket: bucket),
                icon: bucket.icon,
                accentColor: bucket == .income ? .green : .red
            )
        }
        .buttonStyle(.plain)
    }

    private var destinationsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Money Destinations")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Suggested split for your safe-to-move amount.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                NavigationLink {
                    SettingsView()
                } label: {
                    Text("Customize")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }

            ForEach(viewModel.destinations) { destination in
                DestinationRow(
                    destination: destination,
                    safeToMoveAmount: viewModel.result.safeToMoveAmount
                )
            }
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var heroGradient: LinearGradient {
        switch viewModel.statusColor {
        case .healthy:
            return LinearGradient(
                colors: [Color.green.opacity(0.55), Color.green.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .tight:
            return LinearGradient(
                colors: [Color.yellow.opacity(0.48), Color.orange.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .risk:
            return LinearGradient(
                colors: [Color.red.opacity(0.58), Color.orange.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var statusLabel: String {
        switch viewModel.statusColor {
        case .healthy:
            return "Healthy"
        case .tight:
            return "Tight"
        case .risk:
            return "Risk"
        }
    }
}

struct ProjectedSafeLineGraph: View {
    let points: [ProjectedSafePoint]
    let today: Date
    let protectedBalance: Double

    @State private var selectedIndex: Int?

    private var maxSafeToMove: Double {
        max(points.map(\.safeToMove).max() ?? 1, 1)
    }

    private var firstDate: Date? {
        points.first?.date
    }

    private var lastDate: Date? {
        points.last?.date
    }

    private var selectedPoint: ProjectedSafePoint? {
        guard let selectedIndex else {
            return points.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) })
                ?? points.first
        }

        return points[safe: selectedIndex]
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let size = proxy.size
                let chartPoints = mappedPoints(in: size)
                let activeIndex = selectedIndex ?? todayIndex
                let activePosition = activeIndex.flatMap { chartPoints[safe: $0] }
                let todayPosition = todayIndex.flatMap { chartPoints[safe: $0] }

                ZStack(alignment: .topLeading) {
                    gridLines(in: size)

                    Path { path in
                        guard let first = chartPoints.first, let last = chartPoints.last else {
                            return
                        }

                        path.move(to: CGPoint(x: first.x, y: size.height))
                        path.addLine(to: first)
                        for point in chartPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                        path.addLine(to: CGPoint(x: last.x, y: size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.22), Color.green.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    Path { path in
                        guard let first = chartPoints.first else {
                            return
                        }

                        path.move(to: first)
                        for point in chartPoints.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(
                        Color.green,
                        style: StrokeStyle(lineWidth: 1.75, lineCap: .butt, lineJoin: .miter)
                    )

                    if let todayPosition {
                        Path { path in
                            path.move(to: CGPoint(x: todayPosition.x, y: 0))
                            path.addLine(to: CGPoint(x: todayPosition.x, y: size.height))
                        }
                        .stroke(
                            Color.white.opacity(0.42),
                            style: StrokeStyle(lineWidth: 1, dash: [4])
                        )
                    }

                    if let activePosition {
                        Path { path in
                            path.move(to: CGPoint(x: activePosition.x, y: 0))
                            path.addLine(to: CGPoint(x: activePosition.x, y: size.height))
                        }
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)

                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                            .shadow(color: .green.opacity(0.7), radius: 3)
                            .position(activePosition)
                    }

                    ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                        if point.hasEvent, let position = chartPoints[safe: index] {
                            Circle()
                                .fill(point.isCashOutflow ? Color.red : Color.green)
                                .frame(width: 5, height: 5)
                                .position(position)
                        }
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            selectedIndex = nearestIndex(for: value.location.x, width: size.width)
                        }
                )
            }

            HStack {
                if let firstDate {
                    Text(shortDate(firstDate))
                }

                Spacer()

                if let lastDate {
                    Text(shortDate(lastDate))
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            if let selectedPoint {
                selectedPointCard(selectedPoint)
            }
        }
    }

    private var todayIndex: Int? {
        let calendar = Calendar.current
        return points.firstIndex { calendar.isDate($0.date, inSameDayAs: today) }
    }

    private func selectedPointCard(_ point: ProjectedSafePoint) -> some View {
        let visibleEvents = point.events.filter { event in
            !event.displayLabel.lowercased().contains("projected spending")
        }
        let primaryEvent = visibleEvents.first

        return VStack(spacing: 6) {
            Text(shortDate(point.date))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            GeometryReader { geometry in
                let spacing: CGFloat = 6
                let availableWidth = geometry.size.width - spacing
                let safeToMoveWidth = availableWidth * 0.30
                let transactionWidth = availableWidth * 0.70

                HStack(spacing: spacing) {
                    Text(CurrencyFormatter.dollars(point.safeToMove))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: safeToMoveWidth, height: geometry.size.height)
                        .background(safeToMoveGradient(for: point.safeToMove))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    transactionInfoCard(for: primaryEvent)
                        .frame(width: transactionWidth, height: geometry.size.height)
                }
            }
            .frame(height: 48)
        }
        .frame(height: 84)
    }

    private func transactionInfoCard(for event: ProjectedSafeEvent?) -> some View {
        HStack(spacing: 5) {
            if let event {
                Circle()
                    .fill(event.isCashOutflow ? Color.red : Color.green)
                    .frame(width: 4, height: 4)

                VStack(alignment: .leading, spacing: 0) {
                    Text(event.displayLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(event.sourceLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.72))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(CurrencyFormatter.dollars(event.amount))
                    .font(.caption2.bold())
                    .foregroundStyle(event.isCashOutflow ? .red : .green)
                    .lineLimit(1)
            } else {
                Text("No Cashflow Change")
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func safeToMoveGradient(for safeToMove: Double) -> LinearGradient {
        guard protectedBalance > 0 else {
            return LinearGradient(
                colors: [Color.green.opacity(0.55), Color.green.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        let ratio = safeToMove / protectedBalance

        if ratio >= 0.75 {
            return LinearGradient(
                colors: [Color.green.opacity(0.55), Color.green.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if ratio >= 0.35 {
            return LinearGradient(
                colors: [Color.yellow.opacity(0.48), Color.orange.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.red.opacity(0.58), Color.orange.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func gridLines(in size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<3, id: \.self) { index in
                let y = size.height * CGFloat(index) / 2

                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                .stroke(Color.white.opacity(index == 2 ? 0.24 : 0.08), style: StrokeStyle(lineWidth: 1, dash: index == 2 ? [5] : []))
            }
        }
    }

    private func mappedPoints(in size: CGSize) -> [CGPoint] {
        guard points.count > 1 else {
            let y = yPosition(for: points.first?.safeToMove ?? 0, height: size.height)
            return [CGPoint(x: size.width / 2, y: y)]
        }

        return points.enumerated().map { index, point in
            let x = size.width * CGFloat(index) / CGFloat(points.count - 1)
            let y = yPosition(for: point.safeToMove, height: size.height)
            return CGPoint(x: x, y: y)
        }
    }

    private func nearestIndex(for xPosition: CGFloat, width: CGFloat) -> Int? {
        guard points.count > 1, width > 0 else {
            return points.isEmpty ? nil : 0
        }

        let rawIndex = (xPosition / width) * CGFloat(points.count - 1)
        return min(max(Int(rawIndex.rounded()), 0), points.count - 1)
    }

    private func yPosition(for value: Double, height: CGFloat) -> CGFloat {
        let paddedMax = maxSafeToMove * 1.18
        let ratio = min(max(value / paddedMax, 0), 1)
        return height * (1 - CGFloat(ratio))
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else {
            return nil
        }

        return self[index]
    }
}

struct BreakdownCard: View {
    let title: String
    let amount: Double
    let icon: String
    let accentColor: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(accentColor)
                .frame(width: 34, height: 34)
                .background(accentColor.opacity(0.14))
                .clipShape(Circle())

            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            Text(CurrencyFormatter.dollars(amount))
                .font(.headline)
                .foregroundStyle(accentColor)

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct CreditCardObligationRow: View {
    let obligation: CreditCardObligation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "creditcard.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)
                .frame(width: 30, height: 30)
                .background(Color.orange.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(obligation.accountName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)

                if let dueDate = CashFlowDate.formatted(obligation.nextPaymentDueDate) {
                    Text("Due \(dueDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if obligation.isAlreadyPaidThisCycle {
                    Text("Paid this cycle")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(CurrencyFormatter.dollars(-obligation.projectedPaymentAmount))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)

                if let minimum = obligation.minimumPaymentAmount {
                    Text("Min \(CurrencyFormatter.dollars(minimum))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct CashFlowEventRow: View {
    let event: CashFlowEvent

    private var accentColor: Color {
        event.amount >= 0 ? .green : .red
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.amount >= 0 ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                .foregroundStyle(accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.label)
                    .font(.subheadline)
                    .foregroundStyle(.white)

                Text(CashFlowDate.formatted(event.date) ?? event.date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(CurrencyFormatter.dollars(event.amount))
                .font(.subheadline.bold())
                .foregroundStyle(accentColor)
        }
        .padding(.vertical, 4)
    }
}

struct DestinationRow: View {
    let destination: MoneyDestination
    let safeToMoveAmount: Double

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: destination.icon)
                .font(.subheadline)
                .foregroundStyle(.green)
                .frame(width: 30, height: 30)
                .background(Color.green.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(destination.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)

                Text(destination.percentText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(CurrencyFormatter.dollars(destination.amount(from: safeToMoveAmount)))
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DashboardView()
        .preferredColorScheme(.dark)
}
