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

    private var handler: Handler?

    func createLinkToken() async {
        isLoading = true
        errorMessage = nil

        do {
            let token = try await PlaidAPIService.shared.createLinkToken()
            linkToken = token

            linkConfiguration = PlaidLinkManager.createConfiguration(
                linkToken: token
            ) { publicToken in
                Task { @MainActor in
                    await self.exchangePublicToken(publicToken)
                }
            }

            statusMessage = "Ready to connect bank"
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

    func exchangePublicToken(_ publicToken: String) async {
        isLoading = true
        errorMessage = nil

        do {
            try await PlaidAPIService.shared.exchangePublicToken(publicToken)
            statusMessage = "Bank linked successfully"
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = "Failed to exchange public token"
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
