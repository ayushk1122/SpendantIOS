import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserSettings.createdAt) private var settings: [UserSettings]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    profileHeader

                    VStack(spacing: 12) {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            ProfileRow(title: "Settings", subtitle: "Manage app preferences", icon: "gearshape.fill")
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            SettingsView()
                        } label: {
                            ProfileRow(
                                title: "Protected Balance",
                                subtitle: protectedBalanceSubtitle,
                                icon: "shield.fill"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            SettingsView()
                        } label: {
                            ProfileRow(
                                title: "Default Allocation",
                                subtitle: allocationSubtitle,
                                icon: "slider.horizontal.3"
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            PlaidConnectionView(
                                isBankLinked: userSettings?.hasLinkedPlaid == true,
                                onBankLinked: markBankLinked
                            )
                        } label: {
                            ProfileRow(
                                title: "Account Connections",
                                subtitle: bankConnectionSubtitle,
                                icon: "link"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Profile")
        }
    }

    private var userSettings: UserSettings? {
        settings.first
    }

    private var protectedBalanceSubtitle: String {
        guard let userSettings else {
            return "Set your minimum checking buffer"
        }

        return "\(CurrencyFormatter.dollars(userSettings.minimumCheckingBuffer)) minimum checking buffer"
    }

    private var allocationSubtitle: String {
        guard let userSettings else {
            return "Customize savings, investing, and buffer splits"
        }

        return "\(percent(userSettings.savingsAllocationPercent)) savings, \(percent(userSettings.investmentAllocationPercent)) investing"
    }

    private var bankConnectionSubtitle: String {
        userSettings?.hasLinkedPlaid == true
            ? "Bank linked through Plaid"
            : "Connect and test bank data"
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Ayush")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("Your monthly money command center.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func markBankLinked() {
        let userSettings = settings.first ?? UserSettings()
        if settings.isEmpty {
            modelContext.insert(userSettings)
        }

        userSettings.hasLinkedPlaid = true
        try? modelContext.save()
    }
}

struct ProfileRow: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 36, height: 36)
                .background(Color.green.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: UserSettings.self, inMemory: true)
        .preferredColorScheme(.dark)
}
