import SwiftUI
import MapKit

struct RallyActiveView: View {
    let rally: Rally
    @Binding var progress: RallyProgress?
    let onExit: () -> Void

    @StateObject private var realtimeManager = RallyRealtimeManager()
    @State private var selectedTab = 0
    @State private var statistics: RallyStatistics?
    @State private var isLoading = false
    @State private var showMap = false
    @State private var notificationMessage: String?

    private var participants: [RallyParticipant] {
        realtimeManager.participants
    }

    private var collections: [RallyCollection] {
        realtimeManager.collections
    }

    var body: some View {
        VStack(spacing: 0) {

            if realtimeManager.currentState == .loading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Lade...")
                        .font(.hostGrotesk(.caption))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if let message = notificationMessage {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.white)
                    Text(message)
                        .font(.hostGrotesk(.caption))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.green)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            rallyInfoCard

            Picker("", selection: $selectedTab) {
                Text("Teilnehmer (\(participants.count))").tag(0)
                Text("Bäume (\(collections.count))").tag(1)
                Text("Statistik").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            TabView(selection: $selectedTab) {
                ParticipantsTabView(participants: participants)
                    .tag(0)

                CollectionsTabView(collections: collections)
                    .tag(1)

                StatisticsTabView(statistics: statistics)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationTitle(rally.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {

                    if rally.mode == .teacher {
                        NavigationLink {
                            TeacherDashboardView(rally: rally)
                        } label: {
                            Label("Lehrer:innen-Dashboard", systemImage: "person.3.sequence.fill")
                        }

                        Divider()
                    }

                    Button {
                        showMap = true
                    } label: {
                        Label("Karte anzeigen", systemImage: "map")
                    }

                    Button {
                        Task { await refreshData() }
                    } label: {
                        Label("Aktualisieren", systemImage: "arrow.clockwise")
                    }

                    Divider()

                    Button(role: .destructive) {
                        realtimeManager.unsubscribe()
                        Task {
                            _ = await SupabaseService.shared.leaveRally(rallyId: rally.id)
                            onExit()
                        }
                    } label: {
                        Label("Rally verlassen", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showMap) {
            RallyMapView(rally: rally, collections: collections)
        }
        .task {

            realtimeManager.subscribeToRally(rallyId: rally.id)
            await loadStatistics()
        }
        .onDisappear {
            realtimeManager.unsubscribe()
        }
        .onChange(of: realtimeManager.currentState) { _, newState in
            handleStateChange(newState)
        }
        .refreshable {
            await refreshData()
        }
        .animation(.default, value: notificationMessage)
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

                Text(rally.code)
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 8) {
                StatusChip(text: "Mode: \(rally.mode.displayName)")
                StatusChip(text: "Status: \(rally.status.rawValue)")
                StatusChip(text: "Creator: \(rally.creatorPlatform)")
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func refreshData() async {
        await realtimeManager.refresh()
        await loadStatistics()
    }

    private func loadStatistics() async {
        let result = await SupabaseService.shared.getRallyStats(rallyId: rally.id)
        if case .success(let data) = result {
            await MainActor.run {
                statistics = data
            }
        }
    }

    private func handleStateChange(_ state: RallyState) {
        switch state {
        case .participantJoined(let participant):
            showNotification("\(participant.displayName) ist beigetreten (\(participant.platform))")
        case .participantLeft(let participant):
            showNotification("\(participant.displayName) hat verlassen")
        case .treeCollected(let collection):
            showNotification("Neuer Baum: \(collection.species)")

            Task { await loadStatistics() }
        case .rallyFinished(_):
            showNotification("Rally beendet!")
        default:
            break
        }
    }

    private func showNotification(_ message: String) {
        withAnimation {
            notificationMessage = message
        }

        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                withAnimation {
                    notificationMessage = nil
                }
            }
        }
    }
}

struct StatusChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.hostGrotesk(.caption2))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.quaternary)
            .clipShape(Capsule())
    }
}

struct ParticipantsTabView: View {
    let participants: [RallyParticipant]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(participants) { participant in
                    ParticipantCard(participant: participant)
                }

                if participants.isEmpty {
                    ContentUnavailableView(
                        "Keine Teilnehmer",
                        systemImage: "person.3",
                        description: Text("Teile den Rally-Code, um Teilnehmer einzuladen")
                    )
                    .padding(.top, 40)
                }
            }
            .padding()
        }
    }
}

struct ParticipantCard: View {
    let participant: RallyParticipant

