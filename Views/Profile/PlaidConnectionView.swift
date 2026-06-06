import SwiftUI

struct PlaidConnectionView: View {
    var isBankLinked: Bool = false
    var onBankLinked: (() -> Void)? = nil

    @StateObject private var viewModel = PlaidConnectionViewModel()
    @State private var showsDeveloperTools = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    connectionHero

                    if let errorMessage = viewModel.errorMessage {
                        ErrorBanner(message: errorMessage)
                    }

                    Button {
                        connectBank()
                    } label: {
                        PrimaryButtonLabel(title: primaryButtonTitle)
                    }
                    .disabled(viewModel.isLoading)

                    VStack(spacing: 10) {
                        ConnectionBenefitRow(icon: "lock.shield.fill", title: "Secure Plaid connection")
                        ConnectionBenefitRow(icon: "chart.line.uptrend.xyaxis", title: "Live balances and transactions")
                        ConnectionBenefitRow(icon: "sparkles", title: "Smarter safe-to-move insights")
                    }

                    developerTools
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 24)
            }
            .background(connectionBackground)
            .navigationTitle("Bank")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                guard isConnected else {
                    return
                }

                await viewModel.refreshConnectedAccounts()
            }
            .onChange(of: viewModel.didLinkBank) { _, didLinkBank in
                guard didLinkBank else {
                    return
                }

                onBankLinked?()
            }
        }
    }

    private var connectionBackground: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color.green.opacity(0.10),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var connectionHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: isConnected ? "checkmark.shield.fill" : "building.columns.fill")
                    .font(.title3)
                    .foregroundStyle(isConnected ? .black : .green)
                    .frame(width: 48, height: 48)
                    .background(isConnected ? Color.green : Color.green.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(isConnected ? "Banks Connected" : "Connect Your Bank")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(isConnected ? connectedSubtitle : "Link your accounts to calculate what is safe to move each month.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            statusPill

            if isConnected && (!viewModel.institutions.isEmpty || !viewModel.accounts.isEmpty) {
                ConnectedAccountSummary(
                    institutions: viewModel.institutions,
                    accounts: viewModel.accounts
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.11),
                    Color.white.opacity(0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    private var connectedSubtitle: String {
        if !viewModel.institutions.isEmpty {
            let bankCount = viewModel.institutions.count
            let accountCount = viewModel.accounts.count
            return "\(bankCount) bank\(bankCount == 1 ? "" : "s") · \(accountCount) account\(accountCount == 1 ? "" : "s") linked"
        }

        if viewModel.accounts.isEmpty {
            return "Account details will appear here."
        }

        return "\(viewModel.accounts.count) account\(viewModel.accounts.count == 1 ? "" : "s") available to Spendant."
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            if viewModel.isLoading {
                ProgressView()
                    .tint(.green)
                    .scaleEffect(0.75)
            } else {
                Circle()
                    .fill(isConnected ? Color.green : Color.white.opacity(0.22))
                    .frame(width: 8, height: 8)
            }

            Text(viewModel.isLoading ? "Opening Plaid..." : viewModel.statusMessage)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.66))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.07))
        .clipShape(Capsule())
    }

    private var primaryButtonTitle: String {
        if isConnected {
            return "Connect Another Bank"
        }

        return "Connect with Plaid"
    }

    private var isConnected: Bool {
        isBankLinked || viewModel.didLinkBank || !viewModel.institutions.isEmpty
    }

    private var developerTools: some View {
        DisclosureGroup(isExpanded: $showsDeveloperTools) {
            VStack(spacing: 12) {
                Button {
                    Task {
                        await viewModel.fetchAccounts()
                    }
                } label: {
                    SecondaryButtonLabel(title: "Fetch Accounts")
                }

                Button {
                    Task {
                        await viewModel.fetchBalances()
                    }
                } label: {
                    SecondaryButtonLabel(title: "Fetch Balances")
                }

                Button {
                    Task {
                        await viewModel.fetchTransactions()
                    }
                } label: {
                    SecondaryButtonLabel(title: "Fetch Transactions")
                }

                DebugJSONCard(title: "Accounts", json: viewModel.accountsJSON)
                DebugJSONCard(title: "Balances", json: viewModel.balancesJSON)
                DebugJSONCard(title: "Transactions", json: viewModel.transactionsJSON)
            }
            .padding(.top, 12)
        } label: {
            Text("Developer tools")
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.62))
        }
        .tint(.white.opacity(0.62))
        .padding()
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func connectBank() {
        Task {
            await viewModel.prepareLinkSession()

            if viewModel.linkConfiguration != nil {
                viewModel.openPlaidLink()
            }
        }
    }
}

struct PrimaryButtonLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.green)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct SecondaryButtonLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.075))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct ConnectionBenefitRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.bold())
                .foregroundStyle(.green)
                .frame(width: 34, height: 34)
                .background(Color.green.opacity(0.14))
                .clipShape(Circle())

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))

            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct DebugJSONCard: View {
    let title: String
    let json: String

    var body: some View {
        if !json.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                ScrollView(.horizontal) {
                    Text(json)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

#Preview {
    PlaidConnectionView()
        .preferredColorScheme(ColorScheme.dark)
}
