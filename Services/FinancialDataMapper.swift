import Foundation

struct DashboardFinancialSummary {
    let checkingBalance: Double
    let incomeTotal: Double
    let housingTotal: Double
    let expenseTotal: Double
    let subscriptionsTotal: Double
}

struct FinancialDataMapper {
    static func makeSummary(
        accounts: [PlaidAccount],
        transactions: [PlaidTransaction]
    ) -> DashboardFinancialSummary {
        let checkingBalance = accounts
            .first(where: { $0.type == "depository" && $0.subtype == "checking" })?
            .balance ?? 0

        let currentMonthTransactions = transactions.filter { isCurrentMonth($0.date) }

        let income = currentMonthTransactions
            .filter { $0.amount < 0 }
            .map { abs($0.amount) }
            .reduce(0, +)

        let outgoing = currentMonthTransactions.filter { $0.amount > 0 }

        let housing = outgoing
            .filter { isHousing($0) }
            .map(\.amount)
            .reduce(0, +)

        let subscriptions = outgoing
            .filter { isSubscription($0) }
            .map(\.amount)
            .reduce(0, +)

        let expenses = outgoing
            .filter { !isHousing($0) && !isSubscription($0) }
            .map(\.amount)
            .reduce(0, +)

        return DashboardFinancialSummary(
            checkingBalance: checkingBalance,
            incomeTotal: income,
            housingTotal: housing,
            expenseTotal: expenses,
            subscriptionsTotal: subscriptions
        )
    }

    private static func isCurrentMonth(_ dateString: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: dateString) else {
            return false
        }

        return Calendar.current.isDate(
            date,
            equalTo: Date(),
            toGranularity: .month
        )
    }

    private static func combinedText(_ transaction: PlaidTransaction) -> String {
        [
            transaction.name,
            transaction.merchantName ?? "",
            transaction.category?.joined(separator: " ") ?? "",
            transaction.personalFinanceCategory?.primary ?? "",
            transaction.personalFinanceCategory?.detailed ?? ""
        ]
        .joined(separator: " ")
        .lowercased()
    }

    private static func isHousing(_ transaction: PlaidTransaction) -> Bool {
        let text = combinedText(transaction)

        return [
            "rent",
            "mortgage",
            "apartment",
            "housing",
            "utility",
            "utilities",
            "electric",
            "gas bill",
            "water",
            "internet",
            "comcast",
            "xfinity",
            "hoa"
        ].contains { text.contains($0) }
    }

    private static func isSubscription(_ transaction: PlaidTransaction) -> Bool {
        let text = combinedText(transaction)

        return [
            "subscription",
            "spotify",
            "netflix",
            "hulu",
            "disney",
            "apple",
            "icloud",
            "youtube",
            "chatgpt",
            "openai",
            "gym",
            "membership"
        ].contains { text.contains($0) }
    }
}
