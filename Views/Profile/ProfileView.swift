import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    profileHeader

                    VStack(spacing: 12) {
                        ProfileRow(title: "Settings", subtitle: "Manage app preferences", icon: "gearshape.fill")
                        ProfileRow(title: "Protected Balance", subtitle: "Set your minimum checking buffer", icon: "shield.fill")
                        ProfileRow(title: "Default Allocation", subtitle: "Customize savings, investing, and buffer splits", icon: "slider.horizontal.3")
                        ProfileRow(title: "Account Connections", subtitle: "Bank connections coming later", icon: "link")
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Profile")
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Ayush")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("Your monthly money command center.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

struct ProfileRow: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 36, height: 36)
                .background(Color.green.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

#Preview {
    ProfileView()
        .preferredColorScheme(.dark)
}
