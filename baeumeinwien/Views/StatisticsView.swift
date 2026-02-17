import SwiftUI
import Charts

struct StatisticsView: View {
    @State private var appState = AppState.shared
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                VStack(alignment: .leading, spacing: 4) {
                    Text("STATISTIK")
                        .font(.hostGrotesk(.largeTitle))
                        .fontWeight(.black)
                    Text("Wiener Baumkataster")
                        .font(.hostGrotesk(.subheadline))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Picker("Kategorie", selection: $selectedTab) {
                    Text("Übersicht").tag(0)
                    Text("Bezirke").tag(1)
                    Text("Arten").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch selectedTab {
                case 0:
                    overviewSection
                case 1:
                    districtsSection
                case 2:
                    speciesSection
                default:
                    EmptyView()
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Statistik")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var overviewSection: some View {
        VStack(spacing: 16) {

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatisticsCardItem(title: "Bäume", value: "~500.000", icon: "tree.fill", color: .green)
                StatisticsCardItem(title: "Arten", value: "~700", icon: "leaf.fill", color: .mint)
                StatisticsCardItem(title: "Bezirke", value: "23", icon: "map.fill", color: .blue)
                StatisticsCardItem(title: "Ältester", value: "~300 Jahre", icon: "clock.fill", color: .orange)
            }
            .padding(.horizontal)

            GroupBox("Deine Statistik") {
                VStack(spacing: 12) {
                    HStack {
                        Label("Entdeckte Arten", systemImage: "leaf.fill")
                        Spacer()
                        Text("\(appState.uniqueSpeciesDiscovered.count)")
                            .fontWeight(.bold)
                    }

                    HStack {
                        Label("Entdeckte Bäume", systemImage: "tree.fill")
                        Spacer()
                        Text("\(appState.totalTreesDiscovered)")
                            .fontWeight(.bold)
                    }

                    HStack {
                        Label("Zurückgelegte Strecke", systemImage: "figure.walk")
                        Spacer()
                        Text(String(format: "%.1f km", appState.totalDistanceWalked / 1000))
                            .fontWeight(.bold)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var districtsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top 10 Bezirke")
                .font(.hostGrotesk(.headline, weight: .semibold))
                .padding(.horizontal)

            ForEach(topDistricts, id: \.name) { district in
                DistrictRow(district: district)
            }
            .padding(.horizontal)
        }
    }

    private var speciesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Häufigste Arten")
                .font(.hostGrotesk(.headline, weight: .semibold))
                .padding(.horizontal)

            ForEach(topSpecies, id: \.name) { species in
                SpeciesRow(species: species)
            }
            .padding(.horizontal)
        }
    }

    private var topDistricts: [DistrictData] {
        [
            DistrictData(name: "22. Donaustadt", count: 51_780, percentage: 10.3),
            DistrictData(name: "21. Floridsdorf", count: 43_430, percentage: 8.6),
            DistrictData(name: "10. Favoriten", count: 38_900, percentage: 7.7),
            DistrictData(name: "23. Liesing", count: 35_250, percentage: 7.0),
            DistrictData(name: "2. Leopoldstadt", count: 29_100, percentage: 5.8),
            DistrictData(name: "19. Döbling", count: 27_800, percentage: 5.5),
            DistrictData(name: "13. Hietzing", count: 26_900, percentage: 5.3),
            DistrictData(name: "14. Penzing", count: 24_600, percentage: 4.9),
            DistrictData(name: "3. Landstraße", count: 22_100, percentage: 4.4),
            DistrictData(name: "11. Simmering", count: 21_400, percentage: 4.2)
        ]
    }

    private var topSpecies: [SpeciesData] {
        [
            SpeciesData(name: "Spitz-Ahorn", latinName: "Acer platanoides", count: 52_400),
            SpeciesData(name: "Winter-Linde", latinName: "Tilia cordata", count: 38_900),
            SpeciesData(name: "Berg-Ahorn", latinName: "Acer pseudoplatanus", count: 31_200),
            SpeciesData(name: "Gemeine Esche", latinName: "Fraxinus excelsior", count: 28_700),
            SpeciesData(name: "Rosskastanie", latinName: "Aesculus hippocastanum", count: 24_100),
            SpeciesData(name: "Sommer-Linde", latinName: "Tilia platyphyllos", count: 19_800),
            SpeciesData(name: "Stiel-Eiche", latinName: "Quercus robur", count: 17_300),
            SpeciesData(name: "Rot-Buche", latinName: "Fagus sylvatica", count: 14_900)
        ]
    }
}

struct StatisticsCardItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.hostGrotesk(.title2))
                .fontWeight(.bold)

            Text(title)
                .font(.hostGrotesk(.caption))
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct DistrictRow: View {
    let district: DistrictData

    var body: some View {
        HStack {
            Text(district.name)
                .font(.hostGrotesk(.subheadline))

            Spacer()

            Text("\(district.count)")
                .font(.hostGrotesk(.subheadline))
                .fontWeight(.bold)

            Text("(\(String(format: "%.1f", district.percentage))%)")
                .font(.hostGrotesk(.caption))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct SpeciesRow: View {
    let species: SpeciesData

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(species.name)
                    .font(.hostGrotesk(.subheadline))
                    .fontWeight(.medium)
                Text(species.latinName)
                    .font(.hostGrotesk(.caption))
                    .italic()
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(species.count)")
                .font(.hostGrotesk(.subheadline))
                .fontWeight(.bold)
        }
        .padding(.vertical, 4)
    }
}

struct DistrictData {
    let name: String
    let count: Int
    let percentage: Double
}

struct SpeciesData {
    let name: String
    let latinName: String
    let count: Int
}

#Preview {
    StatisticsView()
}
