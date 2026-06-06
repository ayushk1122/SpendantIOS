import SwiftUI
import SwiftData

@main
struct SpendantApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [
            IncomeSource.self,
            FixedExpense.self,
            Subscription.self,
            CreditCardBalance.self,
            FinancialGoal.self,
            UserSettings.self
        ])
    }
}
