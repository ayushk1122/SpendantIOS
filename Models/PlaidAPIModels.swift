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
    let institutionID: String?
    let institutionName: String?

    enum CodingKeys: String, CodingKey {
        case publicToken = "public_token"
        case clientUserID = "client_user_id"
        case institutionID = "institution_id"
        case institutionName = "institution_name"
    }
}

struct PlaidItemSummary: Decodable, Identifiable {
    let itemID: String
    let institutionID: String?
    let institutionName: String?
    let accountCount: Int

    var id: String { itemID }

    enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case institutionID = "institution_id"
        case institutionName = "institution_name"
        case accountCount = "account_count"
    }
}

struct PlaidItemsResponse: Decodable {
    let items: [PlaidItemSummary]
}

struct PlaidAccountsResponse: Decodable {
    let accounts: [PlaidAccount]
    let institutions: [PlaidInstitutionAccounts]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accounts = try container.decode([PlaidAccount].self, forKey: .accounts)
        institutions = try container.decodeIfPresent(
            [PlaidInstitutionAccounts].self,
            forKey: .institutions
        ) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case accounts
        case institutions
    }
}

struct PlaidInstitutionAccounts: Decodable, Identifiable {
    let itemID: String
    let institutionID: String?
    let institutionName: String?
    let accounts: [PlaidAccount]

    var id: String { itemID }

    var displayName: String {
        institutionName ?? "Connected Bank"
    }

    init(
        itemID: String,
        institutionID: String?,
        institutionName: String?,
        accounts: [PlaidAccount]
    ) {
        self.itemID = itemID
        self.institutionID = institutionID
        self.institutionName = institutionName
        self.accounts = accounts
    }

    enum CodingKeys: String, CodingKey {
        case itemID = "item_id"
        case institutionID = "institution_id"
        case institutionName = "institution_name"
        case accounts
    }
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
    let itemID: String?
    let institutionID: String?
    let institutionName: String?
    let name: String
    let officialName: String?
    let type: String
    let subtype: String?
    let balance: Double?
    let availableBalance: Double?

    var id: String { accountID }

    var displayName: String {
        if let officialName, !officialName.isEmpty, officialName != name {
            return officialName
        }

        return name
    }

    var typeLabel: String {
        switch (type.lowercased(), subtype?.lowercased()) {
        case ("credit", _):
            return "Credit Card"
        case ("depository", "checking"):
            return "Checking"
        case ("depository", "savings"):
            return "Savings"
        case ("depository", _):
            return "Bank Account"
        case ("loan", "mortgage"):
            return "Mortgage"
        case ("loan", _):
            return "Loan"
        case ("investment", _):
            return "Investment"
        default:
            if let subtype, !subtype.isEmpty {
                return subtype.capitalized
            }

            return type.capitalized
        }
    }

    var iconName: String {
        switch (type.lowercased(), subtype?.lowercased()) {
        case ("credit", _):
            return "creditcard.fill"
        case ("depository", "savings"):
            return "banknote.fill"
        case ("depository", _):
            return "building.columns.fill"
        case ("loan", _):
            return "house.fill"
        case ("investment", _):
            return "chart.line.uptrend.xyaxis"
        default:
            return "wallet.pass.fill"
        }
    }

    var resolvedBalance: Double {
        balance ?? availableBalance ?? 0
    }

    var formattedBalance: String {
        CurrencyFormatter.dollars(resolvedBalance)
    }

    var isCheckingAccount: Bool {
        type.lowercased() == "depository" && subtype?.lowercased() == "checking"
    }

    var isSavingsAccount: Bool {
        type.lowercased() == "depository" && subtype?.lowercased() == "savings"
    }

    var isCreditAccount: Bool {
        type.lowercased() == "credit"
    }

    enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case itemID = "item_id"
        case institutionID = "institution_id"
        case institutionName = "institution_name"
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

extension Array where Element == PlaidAccount {
    func totalBalance(where predicate: (PlaidAccount) -> Bool) -> Double {
        filter(predicate)
            .map(\.resolvedBalance)
            .reduce(0, +)
    }
}

struct PlaidLinkSuccess {
    let publicToken: String
    let institutionID: String?
    let institutionName: String?
}
