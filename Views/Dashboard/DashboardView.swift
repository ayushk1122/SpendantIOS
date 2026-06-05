import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroCard
                    summaryRow
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
                await viewModel.loadDashboardSummary()
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Safe to Move This Month")
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

            Text("Maximum amount you can move from checking while keeping your protected balance intact.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .background(heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var summaryRow: some View {
        HStack(spacing: 14) {
            MiniSummaryCard(
                title: "Month-End",
                amount: viewModel.result.projectedEndOfMonthBalance,
                icon: "calendar"
            )

            MiniSummaryCard(
                title: "Protected",
                amount: viewModel.minimumBuffer,
                icon: "shield.fill"
            )
        }
    }

    private var breakdownSection: some View {
        VStack(spacing: 14) {
            NavigationLink {
                CashFlowView()
            } label: {
                BreakdownCard(
                    title: "Income",
                    amount: viewModel.incomeTotal,
                    icon: "arrow.down.circle.fill",
                    accentColor: .green,
                    amountPrefix: "+"
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                CashFlowView()
            } label: {
                BreakdownCard(
                    title: "Housing",
                    amount: viewModel.housingTotal,
                    icon: "house.fill",
                    accentColor: .red,
                    amountPrefix: "-"
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                CashFlowView()
            } label: {
                BreakdownCard(
                    title: "Expenses",
                    amount: viewModel.expenseTotal,
                    icon: "creditcard.fill",
                    accentColor: .red,
                    amountPrefix: "-"
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                CashFlowView()
            } label: {
                BreakdownCard(
                    title: "Subscriptions",
                    amount: viewModel.subscriptionsTotal,
                    icon: "repeat.circle.fill",
                    accentColor: .red,
                    amountPrefix: "-"
                )
            }
            .buttonStyle(.plain)
        }
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

                Text("Customize")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
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

struct MiniSummaryCard: View {
    let title: String
    let amount: Double
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.green)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(CurrencyFormatter.dollars(amount))
                .font(.title3.bold())
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct BreakdownCard: View {
    let title: String
    let amount: Double
    let icon: String
    let accentColor: Color
    let amountPrefix: String

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

            Text("\(amountPrefix)\(CurrencyFormatter.dollars(amount))")
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
