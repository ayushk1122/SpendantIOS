import SwiftUI
import SwiftData

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserSettings.createdAt) private var settings: [UserSettings]

    var body: some View {
        Group {
            if let userSettings = settings.first, userSettings.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .task {
            ensureSettingsExist()
        }
    }

    private func ensureSettingsExist() {
        guard settings.isEmpty else {
            return
        }

        modelContext.insert(UserSettings())
        try? modelContext.save()
    }
}

#Preview {
    AppRootView()
        .modelContainer(for: UserSettings.self, inMemory: true)
        .preferredColorScheme(.dark)
}
