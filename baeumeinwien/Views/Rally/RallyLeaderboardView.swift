import SwiftUI

struct RallyLeaderboardView: View {
    @Environment(\.dismiss) private var dismiss
    let rallyId: String

    @State private var leaderboard: [LeaderboardEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundStyle(.orange)
                        Text(error)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if leaderboard.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Noch keine Teilnehmer")
                            .font(.hostGrotesk(.headline, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Teile den Rally-Code, damit andere beitreten können!")
                            .font(.hostGrotesk(.subheadline))
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    leaderboardList
                }
            }
            .navigationTitle("Bestenliste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadLeaderboard()
            }
        }
    }

    private var leaderboardList: some View {
        List {
            ForEach(Array(leaderboard.enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: 16) {

                    ZStack {
                        Circle()
                            .fill(rankColor(for: index))
                            .frame(width: 40, height: 40)

                        if index < 3 {
                            Text(rankEmoji(for: index))
                                .font(.hostGrotesk(.title2))
                        } else {
                            Text("\(index + 1)")
                                .font(.hostGrotesk(.headline, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }

                    Image(systemName: entry.platform == "ios" ? "iphone" : "candybarphone")
                        .foregroundStyle(.secondary)
                        .font(.hostGrotesk(.caption))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.displayName)
                                .font(.hostGrotesk(.headline, weight: .semibold))

                            if entry.hasCompleted {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.hostGrotesk(.caption))
                                    .foregroundStyle(.green)
                            }
                        }

                        HStack(spacing: 8) {
                            Label("\(entry.speciesCollected) Arten", systemImage: "leaf.fill")
                                .font(.hostGrotesk(.caption))
                                .foregroundStyle(.green)

                            Label("\(entry.treesScanned) Bäume", systemImage: "tree.fill")
                                .font(.hostGrotesk(.caption))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("\(entry.speciesCollected)")
                            .font(.title2.bold())
                            .foregroundStyle(entry.hasCompleted ? .green : .primary)
                        Text("Arten")
                            .font(.hostGrotesk(.caption2))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func rankEmoji(for index: Int) -> String {
        switch index {
        case 0: return "🥇"
        case 1: return "🥈"
        case 2: return "🥉"
        default: return "\(index + 1)"
        }
    }

    private func rankColor(for index: Int) -> Color {
        switch index {
        case 0: return .yellow
        case 1: return .gray
        case 2: return .orange
        default: return .blue.opacity(0.3)
        }
    }

    private func loadLeaderboard() async {
        isLoading = true
        errorMessage = nil

        let result = await SupabaseService.shared.getLeaderboard(rallyId: rallyId)

        await MainActor.run {
            isLoading = false

            switch result {
            case .success(let entries):
                leaderboard = entries
            case .error(let message):
                errorMessage = message
            }
        }
    }
}

#Preview {
    RallyLeaderboardView(rallyId: "test-rally-id")
}
