import Foundation

struct LinkTokenResponse: Decodable {
    let linkToken: String

    enum CodingKeys: String, CodingKey {
        case linkToken = "link_token"
    }
}

struct PublicTokenRequest: Encodable {
    let publicToken: String
    let clientUserID: String

    enum CodingKeys: String, CodingKey {
        case publicToken = "public_token"
        case clientUserID = "client_user_id"
    }
}

struct PlaidAccountsResponse: Decodable {
    let accounts: [PlaidAccount]
}

struct PlaidTransactionsResponse: Decodable {
    let transactions: [PlaidTransaction]?

    // Some Plaid sync responses use "added"
    let added: [PlaidTransaction]?

    var allTransactions: [PlaidTransaction] {
        transactions ?? added ?? []
    }
}

struct PlaidAccount: Decodable, Identifiable {
    let accountID: String
    let name: String
    let officialName: String?
    let type: String
    let subtype: String?
    let balance: Double?
    let availableBalance: Double?

    var id: String { accountID }

    enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case name
        case officialName = "official_name"
        case type
        case subtype
        case balance
        case availableBalance = "available_balance"
    }
}

struct PlaidTransaction: Decodable, Identifiable {
    let transactionID: String
    let accountID: String?
    let name: String
    let merchantName: String?
    let amount: Double
    let date: String
    let category: [String]?
    let personalFinanceCategory: PlaidPersonalFinanceCategory?

    var id: String { transactionID }

    enum CodingKeys: String, CodingKey {
        case transactionID = "transaction_id"
        case accountID = "account_id"
        case name
        case merchantName = "merchant_name"
        case amount
        case date
        case category
        case personalFinanceCategory = "personal_finance_category"
    }
}

struct PlaidPersonalFinanceCategory: Decodable {
    let primary: String?
    let detailed: String?
}
