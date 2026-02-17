import SwiftUI
import CoreData
import CoreLocation

struct FavoritesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FavoriteTreeEntity.addedAt, ascending: false)],
        animation: .default
    )
    private var favorites: FetchedResults<FavoriteTreeEntity>

    @State private var selectedTree: Tree?
    @Namespace private var namespace

    var body: some View {
        ZStack {

            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGray6).opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Group {
                if favorites.isEmpty {
                    emptyStateView
                } else {
                    favoritesGrid
                }
            }
        }
        .navigationTitle("Favoriten")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedTree) { tree in
            TreeDetailSheet(tree: tree)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(24)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {

            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 20, y: 10)

                Image(systemName: "star.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                Text("Keine Favoriten")
                    .font(.hostGrotesk(.title2))
                    .fontWeight(.bold)

                Text("Tippe auf einen Baum und speichere ihn als Favorit")
                    .font(.hostGrotesk(.subheadline))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }

    private var favoritesGrid: some View {
        ScrollView {

            GlassCard(padding: 16, cornerRadius: 20) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)

                        Image(systemName: "star.fill")
                            .font(.hostGrotesk(.title2))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(favorites.count) Lieblingsbäume")
                            .font(.hostGrotesk(.headline, weight: .semibold))

                        let uniqueSpecies = Set(favorites.compactMap { $0.speciesGerman }).count
                        Text("\(uniqueSpecies) verschiedene Arten")
                            .font(.hostGrotesk(.subheadline))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(favorites) { favorite in
                    FavoriteTreeCard(favorite: favorite) {
                        selectedTree = favorite.tree
                    } onDelete: {
                        deleteFavorite(favorite)
                    }
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
            }
            .padding()
            .animation(.spring(duration: 0.4), value: favorites.count)
        }
    }

    private func deleteFavorite(_ favorite: FavoriteTreeEntity) {
        withAnimation(.spring(duration: 0.3)) {
            viewContext.delete(favorite)
            try? viewContext.save()
        }
    }
}

struct FavoriteTreeCard: View {
    let favorite: FavoriteTreeEntity
    let onTap: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteConfirmation = false
    @State private var isPressed = false

    private var tree: Tree {
        favorite.tree
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {

                ZStack {

                    Circle()
                        .fill(Color(tree.speciesColor).opacity(0.3))
                        .frame(width: 60, height: 60)
                        .blur(radius: 10)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(tree.speciesColor), Color(tree.speciesColor).opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.6), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )

                    Image(systemName: tree.speciesIcon)
                        .font(.hostGrotesk(.title2))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 4) {
                    Text(tree.speciesGerman)
                        .font(.hostGrotesk(.subheadline))
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    if let street = tree.streetName {
                        Text(street)
                            .font(.hostGrotesk(.caption))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if let date = favorite.addedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.hostGrotesk(.caption2))
                        Text(date, style: .date)
                            .font(.hostGrotesk(.caption2))
                    }
                    .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 8)
            .shadow(color: Color(tree.speciesColor).opacity(0.15), radius: 20, x: 0, y: 10)
        }
        .buttonStyle(LiquidGlassButtonStyle())
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Entfernen", systemImage: "trash")
            }

            Button {
                openInMaps()
            } label: {
                Label("In Karten öffnen", systemImage: "map")
            }

            Button {
                shareTree()
            } label: {
                Label("Teilen", systemImage: "square.and.arrow.up")
            }
        }
        .confirmationDialog("Favorit entfernen?", isPresented: $showDeleteConfirmation) {
            Button("Entfernen", role: .destructive) {
                onDelete()
            }
        }
    }

    private func openInMaps() {
        let coordinate = tree.coordinate
        if let url = URL(string: "maps://?ll=\(coordinate.latitude),\(coordinate.longitude)") {
            UIApplication.shared.open(url)
        }
    }

    private func shareTree() {

        let text = "🌳 \(tree.speciesGerman) (\(tree.speciesLatin)) - \(tree.streetName ?? "Wien")"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

struct LiquidGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

extension Tree {
    static func == (lhs: Tree, rhs: Tree) -> Bool {
        lhs.id == rhs.id
    }
}

#Preview {
    FavoritesView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
