import SwiftUI
import MapKit

struct RallyView: View {
    @State private var appState = AppState.shared
    @State private var showRallyCreate = false
    @State private var showRallyJoin = false
    @State private var showHerbarium = false
    @State private var currentRally: Rally?
    @State private var rallyProgress: RallyProgress?
    @State private var viewMode: RallyViewMode = .map

    enum RallyViewMode: String, CaseIterable {
        case map = "Karte"
        case tabs = "Details"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let rally = currentRally {

                    Picker("Ansicht", selection: $viewMode) {
                        ForEach(RallyViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if viewMode == .map {
                        RallyPlayView(
                            rally: rally,
                            progress: $rallyProgress,
                            onExit: {
                                currentRally = nil
                                rallyProgress = nil
                            }
                        )
                    } else {
                        RallyActiveView(
                            rally: rally,
                            progress: $rallyProgress,
                            onExit: {
                                currentRally = nil
                                rallyProgress = nil
                            }
                        )
                    }
                } else {
                    rallyStartView
                }
            }
            .navigationTitle("Rally")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .sheet(isPresented: $showRallyCreate) {
                RallyCreateView { rally in
                    currentRally = rally
                    Task {
                        if let result = await SupabaseService.shared.getRallyProgress(rallyId: rally.id).value {
                            rallyProgress = result
                        }
                    }
                }
            }
            .sheet(isPresented: $showRallyJoin) {
                RallyJoinView { rally in
                    currentRally = rally
                    Task {
                        if let result = await SupabaseService.shared.getRallyProgress(rallyId: rally.id).value {
                            rallyProgress = result
                        }
                    }
                }
            }
            .sheet(isPresented: $showHerbarium) {
                HerbariumView()
            }
        }
    }

    private var rallyStartView: some View {
        ScrollView {
            VStack(spacing: 24) {

                VStack(alignment: .leading, spacing: 8) {
                    Text("RALLYE")
                        .font(.hostGrotesk(.largeTitle))
                        .fontWeight(.black)

                    Text("Entdecke Bäume in deiner Umgebung")
                        .font(.hostGrotesk(.title3))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 16)

                VStack(spacing: 16) {

                    Button {

                        appState.selectedTab = .explorer
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("SOLO ENTDECKER:IN", systemImage: "globe")
                                    .font(.hostGrotesk(.headline, weight: .semibold))
                                    .foregroundStyle(.white)

                                Text("Starte dein eigenes Abenteuer")
                                    .font(.hostGrotesk(.subheadline))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(20)
                        .background(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .green.opacity(0.3), radius: 12, y: 6)
                    }

                    HStack(spacing: 12) {

                        Button {
                            showRallyJoin = true
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: "graduationcap.fill")
                                    .font(.hostGrotesk(.title2))
                                    .foregroundStyle(.purple)
                                    .padding(10)
                                    .background(.purple.opacity(0.15))
                                    .clipShape(Circle())

                                Spacer()

                                Text("SCHÜLER:INNEN")
                                    .font(.hostGrotesk(.subheadline))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)

                                Text("Code eingeben")
                                    .font(.hostGrotesk(.caption))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 150)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(.quaternary, lineWidth: 1)
                            )
                        }

                        Button {
                            showRallyCreate = true
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.hostGrotesk(.title2))
                                    .foregroundStyle(.orange)
                                    .padding(10)
                                    .background(.orange.opacity(0.15))
                                    .clipShape(Circle())

                                Spacer()

                                Text("LEHRER:INNEN")
                                    .font(.hostGrotesk(.subheadline))
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)

                                Text("Erstellen")
                                    .font(.hostGrotesk(.caption))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 150)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(.quaternary, lineWidth: 1)
                            )
                        }
                    }

                    Button {
                        showHerbarium = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Digitales Herbarium", systemImage: "leaf.fill")
                                    .font(.hostGrotesk(.headline, weight: .semibold))
                                    .foregroundStyle(.primary)

                                Text("Sammle Blätter und Abzeichen")
                                    .font(.hostGrotesk(.subheadline))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()

                            if !appState.herbariumEntries.isEmpty {
                                Text("\(appState.herbariumEntries.count)")
                                    .font(.hostGrotesk(.headline, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.green)
                                    .clipShape(Capsule())
                            }

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding(20)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.quaternary, lineWidth: 1)
                        )
                    }
                }
                .padding()

                VStack(alignment: .leading, spacing: 16) {
                    Text("So funktioniert's")
                        .font(.hostGrotesk(.headline, weight: .semibold))
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        HowItWorksRow(
                            number: 1,
                            icon: "star.fill",
                            title: "Bäume als Favoriten speichern",
                            description: "Markiere Bäume auf der Karte als Favoriten"
                        )

                        HowItWorksRow(
                            number: 2,
                            icon: "plus.circle.fill",
                            title: "Rally erstellen",
                            description: "Wähle deine Favoriten als Ziele aus"
                        )

                        HowItWorksRow(
                            number: 3,
                            icon: "qrcode",
                            title: "Code teilen",
                            description: "Teile den 6-stelligen Code mit deiner Gruppe"
                        )

                        HowItWorksRow(
                            number: 4,
                            icon: "camera.fill",
                            title: "Bäume fotografieren",
                            description: "Finde die Bäume und fotografiere sie"
                        )
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

struct HowItWorksRow: View {
    let number: Int
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.green.opacity(0.2))
                    .frame(width: 44, height: 44)

                Text("\(number)")
                    .font(.hostGrotesk(.headline, weight: .semibold))
                    .foregroundStyle(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(.green)
                    Text(title)
                        .font(.subheadline.bold())
                }

                Text(description)
                    .font(.hostGrotesk(.caption))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    RallyView()
}
