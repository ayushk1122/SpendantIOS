import SwiftUI
import LinkKit

struct PlaidConnectionView: View {
    @StateObject private var viewModel = PlaidConnectionViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard

                    Button {
                        Task {
                            if viewModel.linkConfiguration == nil {
                                await viewModel.createLinkToken()
                            } else {
                                viewModel.openPlaidLink()
                            }
                        }
                    } label: {
                        PrimaryButtonLabel(
                            title: viewModel.linkConfiguration == nil
                                ? "Create Link Token"
                                : "Connect Bank"
                        )
                    }

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

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    DebugJSONCard(title: "Accounts", json: viewModel.accountsJSON)
                    DebugJSONCard(title: "Balances", json: viewModel.balancesJSON)
                    DebugJSONCard(title: "Transactions", json: viewModel.transactionsJSON)
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Bank Connection")
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Backend Status")
                .font(.headline)
                .foregroundStyle(.white)

            Text(viewModel.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 4)
            }

            if let linkToken = viewModel.linkToken {
                Text("Link token created")
                    .font(.caption.bold())
                    .foregroundStyle(.green)

                Text(linkToken)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct PrimaryButtonLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(.green)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct SecondaryButtonLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white.opacity(0.08))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        .preferredColorScheme(.dark)
}
