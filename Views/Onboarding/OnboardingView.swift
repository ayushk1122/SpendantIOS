import SwiftUI

struct OnboardingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("$pendant")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Know how much you can safely spend, save, and invest each month.")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                // Later: mark onboarding complete
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.top)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    OnboardingView()
        .preferredColorScheme(.dark)
}
