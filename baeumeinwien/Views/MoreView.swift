import SwiftUI

struct MoreView: View {
    @State private var authService = AuthService.shared
    @State private var showLogin = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {

                    authSection
                        .padding(.bottom, 8)

                    ForEach(AppTab.moreTabs, id: \.self) { tab in
                        NavigationLink {
                            destinationView(for: tab)
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: tab.icon)
                                    .font(.hostGrotesk(.title2))
                                    .foregroundStyle(.green)
                                    .frame(width: 32)

                                Text(tab.rawValue)
                                    .font(.hostGrotesk(.headline, weight: .semibold))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.hostGrotesk(.subheadline))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(spacing: 8) {
                        Image(systemName: "tree.fill")
                            .font(.hostGrotesk(.largeTitle))
                            .foregroundStyle(.green.opacity(0.6))

                        Text("Bäume in Wien")
                            .font(.hostGrotesk(.headline, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text("Version 1.6")
                            .font(.hostGrotesk(.caption))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 16)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
        }
    }

    private var authSection: some View {
        Group {
            if authService.authState.isAuthenticated {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.green.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "person.fill")
                            .font(.hostGrotesk(.title3))
                            .foregroundStyle(.green)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(authService.authState.displayName ?? "Benutzer")
                            .font(.hostGrotesk(.headline, weight: .semibold))
                        if let email = authService.authState.email {
                            Text(email)
                                .font(.hostGrotesk(.caption))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        authService.signOut()
                    } label: {
                        Text("Abmelden")
                            .font(.hostGrotesk(.subheadline))
                            .foregroundStyle(.red)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else {
                Button {
                    showLogin = true
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(.green.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.hostGrotesk(.title3))
                                .foregroundStyle(.green)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Anmelden")
                                .font(.hostGrotesk(.headline, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("Community-Bäume melden")
                                .font(.hostGrotesk(.caption))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.hostGrotesk(.subheadline))
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for tab: AppTab) -> some View {
        switch tab {
        case .leafScanner:
            LeafScannerView()
        case .favorites:
            FavoritesView()
        case .pet:
            PetHomeView()
        case .achievements:
            AchievementsGalleryView()
        case .statistics:
            StatisticsView()
        case .info:
            InfoView()
        default:
            EmptyView()
        }
    }
}

#Preview {
    MoreView()
}
