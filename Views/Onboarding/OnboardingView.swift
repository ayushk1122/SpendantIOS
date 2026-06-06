import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserSettings.createdAt) private var settings: [UserSettings]
    @StateObject private var plaidViewModel = PlaidConnectionViewModel()
    @State private var step: OnboardingStep = .welcome

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    progressHeader

                    if let userSettings = settings.first {
                        content(for: userSettings)
                    } else {
                        ProgressView()
                            .padding()
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 28)
            }
            .background(appBackground)
            .task {
                ensureSettingsExist()
            }
            .onChange(of: plaidViewModel.didLinkBank) { _, didLinkBank in
                guard didLinkBank, let userSettings = settings.first else {
                    return
                }

                userSettings.hasLinkedPlaid = true
                saveSettings()
            }
            .onChange(of: step) { _, newStep in
                guard newStep == .connectBank, settings.first?.hasLinkedPlaid == true else {
                    return
                }

                Task {
                    await plaidViewModel.refreshConnectedAccounts()
                }
            }
        }
    }

    private var appBackground: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color.green.opacity(0.12),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 6) {
                ForEach(OnboardingStep.allCases, id: \.self) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? Color.green : Color.white.opacity(0.10))
                        .frame(height: 4)
                }
            }

            if step != .welcome {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .textCase(.uppercase)

                    Text(step.title)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(step.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func content(for userSettings: UserSettings) -> some View {
        switch step {
        case .welcome:
            welcomeStep
        case .connectBank:
            connectBankStep(userSettings)
        case .preferences:
            preferencesStep(userSettings)
        case .finish:
            finishStep(userSettings)
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 18) {
            OnboardingHeroCard(
                icon: "dollarsign.circle.fill",
                title: "$pendant",
                subtitle: "Your safe-to-move number, updated from your monthly cash flow."
            )

            VStack(spacing: 10) {
                OnboardingFeatureRow(icon: "shield.fill", title: "Protect your checking buffer")
                OnboardingFeatureRow(icon: "chart.pie.fill", title: "Split extra cash with a plan")
                OnboardingFeatureRow(icon: "link", title: "Connect bank data with Plaid")
            }

            OnboardingPrimaryButton(title: "Get Started") {
                step = .connectBank
            }
        }
    }

    private func connectBankStep(_ userSettings: UserSettings) -> some View {
        let hasConnectedBanks = userSettings.hasLinkedPlaid
            || plaidViewModel.hasConnectedInstitutions

        return VStack(spacing: 16) {
            BankConnectCard(
                isLinked: hasConnectedBanks,
                isLoading: plaidViewModel.isLoading,
                statusMessage: plaidViewModel.statusMessage,
                errorMessage: plaidViewModel.errorMessage,
                institutions: plaidViewModel.institutions,
                accounts: plaidViewModel.accounts
            )

            if hasConnectedBanks {
                OnboardingPrimaryButton(title: "Continue") {
                    step = .preferences
                }

                Button {
                    connectBank()
                } label: {
                    OnboardingButtonLabel(title: "Connect Another Bank", style: .secondary)
                }
                .disabled(plaidViewModel.isLoading)
            } else {
                OnboardingPrimaryButton(title: "Connect Bank") {
                    connectBank()
                }
                .disabled(plaidViewModel.isLoading)

                Button {
                    step = .preferences
                } label: {
                    OnboardingButtonLabel(title: "Skip for now", style: .secondary)
                }
            }
        }
    }

    private func preferencesStep(_ userSettings: UserSettings) -> some View {
        VStack(spacing: 14) {
            OnboardingCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Protected Balance")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Text("Amount to keep in checking.")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.52))
                        }

                        Spacer()

                        Text(CurrencyFormatter.dollars(userSettings.minimumCheckingBuffer))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                    }

                    CurrencyInputField(
                        value: Binding(
                            get: { userSettings.minimumCheckingBuffer },
                            set: { newValue in
                                userSettings.minimumCheckingBuffer = newValue
                                saveSettings()
                            }
                        )
                    )

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

            OnboardingCard {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Allocation Preview")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text("Split preview using your protected balance amount.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.52))
                    }

                    AllocationPreviewRows(userSettings: userSettings)
                }
            }

            OnboardingCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Allocation Style")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Choose a starting point.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.52))
                }

                AllocationPresetButton(title: "Balanced", subtitle: "Save, invest, and keep a small cushion") {
                    userSettings.applyBalancedAllocation()
                    saveSettings()
                }

                AllocationPresetButton(title: "Conservative", subtitle: "More cash cushion, less investing") {
                    userSettings.applyConservativeAllocation()
                    saveSettings()
                }

                AllocationPresetButton(title: "Growth", subtitle: "Prioritize investments and retirement") {
                    userSettings.applyGrowthAllocation()
                    saveSettings()
                }
            }

            OnboardingPrimaryButton(title: "Review Setup") {
                step = .finish
            }
        }
    }

    private func finishStep(_ userSettings: UserSettings) -> some View {
        VStack(spacing: 14) {
            OnboardingCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Review")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.72))

                    Text(CurrencyFormatter.dollars(userSettings.minimumCheckingBuffer))
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)

                    Text("Protected balance")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.54))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            OnboardingCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Allocation Preview")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Spacer()

                        Text(userSettings.hasLinkedPlaid ? "Bank connected" : "Bank skipped")
                            .font(.caption.bold())
                            .foregroundStyle(userSettings.hasLinkedPlaid ? .green : .white.opacity(0.46))
                    }

                    AllocationPreviewRows(userSettings: userSettings)
                }
            }

            OnboardingPrimaryButton(title: "Open Dashboard") {
                userSettings.hasCompletedOnboarding = true
                saveSettings()
            }
        }
    }

    private func allocationSummary(for userSettings: UserSettings) -> String {
        "\(percent(userSettings.savingsAllocationPercent)) savings / \(percent(userSettings.investmentAllocationPercent)) investing / \(percent(userSettings.retirementAllocationPercent)) retirement / \(percent(userSettings.bufferAllocationPercent)) buffer"
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func connectBank() {
        Task {
            await plaidViewModel.prepareLinkSession()

            if plaidViewModel.linkConfiguration != nil {
                plaidViewModel.openPlaidLink()
            }
        }
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

private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case connectBank
    case preferences
    case finish

    var title: String {
        switch self {
        case .welcome:
            return "Meet Spendant"
        case .connectBank:
            return "Connect Bank"
        case .preferences:
            return "Set Guardrails"
        case .finish:
            return "Ready"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            return "A simpler way to know what you can move."
        case .connectBank:
            return "Securely connect accounts with Plaid."
        case .preferences:
            return "Set your buffer and default money split."
        case .finish:
            return "Everything is saved on this device."
        }
    }
}

private struct OnboardingCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial.opacity(0.52))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct OnboardingHeroCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 78, height: 78)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 22)
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
}

