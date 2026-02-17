import SwiftUI
import MapKit

struct TreeSearchView: View {
    @State private var appState = AppState.shared
    @State private var searchText = ""
    @State private var searchResults: [Tree] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.hostGrotesk(.body, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("Baumart oder Straße suchen...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
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
                .padding()

                if searchText.isEmpty {
                    recentSearchesSection
                } else if searchResults.isEmpty && !isSearching {
                    emptyResultsView
                } else {
                    searchResultsList
                }

                Spacer()
            }
            .navigationTitle("Suche")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            performDebouncedSearch(query: newValue)
        }
    }

    private var recentSearchesSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !appState.recentSearches.isEmpty {
                    GlassSectionHeader("Letzte Suchen", icon: "clock.arrow.circlepath")
                        .padding(.horizontal)

                    ForEach(appState.recentSearches, id: \.self) { search in
                        Button {
                            searchText = search
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.secondary.opacity(0.1))
                                        .frame(width: 36, height: 36)

                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.hostGrotesk())
                                        .foregroundStyle(.secondary)
                                }

                                Text(search)
                                    .font(.hostGrotesk())
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.hostGrotesk(.caption))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 0.5
                                    )
                            )
                        }
                        .buttonStyle(GlassPressStyle())
                        .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 16) {
                        Spacer()

                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 80, height: 80)

                            Image(systemName: "magnifyingglass")
                                .font(.hostGrotesk(.largeTitle))
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 8) {
                            Text("Suche starten")
                                .font(.hostGrotesk(.headline, weight: .semibold))

                            Text("Suche nach Baumarten wie \"Linde\" oder Straßen wie \"Ringstraße\"")
                                .font(.hostGrotesk(.subheadline))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }

                        Spacer()
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private var emptyResultsView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)

                Image(systemName: "tree")
                    .font(.hostGrotesk(.largeTitle))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                Text("Keine Ergebnisse")
                    .font(.hostGrotesk(.headline, weight: .semibold))

                Text("Keine Bäume für \"\(searchText)\" gefunden")
                    .font(.hostGrotesk(.subheadline))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var searchResultsList: some View {
        List(searchResults) { tree in
            Button {
                selectTree(tree)
            } label: {
                HStack(spacing: 14) {

                    ZStack {
                        Circle()
                            .fill(Color(tree.speciesColor).opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: tree.speciesIcon)
                            .font(.hostGrotesk(.title3))
                            .foregroundStyle(Color(tree.speciesColor))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(tree.speciesGerman)
                            .font(.hostGrotesk(.headline, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(tree.speciesLatin)
                            .font(.hostGrotesk(.caption))
                            .foregroundStyle(.secondary)
                            .italic()

                        if let street = tree.streetName {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin")
                                    .font(.hostGrotesk(.caption2))
                                Text(street)
                                    .font(.hostGrotesk(.caption))
                            }
                            .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func performDebouncedSearch(query: String) {
        searchTask?.cancel()

        guard !query.isEmpty else {
            searchResults = []
            return
        }

        searchTask = Task {

            try? await Task.sleep(nanoseconds: 500_000_000)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                isSearching = true
            }

            do {
                let results = try await WFSService.shared.searchTrees(query: query)

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                }
            }
        }
    }

    private func selectTree(_ tree: Tree) {
        appState.addRecentSearch(searchText)

        appState.highlightedTreeID = tree.id

        appState.mapRegion = MKCoordinateRegion(
            center: tree.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        )

        appState.selectedTree = tree
        dismiss()
    }
}

#Preview {
    TreeSearchView()
}
