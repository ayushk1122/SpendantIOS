import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserSettings.createdAt) private var settings: [UserSettings]

    @State private var showsClearDataConfirmation = false
    @State private var isClearingData = false
    @State private var statusMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if let userSettings = settings.first {
                    protectedBalanceSection(userSettings)
                    allocationSection(userSettings)
                    connectionSection(userSettings)
                    setupSection(userSettings)
                    developerSection(userSettings)
                } else {
                    ProgressView()
                        .padding()
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Settings")
        .task {
            ensureSettingsExist()
        }
        .alert("Clear connected banks?", isPresented: $showsClearDataConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear Data", role: .destructive) {
                guard let userSettings = settings.first else {
                    return
                }

                Task {
                    await clearBankData(for: userSettings)
                }
            }
        } message: {
            Text("This removes all linked banks from the backend and resets onboarding so you can test a fresh connection flow.")
        }
    }

    private func protectedBalanceSection(_ userSettings: UserSettings) -> some View {
        SettingsCard(title: "Protected Balance", icon: "shield.fill") {
            Text(CurrencyFormatter.dollars(userSettings.minimumCheckingBuffer))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.green)

            Text("Spendant subtracts this buffer before showing money that is safe to move.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Slider(
                value: Binding(
                    get: { userSettings.minimumCheckingBuffer },
                    set: { newValue in
                        userSettings.minimumCheckingBuffer = newValue
                        saveSettings()
                    }
                ),
                in: 0...5000,
                step: 25
            )
            .tint(.green)
        }
    }

    private func allocationSection(_ userSettings: UserSettings) -> some View {
        SettingsCard(title: "Default Allocation", icon: "chart.pie.fill") {
            AllocationSummaryRow(title: "Savings", percent: userSettings.savingsAllocationPercent)
            AllocationSummaryRow(title: "Investments", percent: userSettings.investmentAllocationPercent)
            AllocationSummaryRow(title: "Retirement", percent: userSettings.retirementAllocationPercent)
            AllocationSummaryRow(title: "Extra Buffer", percent: userSettings.bufferAllocationPercent)

            VStack(spacing: 10) {
                SettingsActionButton(title: "Balanced") {
                    userSettings.applyBalancedAllocation()
                    saveSettings()
                }

                SettingsActionButton(title: "Conservative") {
                    userSettings.applyConservativeAllocation()
                    saveSettings()
                }

                SettingsActionButton(title: "Growth") {
                    userSettings.applyGrowthAllocation()
                    saveSettings()
                }
            }
            .padding(.top, 6)
        }
    }

    private func connectionSection(_ userSettings: UserSettings) -> some View {
        SettingsCard(title: "Bank Connection", icon: "link") {
            HStack {
                Text(userSettings.hasLinkedPlaid ? "Bank linked" : "Not connected")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: userSettings.hasLinkedPlaid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(userSettings.hasLinkedPlaid ? .green : .yellow)
            }

            Text("Use Account Connections in Profile to connect or test Plaid data.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func setupSection(_ userSettings: UserSettings) -> some View {
        SettingsCard(title: "Setup", icon: "arrow.triangle.2.circlepath") {
            SettingsActionButton(title: "Run Onboarding Again") {
                userSettings.hasCompletedOnboarding = false
                saveSettings()
            }
        }
    }

    private func developerSection(_ userSettings: UserSettings) -> some View {
        SettingsCard(title: "Developer", icon: "hammer.fill") {
            Text("Clear linked banks and cached Plaid data, then restart onboarding from scratch.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SettingsActionButton(
                title: isClearingData ? "Clearing..." : "Clear Bank Data & Reset Onboarding",
                isDestructive: true
            ) {
                showsClearDataConfirmation = true
            }
            .disabled(isClearingData)

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(statusMessage.contains("failed") ? .red : .green)
            }
        }
    }

    @MainActor
    private func clearBankData(for userSettings: UserSettings) async {
        isClearingData = true
        statusMessage = nil

        do {
            try await PlaidAPIService.shared.clearAllLinkedItems()
            userSettings.hasLinkedPlaid = false
            userSettings.hasCompletedOnboarding = false
            saveSettings()
            statusMessage = "Bank data cleared. Onboarding will start fresh on next launch."
        } catch {
            statusMessage = "Clear failed: \(error.localizedDescription)"
        }

        isClearingData = false
    }

    private func ensureSettingsExist() {
        guard settings.isEmpty else {
            return
        }

        modelContext.insert(UserSettings())
        saveSettings()
    }

    private func saveSettings() {
        try? modelContext.save()
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.white)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct AllocationSummaryRow: View {
    let title: String
    let percent: Double

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(Int((percent * 100).rounded()))%")
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .font(.subheadline)
    }
}

private struct SettingsActionButton: View {
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isDestructive ? Color.red.opacity(0.18) : Color.white.opacity(0.08))
                .foregroundStyle(isDestructive ? .red : .white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .modelContainer(for: UserSettings.self, inMemory: true)
            .preferredColorScheme(.dark)
    }
}
