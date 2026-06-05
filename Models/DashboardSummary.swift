import Foundation

struct DashboardSummaryResponse: Decodable {
    let checkingBalance: Double
    let incomeTotal: Double
    let housingTotal: Double
    let expensesTotal: Double
    let subscriptionsTotal: Double
    let transferTotal: Double
    let protectedBalance: Double
    let projectedMonthEndBalance: Double
    let safeToMoveAmount: Double
    let transactions: [NormalizedTransaction]

    enum CodingKeys: String, CodingKey {
        case checkingBalance = "checking_balance"
        case incomeTotal = "income_total"
        case housingTotal = "housing_total"
        case expensesTotal = "expenses_total"
        case subscriptionsTotal = "subscriptions_total"
        case transferTotal = "transfer_total"
        case protectedBalance = "protected_balance"
        case projectedMonthEndBalance = "projected_month_end_balance"
        case safeToMoveAmount = "safe_to_move_amount"
        case transactions
    }
}

struct NormalizedTransaction: Decodable, Identifiable {
    let transactionID: String
    let accountID: String?
    let name: String
    let merchantName: String?
    let amount: Double
    let date: String
    let bucket: String
    let pending: Bool
    let plaidPrimaryCategory: String?
    let plaidDetailedCategory: String?

    var id: String { transactionID }

    enum CodingKeys: String, CodingKey {
        case transactionID = "transaction_id"
        case accountID = "account_id"
        case name
        case merchantName = "merchant_name"
        case amount
        case date
        case bucket
        case pending
        case plaidPrimaryCategory = "plaid_primary_category"
        case plaidDetailedCategory = "plaid_detailed_category"
    }
}
