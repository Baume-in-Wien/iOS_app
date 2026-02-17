import SwiftUI
import MapKit

struct ExplorerView: View {
    @State private var appState = AppState.shared
    @State private var locationService = LocationService.shared
    @State private var selectedTab: ExplorerTab = .map
    @State private var showSetup = false
    @State private var showCamera = false
    @State private var selectedMission: Mission?

    enum ExplorerTab: String, CaseIterable {
        case map = "Karte"
        case list = "Missionen"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let session = appState.currentSession {

                    activeSessionView(session)
                } else {

                    setupView
                }
            }
            .navigationTitle("Entdecker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                if appState.currentSession != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Text(appState.currentSession?.progressText ?? "")
                            .font(.hostGrotesk(.headline, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }

                    ToolbarItem(placement: .cancellationAction) {
                        Button("Beenden") {
                            endSession()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .sheet(isPresented: $showSetup) {
                ExplorerSetupSheet(onStart: startSession)
            }
            .fullScreenCover(isPresented: $showCamera) {
                if let mission = selectedMission {
                    PhotoCaptureView(mission: mission) { photoData in
                        completeMission(mission, with: photoData)
                    }
                }
            }
        }
    }

    private var setupView: some View {
        VStack(spacing: 32) {

            VStack(alignment: .leading, spacing: 8) {
                Text("SOLO ENTDECKER:IN")
                    .font(.hostGrotesk(.largeTitle))
                    .fontWeight(.black)

                Text("Finde Bäume in deiner Umgebung")
                    .font(.hostGrotesk(.title3))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 16)

            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.green.opacity(0.2), .green.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 180, height: 180)

                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 70))
                    .foregroundStyle(.green)
                    .symbolEffect(.pulse)
            }

            HStack(spacing: 24) {
                StatBadge(icon: "tree.fill", value: "\(appState.totalTreesDiscovered)", label: "Entdeckt")
                StatBadge(icon: "leaf.fill", value: "\(appState.uniqueSpeciesDiscovered.count)", label: "Arten")
                StatBadge(icon: "figure.walk", value: String(format: "%.1fkm", appState.totalDistanceWalked / 1000), label: "Gelaufen")
            }
            .padding(.top, 20)

            Spacer()

