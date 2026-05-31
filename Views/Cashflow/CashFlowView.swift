import SwiftUI

struct CashFlowView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)

                Text("Expenses")
                    .font(.title.bold())

                Text("Track variable spending like food, shopping, transport, entertainment, and miscellaneous purchases.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Expenses")
        }
    }
}

#Preview {
    CashFlowView()
        .preferredColorScheme(.dark)
}
