import SwiftUI

struct MainTabView: View {
    @State private var appState = AppState.shared
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            TreeMapView()
                .tabItem {
                    Label(AppTab.map.rawValue, systemImage: AppTab.map.icon)
                }
                .tag(AppTab.map)

            ExplorerView()
                .tabItem {
                    Label(AppTab.explorer.rawValue, systemImage: AppTab.explorer.icon)
                }
                .tag(AppTab.explorer)

            TreeARView()
                .tabItem {
                    Label(AppTab.ar.rawValue, systemImage: AppTab.ar.icon)
                }
                .tag(AppTab.ar)

            RallyView()
                .tabItem {
                    Label(AppTab.rally.rawValue, systemImage: AppTab.rally.icon)
                }
                .tag(AppTab.rally)

            MoreView()
                .tabItem {
                    Label(AppTab.more.rawValue, systemImage: AppTab.more.icon)
                }
                .tag(AppTab.more)
        }
        .tint(.green)
        .overlay(alignment: .top) {
            if appState.showAchievementUnlock, let achievement = appState.recentlyUnlockedAchievement {
                AchievementUnlockBanner(achievement: achievement)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .onAppear {

                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)

                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            withAnimation(.spring(duration: 0.4)) {
                                appState.showAchievementUnlock = false
                            }
                        }
                    }
            }
        }
        .animation(.spring(duration: 0.5), value: appState.showAchievementUnlock)
    }
}

struct AchievementUnlockBanner: View {
    let achievement: Achievement
    @State private var showConfetti = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.yellow.opacity(0.3), .orange.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .blur(radius: 5)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: achievement.iconName)
                        .font(.hostGrotesk(.title2))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("🎉 Erfolg freigeschaltet!")
                        .font(.hostGrotesk(.caption))
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Text(achievement.title)
                        .font(.hostGrotesk(.headline, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Image(systemName: "trophy.fill")
                    .font(.hostGrotesk(.title2))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.yellow.opacity(0.5), .orange.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .orange.opacity(0.2), radius: 20, y: 10)
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            .padding(.horizontal)
            .padding(.top, 50)
        }
        .overlay {
            if showConfetti {
                ConfettiView()
            }
        }
        .onAppear {
            showConfetti = true
        }
    }
}

#Preview {
    MainTabView()
}
