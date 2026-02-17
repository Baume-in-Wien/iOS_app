import SwiftUI
import MapKit
import CoreLocation

struct TreeDetailSheet: View {
    let tree: Tree
    @State private var isFavorite: Bool = false
    @State private var showShareSheet = false
    @State private var favoriteScale: CGFloat = 1.0
    @State private var wikiSummary: WikipediaSummary?
    @State private var isLoadingWiki = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                headerSection

                if let summary = wikiSummary {
                    wikiSection(summary)
                } else if isLoadingWiki {
                    ProgressView()
                        .padding()
                }

                statsGrid

                locationSection

                miniMapSection

                actionButtons
            }
            .padding()
            .padding(.bottom, 20)
        }
        .onAppear {
            isFavorite = PersistenceController.shared.isFavorite(tree)
            AppState.shared.discoverTree(tree)
            loadWikipediaInfo()
        }
    }

    private func loadWikipediaInfo() {
        isLoadingWiki = true
        Task {
            if let summary = try? await WikipediaService.shared.fetchSummary(for: tree.speciesGerman) {
                await MainActor.run {
                    self.wikiSummary = summary
                    self.isLoadingWiki = false
                }
            } else if let summary = try? await WikipediaService.shared.fetchSummary(for: tree.speciesLatin) {
                await MainActor.run {
                    self.wikiSummary = summary
                    self.isLoadingWiki = false
                }
            } else {
                await MainActor.run {
                    self.isLoadingWiki = false
                }
            }
        }
    }

    private func wikiSection(_ summary: WikipediaSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imageUrl = summary.thumbnail?.source, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(ProgressView())
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Über diese Baumart")
                    .font(.hostGrotesk(.headline, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(summary.extract)
                    .font(.hostGrotesk())
                    .fixedSize(horizontal: false, vertical: true)

                if let pageUrl = summary.content_urls?.mobile?.page, let url = URL(string: pageUrl) {
                    Link(destination: url) {
                        HStack(spacing: 4) {
                            Text("Mehr auf Wikipedia")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.hostGrotesk(.caption))
                        .foregroundStyle(.blue)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {

            ZStack {
                Circle()
                    .fill(Color(tree.speciesColor).opacity(0.2))
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(Color(tree.speciesColor))
                    .frame(width: 60, height: 60)

                Image(systemName: tree.speciesIcon)
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text(tree.speciesGerman)
                    .font(.hostGrotesk(.title2))
                    .fontWeight(.bold)

                Text(tree.speciesLatin)
                    .font(.hostGrotesk(.subheadline))
                    .foregroundStyle(.secondary)
                    .italic()
            }

            Button {
                toggleFavorite()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? .yellow : .secondary)
                        .scaleEffect(favoriteScale)

                    Text(isFavorite ? "Favorit" : "Als Favorit speichern")
                        .font(.hostGrotesk(.subheadline))
                }
                .foregroundStyle(isFavorite ? .primary : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isFavorite ? Color.yellow.opacity(0.15) : Color(.systemGray6),
                    in: Capsule()
                )
            }
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if let height = tree.height {
                StatCard(icon: "arrow.up.and.down", title: "Höhe", value: "\(String(format: "%.1f", height)) m", color: .blue)
            }

            if let crown = tree.crownDiameter {
                StatCard(icon: "circle.dashed", title: "Krone", value: "\(String(format: "%.1f", crown)) m", color: .green)
            }

            if let trunk = tree.trunkCircumference {
                StatCard(icon: "circle", title: "Stammumfang", value: "\(Int(trunk)) cm", color: .brown)
            }

            if let year = tree.yearPlanted {
                let age = Calendar.current.component(.year, from: Date()) - year
                StatCard(icon: "calendar", title: "Gepflanzt", value: "\(year) (\(age) J.)", color: .orange)
            }

            if let district = tree.district {
                StatCard(icon: "mappin.circle", title: "Bezirk", value: "\(district). Bezirk", color: .purple)
            }
        }
    }

    private var locationSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: "location.fill")
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                if let street = tree.streetName {
                    Text(street)
                        .font(.hostGrotesk(.subheadline))
                        .fontWeight(.medium)
                }
                Text("\(String(format: "%.5f", tree.latitude)), \(String(format: "%.5f", tree.longitude))")
                    .font(.hostGrotesk(.caption))
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }

            Spacer()

            Button {
                openInMaps()
            } label: {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.hostGrotesk(.title3))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Color(.systemGray6), in: Circle())
            }
        }
        .padding(14)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
    }

    private var miniMapSection: some View {
        Map(initialPosition: .region(
            MKCoordinateRegion(
                center: tree.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
            )
        )) {
            Marker(tree.speciesGerman, coordinate: tree.coordinate)
                .tint(Color(tree.speciesColor))
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .allowsHitTesting(false)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                openInMaps()
            } label: {
                Label("Route", systemImage: "arrow.triangle.turn.up.right.diamond")
                    .font(.hostGrotesk(.subheadline, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
            }

            Button {
                showShareSheet = true
            } label: {
                Label("Teilen", systemImage: "square.and.arrow.up")
                    .font(.hostGrotesk(.subheadline, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [
                "🌳 \(tree.speciesGerman) (\(tree.speciesLatin))",
                tree.streetName ?? "Wien",
                URL(string: "https://maps.apple.com/?ll=\(tree.latitude),\(tree.longitude)")!
            ])
        }
    }

    private func toggleFavorite() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        withAnimation(.spring(duration: 0.15)) {
            favoriteScale = 1.3
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(duration: 0.3)) {
                favoriteScale = 1.0

                if isFavorite {
                    PersistenceController.shared.removeFavorite(tree)
                } else {
                    PersistenceController.shared.addFavorite(tree)
                }
                isFavorite.toggle()
            }
        }
    }

    private func openInMaps() {
        let location = CLLocation(latitude: tree.coordinate.latitude, longitude: tree.coordinate.longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = tree.speciesGerman
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    var color: Color = .accentColor

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.hostGrotesk())
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.hostGrotesk(.caption))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.hostGrotesk(.subheadline))
                    .fontWeight(.semibold)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    TreeDetailSheet(tree: Tree.preview)
        .presentationDetents([.medium, .large])
}
