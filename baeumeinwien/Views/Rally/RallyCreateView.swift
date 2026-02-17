import SwiftUI
import MapKit
import CoreData

struct RallyCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FavoriteTreeEntity.addedAt, ascending: false)],
        animation: .default
    )
    private var favorites: FetchedResults<FavoriteTreeEntity>

    @State private var locationService = LocationService.shared
    @State private var name = ""
    @State private var description = ""
    @State private var selectedTreeIds: Set<String> = []
    @State private var radiusMeters = 500
    @State private var timeLimitMinutes = 60
    @State private var useTimeLimit = false
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var createdRally: Rally?
    @State private var currentStep = 0

    let onCreate: (Rally) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { step in
                        Circle()
                            .fill(step <= currentStep ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 16)

                if let rally = createdRally {
                    successView(rally: rally)
                } else {
                    switch currentStep {
                    case 0:
                        detailsStep
                    case 1:
                        selectTreesStep
                    default:
                        detailsStep
                    }
                }
            }
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }

                if createdRally == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        if currentStep == 0 {
                            Button("Weiter") {
                                withAnimation {
                                    currentStep = 1
                                }
                            }
                            .disabled(name.isEmpty)
                        } else if currentStep == 1 {
                            Button("Erstellen") {
                                createRally()
                            }
                            .disabled(selectedTreeIds.isEmpty || isCreating)
                        }
                    }
                }
            }
            .disabled(isCreating)
        }
    }

    private var stepTitle: String {
        switch currentStep {
        case 0: return "Rally Details"
        case 1: return "Bäume auswählen"
        default: return "Rally erstellt"
        }
    }

    private var detailsStep: some View {
        Form {
            Section("Rally Details") {
                TextField("Name der Rally", text: $name)
                TextField("Beschreibung (optional)", text: $description, axis: .vertical)
                    .lineLimit(3...5)
            }

            Section("Bereich") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Radius")
                        Spacer()
                        Text("\(radiusMeters)m")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { Double(radiusMeters) },
                        set: { radiusMeters = Int($0) }
                    ), in: 100...5000, step: 100)
                }

                if locationService.currentLocation != nil {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.green)
                        Text("Aktueller Standort wird verwendet")
                            .font(.hostGrotesk(.caption))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        Image(systemName: "location.slash")
                            .foregroundStyle(.orange)
                        Text("Standort wird ermittelt...")
                            .font(.hostGrotesk(.caption))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Zeitlimit (optional)") {
                Toggle("Zeitlimit aktivieren", isOn: $useTimeLimit)

                if useTimeLimit {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Zeit")
                            Spacer()
                            Text("\(timeLimitMinutes) Min")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(timeLimitMinutes) },
                            set: { timeLimitMinutes = Int($0) }
                        ), in: 10...180, step: 10)
                    }
                }
            }

            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .onAppear {
            locationService.startTracking()
        }
    }

    private var selectTreesStep: some View {
        VStack(spacing: 0) {

            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text("Wähle die Bäume aus, die die Teilnehmer finden sollen")
                    .font(.hostGrotesk(.subheadline))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)

            if favorites.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "star.slash")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("Keine Favoriten")
                        .font(.hostGrotesk(.headline, weight: .semibold))
                    Text("Füge zuerst Bäume zu deinen Favoriten hinzu, um sie als Rally-Ziele zu verwenden.")
                        .font(.hostGrotesk(.subheadline))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Spacer()
                }
            } else {
                List {
                    Section {
                        ForEach(favorites, id: \.objectID) { favorite in
                            let treeId = favorite.id ?? ""
                            TreeSelectionRow(
                                favorite: favorite,
                                isSelected: selectedTreeIds.contains(treeId),
                                onToggle: {
                                    toggleTree(treeId)
                                }
                            )
                        }
                    } header: {
                        Text("\(selectedTreeIds.count) von \(favorites.count) ausgewählt")
                    }
                }
            }

            if !selectedTreeIds.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("\(selectedTreeIds.count) Bäume ausgewählt")
                        .font(.hostGrotesk(.headline, weight: .semibold))
                    Spacer()
                    Button("Alle abwählen") {
                        selectedTreeIds.removeAll()
                    }
                    .font(.hostGrotesk(.caption))
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
    }

    private func toggleTree(_ treeId: String) {
        if selectedTreeIds.contains(treeId) {
            selectedTreeIds.remove(treeId)
        } else {
            selectedTreeIds.insert(treeId)
        }
    }

    private func successView(rally: Rally) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Rally erstellt!")
                .font(.largeTitle.bold())

            Text("Teile diesen Code mit deiner Gruppe:")
                .font(.hostGrotesk(.subheadline))
                .foregroundStyle(.secondary)

            Text(rally.code)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
                .background(.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))

            HStack(spacing: 16) {
                Button {
                    UIPasteboard.general.string = rally.code
                } label: {
                    Label("Kopieren", systemImage: "doc.on.doc")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                ShareLink(item: "Tritt meiner Baum-Rally bei! Code: \(rally.code)") {
                    Label("Teilen", systemImage: "square.and.arrow.up")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Spacer()

            Button {
                onCreate(rally)
                dismiss()
            } label: {
                Text("Rally starten")
                    .font(.hostGrotesk(.headline, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private func createRally() {
        Task {
            isCreating = true
            errorMessage = nil

            guard let location = locationService.currentLocation else {
                errorMessage = "Standort konnte nicht ermittelt werden"
                isCreating = false
                return
            }

            let treeIdsToSend = Array(selectedTreeIds)
            print("🌳 [RallyCreateView] Creating rally with \(treeIdsToSend.count) tree IDs: \(treeIdsToSend.prefix(5))")

            let result = await SupabaseService.shared.createRally(
                name: name,
                description: description.isEmpty ? nil : description,
                mode: .student,
                targetSpeciesCount: selectedTreeIds.count,
                timeLimitMinutes: useTimeLimit ? timeLimitMinutes : nil,
                radiusMeters: radiusMeters,
                centerLocation: location.coordinate,
                targetTreeIds: treeIdsToSend
            )

            await MainActor.run {
                isCreating = false

                switch result {
                case .success(let rally):

                    saveRallyTrees(rallyId: rally.id, treeIds: Array(selectedTreeIds))
                    createdRally = rally
                    currentStep = 2
                case .error(let message):
                    errorMessage = message
                }
            }
        }
    }

    private func saveRallyTrees(rallyId: String, treeIds: [String]) {
        UserDefaults.standard.set(treeIds, forKey: "rally_trees_\(rallyId)")
    }
}

struct TreeSelectionRow: View {
    let favorite: FavoriteTreeEntity
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.hostGrotesk(.title2))
                    .foregroundStyle(isSelected ? .green : .secondary)

                Image(systemName: "tree.fill")
                    .font(.hostGrotesk(.title2))
                    .foregroundStyle(.green)
                    .frame(width: 44, height: 44)
                    .background(.green.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(favorite.speciesGerman ?? "Unbekannt")
                        .font(.hostGrotesk(.headline, weight: .semibold))
                        .foregroundStyle(.primary)

                    if let street = favorite.streetName {
                        Text(street)
                            .font(.hostGrotesk(.caption))
                            .foregroundStyle(.secondary)
                    }

                    if let latin = favorite.speciesLatin {
                        Text(latin)
                            .font(.hostGrotesk(.caption))
                            .italic()
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RallyCreateView { _ in }
}
