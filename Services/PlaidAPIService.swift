import Foundation

final class PlaidAPIService {
    static let shared = PlaidAPIService()

    private init() {}

    func createLinkToken() async throws -> String {
        let url = APIConfig.baseURL.appending(path: "/api/plaid/create-link-token")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_user_id": APIConfig.clientUserID
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await performRequest(request)
        return try JSONDecoder().decode(LinkTokenResponse.self, from: data).linkToken
    }
    
    func fetchDashboardSummary(
        protectedBalance: Double? = nil,
        month: DashboardMonth? = nil
    ) async throws -> DashboardSummaryResponse {
        var queryItems: [URLQueryItem] = []
        if let protectedBalance {
            queryItems.append(URLQueryItem(name: "protected_balance", value: String(protectedBalance)))
        }
        if let month, !month.isCurrentMonth {
            queryItems.append(URLQueryItem(name: "month", value: month.apiValue))
        }

        let url = makeURL(
            path: "/api/dashboard/summary",
            extraQueryItems: queryItems
        )
        let data = try await performRequest(URLRequest(url: url))
        return try JSONDecoder().decode(DashboardSummaryResponse.self, from: data)
    }

    func finalizeDashboardSnapshot(
        month: DashboardMonth,
        protectedBalance: Double?,
        destinations: [MoneyDestinationConfig]
    ) async throws -> DashboardSummaryResponse {
        let url = makeURL(
            path: "/api/dashboard/snapshots/finalize",
            extraQueryItems: [
                URLQueryItem(name: "month", value: month.apiValue)
            ]
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            FinalizeDashboardSnapshotRequest(
                protectedBalance: protectedBalance,
                destinations: destinations
            )
        )

        let data = try await performRequest(request)
        return try JSONDecoder().decode(DashboardSummaryResponse.self, from: data)
    }

    func exchangePublicToken(_ linkSuccess: PlaidLinkSuccess) async throws {
        let url = APIConfig.baseURL.appending(path: "/api/plaid/exchange-public-token")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = PublicTokenRequest(
            publicToken: linkSuccess.publicToken,
            clientUserID: APIConfig.clientUserID,
            institutionID: linkSuccess.institutionID,
            institutionName: linkSuccess.institutionName
        )

        request.httpBody = try JSONEncoder().encode(body)
        _ = try await performRequest(request)
    }

    func fetchItems() async throws -> [PlaidItemSummary] {
        let url = makeURL(path: "/api/plaid/items")
        let data = try await performRequest(URLRequest(url: url))
        return try JSONDecoder().decode(PlaidItemsResponse.self, from: data).items
    }

    func deleteItem(_ itemID: String) async throws {
        let url = makeURL(path: "/api/plaid/items/\(itemID)")

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await performRequest(request)
    }

    func clearAllLinkedItems() async throws {
        let items = try await fetchItems()
        for item in items {
            try await deleteItem(item.itemID)
        }
    }

    func fetchAccountsResponse() async throws -> PlaidAccountsResponse {
        let url = makeURL(path: "/api/plaid/accounts")
        let data = try await performRequest(URLRequest(url: url))
        return try JSONDecoder().decode(PlaidAccountsResponse.self, from: data)
    }

    func fetchAccountsDecoded() async throws -> [PlaidAccount] {
        try await fetchAccountsResponse().accounts
    }

    func fetchBalancesDecoded() async throws -> [PlaidAccount] {
        let url = makeURL(path: "/api/plaid/balances")
        let data = try await performRequest(URLRequest(url: url))
        return try JSONDecoder().decode(PlaidAccountsResponse.self, from: data).accounts
    }

    func fetchTransactionsDecoded() async throws -> [PlaidTransaction] {
        let url = makeURL(path: "/api/plaid/transactions")
        let data = try await performRequest(URLRequest(url: url))
        let decoded = try JSONDecoder().decode(PlaidTransactionsResponse.self, from: data)
        return decoded.allTransactions
    }

    // Keep these for debug screen
    func fetchAccounts() async throws -> String {
        let url = makeURL(path: "/api/plaid/accounts")
        let data = try await performRequest(URLRequest(url: url))
        return prettyJSON(from: data)
    }

    func fetchBalances() async throws -> String {
        let url = makeURL(path: "/api/plaid/balances")
        let data = try await performRequest(URLRequest(url: url))
        return prettyJSON(from: data)
    }

    func fetchTransactions() async throws -> String {
        let url = makeURL(path: "/api/plaid/transactions")
        let data = try await performRequest(URLRequest(url: url))
        return prettyJSON(from: data)
    }

    private func makeURL(
        path: String,
        extraQueryItems: [URLQueryItem] = []
    ) -> URL {
        var components = URLComponents(
            url: APIConfig.baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )!

        components.queryItems = [
            URLQueryItem(name: "client_user_id", value: APIConfig.clientUserID)
        ] + extraQueryItems

        return components.url!
    }

    private func performRequest(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlaidAPIError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let body = String(data: data, encoding: .utf8) ?? "No response body"
            throw PlaidAPIError.serverError(statusCode: httpResponse.statusCode, body: body)
        }

        return data
    }

    private func prettyJSON(from data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
            let string = String(data: prettyData, encoding: .utf8)
        else {
            return String(data: data, encoding: .utf8) ?? ""
        }

        return string
    }
}

enum PlaidAPIError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response."
        case .serverError(let statusCode, let body):
            return "Server error \(statusCode): \(body)"
        }
    }
}
