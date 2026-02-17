import SwiftUI
import MapKit

struct TeacherDashboardView: View {
    let rally: Rally
    @StateObject private var realtimeManager = RallyRealtimeManager()
    @State private var statistics: RallyStatistics?
    @State private var isLoading = false
    @State private var showEndRallyConfirmation = false
    @State private var selectedTab = 0

    private var participants: [RallyParticipant] {
        realtimeManager.participants.sorted { $0.speciesCollected > $1.speciesCollected }
    }

    private var collections: [RallyCollection] {
        realtimeManager.collections
    }

    var body: some View {
        VStack(spacing: 0) {

            rallyInfoCard

            Picker("", selection: $selectedTab) {
                Text("Teilnehmer:innen (\(participants.count))").tag(0)
                Text("Bäume (\(collections.count))").tag(1)
                Text("Karte").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            TabView(selection: $selectedTab) {
                participantsTab
                    .tag(0)

                collectionsTab
                    .tag(1)

                mapTab
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle("Lehrer:innen-Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Label("Aktualisieren", systemImage: "arrow.clockwise")
                    }

                    Button(role: .destructive) {
                        showEndRallyConfirmation = true
                    } label: {
                        Label("Rallye beenden", systemImage: "stop.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Rallye beenden?", isPresented: $showEndRallyConfirmation) {
            Button("Rallye beenden", role: .destructive) {
                Task {
                    _ = await SupabaseService.shared.endRally(rallyId: rally.id)
                }
            }
        } message: {
            Text("Alle Teilnehmer:innen werden benachrichtigt und können keine Bäume mehr sammeln.")
        }
        .task {
            realtimeManager.subscribeToRally(rallyId: rally.id)
            await loadStatistics()
        }
        .onDisappear {
            realtimeManager.unsubscribe()
        }
        .refreshable {
            await refresh()
        }
    }

    private var rallyInfoCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rally.name)
                        .font(.hostGrotesk(.headline, weight: .semibold))
                    if let desc = rally.description, !desc.isEmpty {
                        Text(desc)
                            .font(.hostGrotesk(.caption))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("CODE")
                        .font(.hostGrotesk(.caption2))
                        .foregroundStyle(.secondary)
                    Text(rally.code)
                        .font(.system(.title3, design: .monospaced, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            HStack(spacing: 16) {
                DashboardStatBadge(
                    value: "\(participants.count)",
                    label: "Teilnehmer",
                    icon: "person.3.fill",
                    color: .blue
                )

                DashboardStatBadge(
                    value: "\(collections.count)",
                    label: "Bäume",
                    icon: "tree.fill",
                    color: .green
                )

                if let stats = statistics {
                    DashboardStatBadge(
                        value: "\(stats.totalUniqueSpecies)",
                        label: "Arten",
                        icon: "leaf.fill",
                        color: .mint
                    )
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var participantsTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if participants.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Teilnehmer:innen",
                        systemImage: "person.3",
                        description: Text("Teile den Code \(rally.code), um Schüler:innen einzuladen")
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(Array(participants.enumerated()), id: \.element.id) { index, participant in
                        TeacherParticipantCard(
                            participant: participant,
                            rank: index + 1,
                            collections: collections.filter { $0.participantId == participant.id }
                        )
                    }
                }
            }
            .padding()
        }
    }

    private var collectionsTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if collections.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Bäume gesammelt",
                        systemImage: "tree",
                        description: Text("Die Teilnehmer:innen sammeln gerade...")
                    )
                    .padding(.top, 40)
                } else {

                    let grouped = Dictionary(grouping: collections) { $0.species }
                    ForEach(grouped.keys.sorted(), id: \.self) { species in
                        if let speciesCollections = grouped[species] {
                            SpeciesGroupCard(
                                species: species,
                                collections: speciesCollections
                            )
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var mapTab: some View {
        Map {

            if let center = rally.centerCoordinate {
                Annotation("Rallye Zentrum", coordinate: center) {
                    ZStack {
                        Circle()
                            .fill(.red.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Image(systemName: "flag.fill")
                            .foregroundStyle(.red)
                    }
                }
            }

            ForEach(collections) { collection in
                Annotation(collection.species, coordinate: collection.coordinate) {
                    ZStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 30, height: 30)
                        Image(systemName: "tree.fill")
                            .font(.hostGrotesk(.caption))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
    }

    private func refresh() async {
        await realtimeManager.refresh()
        await loadStatistics()
    }

    private func loadStatistics() async {
        let result = await SupabaseService.shared.getRallyStats(rallyId: rally.id)
        if case .success(let stats) = result {
            await MainActor.run {
                statistics = stats
            }
        }
    }
}

struct DashboardStatBadge: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.hostGrotesk(.caption))
                Text(value)
                    .font(.hostGrotesk(.headline, weight: .semibold))
            }
            .foregroundStyle(color)

            Text(label)
                .font(.hostGrotesk(.caption2))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct TeacherParticipantCard: View {
    let participant: RallyParticipant
    let rank: Int
    let collections: [RallyCollection]

    var body: some View {
        HStack(spacing: 12) {

            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 36, height: 36)
                Text("\(rank)")
                    .font(.hostGrotesk(.headline, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Image(systemName: participant.platform == "ios" ? "iphone" : "candybarphone")
                .font(.hostGrotesk(.title3))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(participant.displayName)
                    .font(.hostGrotesk(.headline, weight: .semibold))

                HStack(spacing: 8) {
                    Label("\(participant.speciesCollected) Arten", systemImage: "leaf.fill")
                    Label("\(participant.treesScanned) Bäume", systemImage: "tree.fill")
                }
                .font(.hostGrotesk(.caption))
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if participant.isActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("Aktiv")
                            .font(.hostGrotesk(.caption2))
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("Inaktiv")
                        .font(.hostGrotesk(.caption2))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue.opacity(0.7)
        }
    }
}

struct SpeciesGroupCard: View {
    let species: String
    let collections: [RallyCollection]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "tree.fill")
                    .foregroundStyle(.green)
                Text(species)
                    .font(.hostGrotesk(.headline, weight: .semibold))
                Spacer()
                Text("\(collections.count)×")
                    .font(.hostGrotesk(.subheadline))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: -8) {
                ForEach(collections.prefix(5)) { collection in
                    Circle()
                        .fill(.green.gradient)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text(String(collection.participantId.prefix(1)).uppercased())
                                .font(.hostGrotesk(.caption2))
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        )
                }

                if collections.count > 5 {
                    Circle()
                        .fill(.gray)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("+\(collections.count - 5)")
                                .font(.hostGrotesk(.caption2))
                                .foregroundStyle(.white)
                        )
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        TeacherDashboardView(
            rally: Rally(
                id: "1",
                code: "ABC123",
                name: "Botanik Ausflug 5A",
                description: "Entdecke die Bäume im Stadtpark",
                creatorId: "teacher1",
                creatorPlatform: "ios",
                mode: .teacher,
                status: .active,
                maxParticipants: 30,
                targetSpeciesCount: 10,
                timeLimitMinutes: 60,
                districtFilter: nil,
                radiusMeters: 500,
                targetTreeIds: nil,
                centerLat: 48.2082,
                centerLng: 16.3738,
                createdAt: Date(),
                startedAt: nil,
                endedAt: nil,
                isPublic: false,
                allowJoinAfterStart: true
            )
        )
    }
}
