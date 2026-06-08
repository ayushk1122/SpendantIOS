import SwiftUI
import SwiftData

struct MoneyDestinationsEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var userSettings: UserSettings
    let safeToMoveAmount: Double
    let onDestinationsChanged: () -> Void

    @State private var destinations: [MoneyDestinationConfig] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 12) {
                        ForEach(destinations.indices, id: \.self) { index in
                            destinationEditorRow(at: index)
                        }
                    }

                    addDestinationButton

                    resetDefaultsButton
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Money Destinations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                destinations = userSettings.resolvedMoneyDestinations()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func destinationEditorRow(at index: Int) -> some View {
        let destination = destinations[index]
        let amount = safeToMoveAmount * destination.percent

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                iconPicker(for: index, currentIcon: destination.icon)

                TextField("Destination name", text: nameBinding(for: index))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .textFieldStyle(.plain)

                Spacer(minLength: 0)

                if destinations.count > MoneyDestinationAllocator.minimumDestinationCount {
                    Button(role: .destructive) {
                        persist(MoneyDestinationAllocator.removeDestination(at: index, from: destinations))
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.borderless)
                }
            }

            HStack {
                Text("\(destination.percentPoints)%")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                    .frame(width: 44, alignment: .leading)

                Slider(
                    value: percentBinding(for: index),
                    in: 0...100,
                    step: 1
                )
                .tint(.green)
                .disabled(destinations.count == 1)

                Text(CurrencyFormatter.dollars(amount))
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 88, alignment: .trailing)
            }
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func iconPicker(for index: Int, currentIcon: String) -> some View {
        Menu {
            ForEach(MoneyDestinationConfig.defaultIconOptions, id: \.self) { icon in
                Button {
                    updateDestination(at: index) { destination in
                        destination.icon = icon
                    }
                } label: {
                    Label(iconLabel(for: icon), systemImage: icon)
                }
            }
        } label: {
            Image(systemName: currentIcon)
                .font(.subheadline)
                .foregroundStyle(.green)
                .frame(width: 34, height: 34)
                .background(Color.green.opacity(0.14))
                .clipShape(Circle())
        }
    }

    private var addDestinationButton: some View {
        Button {
            persist(MoneyDestinationAllocator.addDestination(to: destinations))
        } label: {
            Label("Add Destination", systemImage: "plus.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(destinations.count >= MoneyDestinationAllocator.maximumDestinationCount)
    }

    private var resetDefaultsButton: some View {
        Button {
            persist(MoneyDestinationAllocator.resetToDefaults())
        } label: {
            Text("Reset to Default Split")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private func nameBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { destinations[safe: index]?.name ?? "" },
            set: { newValue in
                updateDestination(at: index) { destination in
                    destination.name = newValue
                }
            }
        )
    }

    private func percentBinding(for index: Int) -> Binding<Double> {
        Binding(
            get: {
                Double(destinations[safe: index]?.percentPoints ?? 0)
            },
            set: { newValue in
                let normalized = MoneyDestinationAllocator.updatePercent(
                    at: index,
                    to: newValue / 100,
                    in: destinations
                )
                persist(normalized)
            }
        )
    }

    private func updateDestination(
        at index: Int,
        transform: (inout MoneyDestinationConfig) -> Void
    ) {
        guard destinations.indices.contains(index) else {
            return
        }

        var updated = destinations
        transform(&updated[index])
        persist(updated)
    }

    private func persist(_ updated: [MoneyDestinationConfig]) {
        let normalized = MoneyDestinationAllocator.normalized(updated)
        destinations = normalized
        userSettings.setMoneyDestinations(normalized)
        try? modelContext.save()
        onDestinationsChanged()
    }

    private func iconLabel(for icon: String) -> String {
        icon
            .replacingOccurrences(of: ".fill", with: "")
            .replacingOccurrences(of: ".", with: " ")
            .capitalized
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else {
            return nil
        }

        return self[index]
    }
}