private struct OnboardingFeatureRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.bold())
                .foregroundStyle(.green)
                .frame(width: 32, height: 32)
                .background(Color.green.opacity(0.14))
                .clipShape(Circle())

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))

            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct CurrencyInputField: View {
    @Binding var value: Double
    @State private var draftValue: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("$")
                .font(.title3.bold())
                .foregroundStyle(.green)

            TextField("0", text: $draftValue)
                .font(.title3.weight(.semibold))
                .keyboardType(.decimalPad)
                .foregroundStyle(.white)
                .focused($isFocused)
                .onChange(of: draftValue) { _, newValue in
                    let filtered = newValue.filter { character in
                        character.isNumber || character == "."
                    }

                    if filtered != newValue {
                        draftValue = filtered
                        return
                    }

                    value = Double(filtered) ?? 0
                }
                .onChange(of: value) { _, newValue in
                    guard !isFocused else {
                        return
                    }

                    draftValue = Self.formattedDraft(newValue)
                }
                .onAppear {
                    draftValue = Self.formattedDraft(value)
                }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color.white.opacity(0.075))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private static func formattedDraft(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }
}

private struct AllocationPreviewRows: View {
    let userSettings: UserSettings

    var body: some View {
        VStack(spacing: 10) {
            AllocationPreviewRow(
                title: "Savings",
                percent: userSettings.savingsAllocationPercent,
                amount: amount(for: userSettings.savingsAllocationPercent)
            )

            AllocationPreviewRow(
                title: "Investing",
                percent: userSettings.investmentAllocationPercent,
                amount: amount(for: userSettings.investmentAllocationPercent)
            )

            AllocationPreviewRow(
                title: "Retirement",
                percent: userSettings.retirementAllocationPercent,
                amount: amount(for: userSettings.retirementAllocationPercent)
            )

            AllocationPreviewRow(
                title: "Buffer",
                percent: userSettings.bufferAllocationPercent,
                amount: amount(for: userSettings.bufferAllocationPercent)
            )
        }
    }

    private func amount(for percent: Double) -> Double {
        userSettings.minimumCheckingBuffer * percent
    }
}

