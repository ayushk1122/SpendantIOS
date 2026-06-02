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

        let decoded = try JSONDecoder().decode(LinkTokenResponse.self, from: data)
        return decoded.linkToken
    }

    func exchangePublicToken(_ publicToken: String) async throws {
        let url = APIConfig.baseURL.appending(path: "/api/plaid/exchange-public-token")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = PublicTokenRequest(
            publicToken: publicToken,
            clientUserID: APIConfig.clientUserID
        )

        request.httpBody = try JSONEncoder().encode(body)

        _ = try await performRequest(request)
    }

    func fetchAccounts() async throws -> String {
        let url = makeURL(path: "/api/plaid/accounts")
        let request = URLRequest(url: url)

        let data = try await performRequest(request)
        return prettyJSON(from: data)
    }

    func fetchBalances() async throws -> String {
        let url = makeURL(path: "/api/plaid/balances")
        let request = URLRequest(url: url)

        let data = try await performRequest(request)
        return prettyJSON(from: data)
    }

    func fetchTransactions() async throws -> String {
        let url = makeURL(path: "/api/plaid/transactions")
        let request = URLRequest(url: url)

        let data = try await performRequest(request)
        return prettyJSON(from: data)
    }

    private func makeURL(path: String) -> URL {
        var components = URLComponents(
            url: APIConfig.baseURL.appending(path: path),
            resolvingAgainstBaseURL: false
        )!

        components.queryItems = [
            URLQueryItem(name: "client_user_id", value: APIConfig.clientUserID)
        ]

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
