import SwiftUI

struct PetStatusBar: View {
    let type: PetNeedType
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(type.emoji)
                    .font(.hostGrotesk(.caption))

                Text(type.displayName)
                    .font(.hostGrotesk(.caption2))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(value * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(barGradient)
                        .frame(width: max(4, geometry.size.width * value))
                        .animation(.spring(response: 0.5), value: value)
                }
            }
            .frame(height: 8)
        }
        .padding(12)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 12))
    }

    private var barGradient: LinearGradient {
        let colors: [Color]

        if value < 0.2 {
            colors = [.red, .red.opacity(0.7)]
        } else if value < 0.4 {
            colors = [.orange, .orange.opacity(0.7)]
        } else {
            colors = [type.color, type.color.opacity(0.7)]
        }

        return LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var backgroundColor: Color {
        if value < 0.2 {
            return .red.opacity(0.1)
        } else if value < 0.4 {
            return .orange.opacity(0.1)
        } else {
            return Color(.systemGray6)
        }
    }
}

struct PetMiniStatusBar: View {
    let type: PetNeedType
    let value: Double

    var body: some View {
        VStack(spacing: 2) {
            Text(type.emoji)
                .font(.hostGrotesk(.caption2))

            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(height: max(2, geometry.size.height * value))
                        .animation(.spring(response: 0.5), value: value)
                }
            }
            .frame(width: 6, height: 24)
        }
    }

    private var barColor: Color {
        if value < 0.2 {
            return .red
        } else if value < 0.4 {
            return .orange
        } else {
            return type.color
        }
    }
}

struct PetStatusOverview: View {
    let pet: Pet

    var body: some View {
        HStack(spacing: 8) {

            Text(pet.species.emoji)
                .font(.hostGrotesk(.title3))

            HStack(spacing: 4) {
                ForEach(PetNeedType.allCases, id: \.self) { need in
                    PetMiniStatusBar(type: need, value: pet.needValue(for: need))
                }
            }

            if pet.needsAttention {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.hostGrotesk(.caption))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(pet.needsAttention ? Color.red.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }
}

#Preview("Status Bar") {
    VStack(spacing: 16) {
        PetStatusBar(type: .hunger, value: 0.8)
        PetStatusBar(type: .happiness, value: 0.35)
        PetStatusBar(type: .energy, value: 0.15)
        PetStatusBar(type: .cleanliness, value: 0.6)
    }
    .padding()
}

#Preview("Overview") {
    VStack {
        PetStatusOverview(pet: .preview)
        PetStatusOverview(pet: .sadPet)
    }
    .padding()
}