private struct AllocationPreviewRow: View {
    let title: String
    let percent: Double
    let amount: Double

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text("\(Int((percent * 100).rounded()))%")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.46))
            }

            Spacer()

            Text(CurrencyFormatter.dollars(amount))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.green)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct BankConnectCard: View {
    let isLinked: Bool
    let isLoading: Bool
    let statusMessage: String
    let errorMessage: String?
    let institutions: [PlaidInstitutionAccounts]
    let accounts: [PlaidAccount]

    var body: some View {
        OnboardingCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: isLinked ? "checkmark.shield.fill" : "building.columns.fill")
                        .font(.title3)
                        .foregroundStyle(isLinked ? .black : .green)
                        .frame(width: 46, height: 46)
                        .background(isLinked ? Color.green : Color.green.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(isLinked ? "Your Connected Banks" : "Connect with Plaid")
                            .font(.title3.bold())
                            .foregroundStyle(.white)

                        Text(isLinked ? connectedSubtitle : "Securely link your accounts to power your dashboard.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.58))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }

                if isLinked && (!institutions.isEmpty || !accounts.isEmpty) {
                    ConnectedAccountSummary(
                        institutions: institutions,
                        accounts: accounts
                    )
                } else if isLinked {
                    LoadingAccountSummary(isLoading: isLoading)
                } else {
                    PreConnectionSummary()
                }

                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView()
                            .tint(.green)
                            .scaleEffect(0.82)
                    } else {
                        Circle()
                            .fill(isLinked ? Color.green : Color.white.opacity(0.20))
                            .frame(width: 8, height: 8)
                    }

                    Text(isLoading ? "Loading account details..." : statusMessage)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private var connectedSubtitle: String {
        if !institutions.isEmpty {
            let bankCount = institutions.count
            let accountCount = accounts.count
            return "Review \(bankCount) bank\(bankCount == 1 ? "" : "s") and \(accountCount) account\(accountCount == 1 ? "" : "s") before continuing."
        }

        if accounts.isEmpty {
            return "Loading your connected accounts..."
        }

        return "Review your \(accounts.count) connected account\(accounts.count == 1 ? "" : "s") before continuing."
    }
}

private struct PreConnectionSummary: View {
    var body: some View {
        VStack(spacing: 10) {
            MiniConnectionRow(icon: "checkmark.circle.fill", title: "Balances", value: "Used for cash flow")
            MiniConnectionRow(icon: "checkmark.circle.fill", title: "Transactions", value: "Used for categories")
            MiniConnectionRow(icon: "lock.fill", title: "Security", value: "Handled by Plaid")
        }
    }
}

private struct LoadingAccountSummary: View {
    let isLoading: Bool

    var body: some View {
        HStack {
            Text(isLoading ? "Loading account details" : "Account details unavailable")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))

            Spacer()

            if isLoading {
                ProgressView()
                    .tint(.green)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ConnectedAccountSummary: View {
    let institutions: [PlaidInstitutionAccounts]
    let accounts: [PlaidAccount]

    var body: some View {
        VStack(spacing: 12) {
            balanceSummaryTiles

            if institutions.isEmpty {
                flatAccountList
            } else {
                institutionList
            }
        }
    }

    private var flatAccountList: some View {
        VStack(spacing: 8) {
            ForEach(accounts) { account in
                ConnectedAccountRow(account: account)
            }
        }
    }

    private var institutionList: some View {
        VStack(spacing: 14) {
            ForEach(institutions) { institution in
                VStack(alignment: .leading, spacing: 10) {
                    InstitutionHeader(
                        name: institution.displayName,
                        accountCount: institution.accounts.count
                    )

                    VStack(spacing: 8) {
                        ForEach(institution.accounts) { account in
                            ConnectedAccountRow(account: account)
                        }
                    }
                }
                .padding(12)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var balanceSummaryTiles: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ],
            spacing: 10
        ) {
            if hasCheckingAccounts {
                BalanceTile(
                    title: "Checking",
                    amount: accounts.totalBalance(where: \.isCheckingAccount)
                )
            }

            if hasSavingsAccounts {
                BalanceTile(
                    title: "Savings",
                    amount: accounts.totalBalance(where: \.isSavingsAccount)
                )
            }

            if hasCreditAccounts {
                BalanceTile(
                    title: "Credit Cards",
                    amount: accounts.totalBalance(where: \.isCreditAccount)
                )
            }
        }
    }

    private var hasCheckingAccounts: Bool {
        accounts.contains(where: \.isCheckingAccount)
    }

    private var hasSavingsAccounts: Bool {
        accounts.contains(where: \.isSavingsAccount)
    }

    private var hasCreditAccounts: Bool {
        accounts.contains(where: \.isCreditAccount)
    }
}

struct InstitutionHeader: View {
    let name: String
    let accountCount: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "building.columns.fill")
                .font(.caption.bold())
                .foregroundStyle(.green)
                .frame(width: 30, height: 30)
                .background(Color.green.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)

                Text("\(accountCount) account\(accountCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()
        }
    }
}

struct ConnectedAccountRow: View {
    let account: PlaidAccount

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: account.iconName)
                .font(.caption.bold())
                .foregroundStyle(.green)
                .frame(width: 26, height: 26)
                .background(Color.green.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)

                Text(account.typeLabel)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
            }

            Spacer()

            Text(account.formattedBalance)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct BalanceTile: View {
    let title: String
    let amount: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.48))

            Text(CurrencyFormatter.dollars(amount))
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct MiniConnectionRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(.green)
                .frame(width: 26, height: 26)
                .background(Color.green.opacity(0.12))
                .clipShape(Circle())

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(1)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct OnboardingPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            OnboardingButtonLabel(title: title, style: .primary)
        }
    }
}

private struct OnboardingButtonLabel: View {
    enum Style {
        case primary
        case secondary
    }

    let title: String
    let style: Style

    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(style == .primary ? Color.green : Color.white.opacity(0.07))
            .foregroundStyle(style == .primary ? Color.black : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct AllocationPresetButton: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(.green)
                    .frame(width: 32, height: 32)
                    .background(Color.green.opacity(0.14))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.54))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.28))
            }
            .padding()
            .background(Color.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct SummaryLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: UserSettings.self, inMemory: true)
        .preferredColorScheme(.dark)
}
