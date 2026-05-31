import SwiftUI

struct GoalsView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "target")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)

                Text("Goals")
                    .font(.title.bold())

                Text("Set savings, investing, emergency fund, and debt payoff goals here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Goals")
        }
    }
}

#Preview {
    GoalsView()
        .preferredColorScheme(.dark)
}