            GlassButton(title: "Neue Session starten", icon: "play.fill") {
                showSetup = true
            }
            .style(.primary)
            .padding(.bottom, 40)
        }
        .padding()
    }

    @ViewBuilder
    private func activeSessionView(_ session: ExplorerSession) -> some View {
        VStack(spacing: 0) {

            Picker("Ansicht", selection: $selectedTab) {
                ForEach(ExplorerTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            GlassProgressBar(
                progress: Double(session.completedCount) / Double(session.missions.count),
                label: nil
            )
            .padding(.horizontal)

            switch selectedTab {
            case .map:
                explorerMapView(session)
            case .list:
                missionListView(session)
            }
        }
    }

    @ViewBuilder
    private func explorerMapView(_ session: ExplorerSession) -> some View {
        Map {
            UserAnnotation()

            ForEach(session.missions) { mission in
                Annotation(mission.tree.speciesGerman, coordinate: mission.tree.coordinate) {
                    MissionMarkerView(mission: mission) {
                        selectMission(mission)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .overlay(alignment: .bottom) {

            if let currentMission = session.missions.first(where: { $0.status != .completed }) {
                MissionCardView(mission: currentMission) {
                    selectMission(currentMission)
                }
                .padding()
                .padding(.bottom, 20)
            }
        }
    }

    @ViewBuilder
    private func missionListView(_ session: ExplorerSession) -> some View {
        List {
            ForEach(session.missions) { mission in
                MissionRowView(mission: mission) {
                    selectMission(mission)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func selectMission(_ mission: Mission) {
        selectedMission = mission

        if locationService.isWithinRange(of: mission.tree) {
            showCamera = true
        } else {

            appState.selectedTree = mission.tree
        }
    }

    private func startSession(radius: ExplorerRadius, trees: [Tree]) {
        let missions = trees.prefix(5).map { Mission(tree: $0) }
        appState.currentSession = ExplorerSession(radius: radius, missions: Array(missions))
        locationService.resetDistanceTracking()

        AppState.shared.unlockAchievement("first_mission")
    }

    private func completeMission(_ mission: Mission, with photoData: Data?) {
        guard var session = appState.currentSession,
              let index = session.missions.firstIndex(where: { $0.id == mission.id }) else { return }

        session.missions[index].markCompleted(photoData: photoData)
        appState.currentSession = session

        appState.discoverTree(mission.tree)

        if session.isCompleted {
            completeSession()
        }

        showCamera = false
        selectedMission = nil
    }

    private func completeSession() {
        guard let session = appState.currentSession else { return }

        appState.explorerHistory.append(session)

        let totalSessions = appState.explorerHistory.count
        if totalSessions >= 5 {
            AppState.shared.unlockAchievement("explorer_5")
        }
        if totalSessions >= 25 {
            AppState.shared.unlockAchievement("explorer_25")
        }

        appState.currentSession = nil
    }

    private func endSession() {
        appState.currentSession = nil
    }
}

struct ExplorerSetupSheet: View {
    let onStart: (ExplorerRadius, [Tree]) -> Void
    @State private var selectedRadius: ExplorerRadius = .r1km
    @State private var isLoading = false
    @State private var availableTrees: [Tree] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                VStack(alignment: .leading, spacing: 12) {
                    Text("Suchradius")
                        .font(.hostGrotesk(.headline, weight: .semibold))

                    HStack(spacing: 12) {
                        ForEach(ExplorerRadius.allCases, id: \.self) { radius in
                            GlassChip(
                                title: radius.displayName,
                                isSelected: selectedRadius == radius
                            ) {
                                selectedRadius = radius
                                loadTrees()
                            }
                        }
                    }
                }

                if isLoading {
                    ProgressView("Suche Bäume...")
                        .frame(maxHeight: .infinity)
                } else if availableTrees.isEmpty {
                    ContentUnavailableView(
                        "Keine Bäume gefunden",
                        systemImage: "tree",
                        description: Text("Versuche einen größeren Radius")
                    )
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(availableTrees.count) Bäume im Umkreis")
                            .font(.hostGrotesk(.subheadline))
                            .foregroundStyle(.secondary)

                        Text("5 zufällige Bäume werden ausgewählt")
                            .font(.hostGrotesk(.caption))
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()
                }

                GlassButton(title: "Session starten", icon: "play.fill") {
                    let selectedTrees = Array(availableTrees.shuffled().prefix(5))
                    onStart(selectedRadius, selectedTrees)
                    dismiss()
                }
                .style(.primary)
                .disabled(availableTrees.count < 5)
            }
            .padding()
            .navigationTitle("Neue Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadTrees()
        }
    }

    private func loadTrees() {
        guard let location = LocationService.shared.currentLocation?.coordinate else {
            return
        }

        isLoading = true

        Task {
            do {
                let trees = try await WFSService.shared.fetchTrees(
                    around: location,
                    radius: selectedRadius.meters
                )
                await MainActor.run {
                    availableTrees = trees
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

struct MissionMarkerView: View {
    let mission: Mission
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {

                if mission.status == .pending {
                    Circle()
                        .fill(Color.orange.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .scaleEffect(mission.status == .pending ? 1.5 : 1)
                        .opacity(mission.status == .pending ? 0 : 1)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: mission.status)
                }

                Image(systemName: mission.status == .completed ? "checkmark.circle.fill" : "target")
                    .font(.hostGrotesk(.title))
                    .foregroundStyle(mission.status == .completed ? .green : .orange)
                    .frame(width: 40, height: 40)
                    .background(.white, in: Circle())
                    .shadow(radius: 5)
            }
        }
    }
}

struct MissionCardView: View {
    let mission: Mission
    let action: () -> Void
    @State private var locationService = LocationService.shared

    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nächstes Ziel")
                            .font(.hostGrotesk(.caption))
                            .foregroundStyle(.secondary)
                        Text(mission.tree.speciesGerman)
                            .font(.hostGrotesk(.headline, weight: .semibold))
                    }

                    Spacer()

                    if let distance = locationService.distance(to: mission.tree.coordinate) {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(formatDistance(distance))
                                .font(.hostGrotesk(.title2))
                                .fontWeight(.bold)
                                .foregroundStyle(distance < 20 ? .green : .primary)

                            if distance < 20 {
                                Text("In Reichweite!")
                                    .font(.hostGrotesk(.caption))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                if let distance = locationService.distance(to: mission.tree.coordinate), distance < 20 {
                    GlassButton(title: "Foto aufnehmen", icon: "camera.fill", action: action)
                        .style(.primary)
                } else {
                    GlassButton(title: "Navigation", icon: "arrow.triangle.turn.up.right.diamond", action: action)
                        .style(.secondary)
                }
            }
        }
    }

    private func formatDistance(_ distance: Double) -> String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
}

struct MissionRowView: View {
    let mission: Mission
    let action: () -> Void
    @State private var locationService = LocationService.shared

    var body: some View {
        Button(action: action) {
            GlassCard(padding: 12) {
                HStack(spacing: 16) {

                    ZStack {
                        Circle()
                            .fill(mission.status == .completed ? Color.green : Color.orange.opacity(0.2))
                            .frame(width: 44, height: 44)

                        Image(systemName: mission.status == .completed ? "checkmark" : mission.tree.speciesIcon)
                            .foregroundStyle(mission.status == .completed ? .white : .orange)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(mission.tree.speciesGerman)
                            .font(.hostGrotesk(.headline, weight: .semibold))
                            .foregroundStyle(.primary)

                        if let street = mission.tree.streetName {
                            Text(street)
                                .font(.hostGrotesk(.caption))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if mission.status != .completed,
                       let distance = locationService.distance(to: mission.tree.coordinate) {
                        Text(formatDistance(distance))
                            .font(.hostGrotesk(.subheadline))
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func formatDistance(_ distance: Double) -> String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1fkm", distance / 1000)
        }
    }
}

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = .green

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.hostGrotesk(.title3))
                    .foregroundStyle(color)
            }

            Text(value)
                .font(.hostGrotesk(.title3))
                .fontWeight(.bold)

            Text(label)
                .font(.hostGrotesk(.caption))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.4), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
    }
}

struct PhotoCaptureView: View {
    let mission: Mission
    let onCapture: (Data?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 100))
                    .foregroundStyle(.secondary)

                Text("Foto von \(mission.tree.speciesGerman)")
                    .font(.hostGrotesk(.title2))
                    .fontWeight(.semibold)

                Text("Kamera-Integration würde hier erscheinen")
                    .foregroundStyle(.secondary)

                Spacer()

                GlassButton(title: "Mission abschließen", icon: "checkmark") {
                    onCapture(nil)
                }
                .style(.primary)
            }
            .padding()
            .navigationTitle("Foto aufnehmen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ExplorerView()
}
