import Foundation
import Combine
import LinkKit
import UIKit

@MainActor
final class PlaidConnectionViewModel: ObservableObject {
    @Published var linkToken: String?
    @Published var linkConfiguration: LinkTokenConfiguration?

    @Published var accountsJSON: String = ""
    @Published var balancesJSON: String = ""
    @Published var transactionsJSON: String = ""

    @Published var statusMessage: String = "Not connected"
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var didLinkBank: Bool = false
    @Published var accounts: [PlaidAccount] = []
    @Published var institutions: [PlaidInstitutionAccounts] = []
    @Published var linkedItems: [PlaidItemSummary] = []

    private var handler: Handler?

    var hasConnectedInstitutions: Bool {
        !institutions.isEmpty || !accounts.isEmpty || didLinkBank
    }

    func prepareLinkSession() async {
        linkConfiguration = nil
        linkToken = nil
        await createLinkToken()
    }

    func createLinkToken() async {
        isLoading = true
        errorMessage = nil

        do {
            let token = try await PlaidAPIService.shared.createLinkToken()
            linkToken = token

            linkConfiguration = PlaidLinkManager.createConfiguration(
                linkToken: token
            ) { linkSuccess in
                Task { @MainActor in
                    await self.exchangePublicToken(linkSuccess)
                }
            }

            statusMessage = hasConnectedInstitutions
                ? "Ready to connect another bank"
                : "Ready to connect bank"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Failed to create Link token"
        }

        isLoading = false
    }

    func openPlaidLink() {
        guard let configuration = linkConfiguration else {
            errorMessage = "Missing Link configuration."
            return
        }

        let result = Plaid.create(configuration)

        switch result {
        case .success(let handler):
            self.handler = handler
            handler.open(presentUsing: .viewController(findViewController()))

        case .failure(let error):
            errorMessage = error.localizedDescription
            statusMessage = "Failed to open Plaid Link"
        }
    }

    func exchangePublicToken(_ linkSuccess: PlaidLinkSuccess) async {
        isLoading = true
        errorMessage = nil

        do {
            try await PlaidAPIService.shared.exchangePublicToken(linkSuccess)
            statusMessage = "Bank linked successfully"
            didLinkBank = true
            linkConfiguration = nil
            linkToken = nil
            await refreshConnectedAccounts()
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Failed to exchange public token"
        }

        isLoading = false
    }

    func refreshConnectedAccounts() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await PlaidAPIService.shared.fetchAccountsResponse()
            accounts = response.accounts
            institutions = response.institutions.isEmpty
                ? fallbackInstitutions(from: response.accounts)
                : response.institutions
            linkedItems = try await PlaidAPIService.shared.fetchItems()
            statusMessage = connectionStatusMessage
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = hasConnectedInstitutions ? "Bank linked" : "Unable to load accounts"
        }

        isLoading = false
    }

    func fetchAccounts() async {
        isLoading = true
        errorMessage = nil

        do {
            accountsJSON = try await PlaidAPIService.shared.fetchAccounts()
            statusMessage = "Fetched accounts"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Failed to fetch accounts"
        }

        isLoading = false
    }

    func fetchBalances() async {
        isLoading = true
        errorMessage = nil

        do {
            balancesJSON = try await PlaidAPIService.shared.fetchBalances()
            statusMessage = "Fetched balances"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Failed to fetch balances"
        }

        isLoading = false
    }

    func fetchTransactions() async {
        isLoading = true
        errorMessage = nil

        do {
            transactionsJSON = try await PlaidAPIService.shared.fetchTransactions()
            statusMessage = "Fetched transactions"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Failed to fetch transactions"
        }

        isLoading = false
    }

    private var connectionStatusMessage: String {
        if institutions.isEmpty {
            return accounts.isEmpty ? "Connected" : "\(accounts.count) accounts connected"
        }

        let bankCount = institutions.count
        let accountCount = accounts.count
        let bankLabel = bankCount == 1 ? "bank" : "banks"
        let accountLabel = accountCount == 1 ? "account" : "accounts"
        return "\(bankCount) \(bankLabel) · \(accountCount) \(accountLabel)"
    }

    private func fallbackInstitutions(from accounts: [PlaidAccount]) -> [PlaidInstitutionAccounts] {
        let grouped = Dictionary(grouping: accounts) { account in
            account.itemID ?? account.institutionID ?? "unknown"
        }

        return grouped.map { key, groupedAccounts in
            PlaidInstitutionAccounts(
                itemID: key,
                institutionID: groupedAccounts.first?.institutionID,
                institutionName: groupedAccounts.first?.institutionName,
                accounts: groupedAccounts
            )
        }
        .sorted { $0.displayName < $1.displayName }
    }

    private func findViewController() -> UIViewController {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let root = scene.windows.first?.rootViewController
        else {
            return UIViewController()
        }

        return root
    }
}