    var body: some View {
        HStack(spacing: 12) {

            Image(systemName: participant.platform == "ios" ? "iphone" : "candybarphone")
                .font(.hostGrotesk(.title2))
                .frame(width: 40, height: 40)
                .background(.green.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(participant.displayName)
                    .font(.hostGrotesk(.headline, weight: .semibold))

                HStack(spacing: 4) {
                    Text("\(participant.speciesCollected) Arten")
                    Text("·")
                    Text("\(participant.treesScanned) Bäume")
                }
                .font(.hostGrotesk(.caption))
                .foregroundStyle(.secondary)
            }

            Spacer()

            if participant.isActive {
                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CollectionsTabView: View {
    let collections: [RallyCollection]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(collections) { collection in
                    CollectionCard(collection: collection)
                }

                if collections.isEmpty {
                    ContentUnavailableView(
                        "Keine Bäume gesammelt",
                        systemImage: "tree",
                        description: Text("Gehe raus und sammle Bäume für die Rally!")
                    )
                    .padding(.top, 40)
                }
            }
            .padding()
        }
    }
}

struct CollectionCard: View {
    let collection: RallyCollection

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.species)
                    .font(.hostGrotesk(.headline, weight: .semibold))

                Text("Baum-ID: \(collection.treeId)")
                    .font(.hostGrotesk(.caption))
                    .foregroundStyle(.secondary)

                if let notes = collection.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.hostGrotesk(.caption))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.hostGrotesk(.title2))
                .foregroundStyle(.green)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatisticsTabView: View {
    let statistics: RallyStatistics?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let stats = statistics {

                    RallyStatCard(
                        title: "Gesamt-Statistik",
                        items: [
                            ("Teilnehmer", "\(stats.totalParticipants)"),
                            ("Gesammelte Bäume", "\(stats.totalTreesCollected)"),
                            ("Einzigartige Arten", "\(stats.totalUniqueSpecies)")
                        ]
                    )

                    if let topCollectors = stats.topCollectors, !topCollectors.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("🏆 Top Sammler")
                                .font(.title3.bold())

                            ForEach(topCollectors) { collector in
                                TopCollectorCard(collector: collector)
                            }
                        }
                    }

                    if let mostCollected = stats.mostCollectedSpecies, !mostCollected.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("🌳 Häufigste Arten")
                                .font(.title3.bold())

                            ForEach(mostCollected) { species in
                                HStack {
                                    Text(species.species)
                                        .font(.hostGrotesk(.subheadline))
                                    Spacer()
                                    Text("\(species.count)x")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.green)
                                }
                                .padding()
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()
        }
    }
}

struct RallyStatCard: View {
    let title: String
    let items: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.hostGrotesk(.headline, weight: .semibold))

            ForEach(items, id: \.0) { item in
                HStack {
                    Text(item.0)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(item.1)
                        .font(.hostGrotesk(.headline, weight: .semibold))
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TopCollectorCard: View {
    let collector: TopCollector

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: collector.platform == "ios" ? "iphone" : "candybarphone")
                .font(.hostGrotesk(.title3))

            VStack(alignment: .leading, spacing: 2) {
                Text(collector.name)
                    .font(.subheadline.bold())

                Text("\(collector.speciesCount) Arten · \(collector.treeCount) Bäume")
                    .font(.hostGrotesk(.caption))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct RallyMapView: View {
    @Environment(\.dismiss) private var dismiss
    let rally: Rally
    let collections: [RallyCollection]

    var body: some View {
        NavigationStack {
            Map {

                if let center = rally.centerCoordinate {
                    Annotation("Rally Zentrum", coordinate: center) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.hostGrotesk(.title))
                            .foregroundStyle(.red)
                    }
                }

                ForEach(collections) { collection in
                    Annotation(collection.species, coordinate: collection.coordinate) {
                        Image(systemName: "tree.fill")
                            .foregroundStyle(.green)
                            .background(Circle().fill(.white).frame(width: 24, height: 24))
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .navigationTitle("Rally Karte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        RallyActiveView(
            rally: Rally(
                id: "1",
                code: "ABC123",
                name: "Test Rally",
                description: "Eine Test-Rally",
                creatorId: "user1",
                creatorPlatform: "ios",
                mode: .student,
                status: .active,
                maxParticipants: 50,
                targetSpeciesCount: 5,
                timeLimitMinutes: nil,
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
            ),
            progress: .constant(nil),
            onExit: {}
        )
    }
}
