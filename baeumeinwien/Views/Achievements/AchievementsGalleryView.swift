import SwiftUI

struct AchievementsGalleryView: View {
    @State private var appState = AppState.shared
    @State private var selectedCategory: AchievementCategory?

    private var filteredAchievements: [Achievement] {
        if let category = selectedCategory {
            return appState.achievements.filter { $0.category == category }
        }
        return appState.achievements
    }

    private var unlockedCount: Int {
        appState.achievements.filter { $0.isUnlocked }.count
    }

    private var uniqueSpeciesCount: Int {
        appState.uniqueSpeciesDiscovered.count
    }

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

            ScrollView {
                VStack(spacing: 20) {

                    statsCard

                    categoryFilter

                    achievementsGrid
                }
                .padding()
            }
        }
        .navigationTitle("Erfolge")
        .navigationBarTitleDisplayMode(.large)
    }

    private var statsCard: some View {
        GlassCard(elevation: .medium) {
            HStack(spacing: 20) {

                ZStack {

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.yellow.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 80, height: 80)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.4), .clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                        )
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .orange.opacity(0.4), radius: 10, y: 5)

                    Image(systemName: "trophy.fill")
                        .font(.hostGrotesk(.title))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(unlockedCount)/\(appState.achievements.count) Erfolge")
                        .font(.hostGrotesk(.headline, weight: .semibold))

                    Text("\(uniqueSpeciesCount) Arten entdeckt")
                        .font(.hostGrotesk(.subheadline))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ZStack {

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.secondary.opacity(0.15), .secondary.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 8
                        )

                    Circle()
                        .trim(from: 0, to: Double(unlockedCount) / Double(max(appState.achievements.count, 1)))
                        .stroke(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .shadow(color: .green.opacity(0.3), radius: 4, y: 2)

                    Text("\(Int(Double(unlockedCount) / Double(max(appState.achievements.count, 1)) * 100))%")
                        .font(.hostGrotesk(.caption))
                        .fontWeight(.bold)
                }
                .frame(width: 56, height: 56)
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                GlassChip(
                    title: "Alle",
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedCategory = nil
                    }
                }

                ForEach(AchievementCategory.allCases, id: \.self) { category in
                    GlassChip(
                        title: category.rawValue,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
    }

    private var achievementsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(filteredAchievements) { achievement in
                AchievementCard(achievement: achievement)
            }
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    @State private var showShimmer = false

    var body: some View {
        VStack(spacing: 14) {

            ZStack {

                if achievement.isUnlocked {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.yellow.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 45
                            )
                        )
                        .frame(width: 70, height: 70)
                }

                Circle()
                    .fill(achievement.isUnlocked ? Achievement.goldGradient : Achievement.lockedGradient)
                    .frame(width: 60, height: 60)
                    .overlay(

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(achievement.isUnlocked ? 0.4 : 0.2), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                achievement.isUnlocked
                                    ? LinearGradient(colors: [.white.opacity(0.5), .orange.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: achievement.isUnlocked ? .orange.opacity(0.4) : .black.opacity(0.1),
                        radius: achievement.isUnlocked ? 10 : 5,
                        y: achievement.isUnlocked ? 5 : 2
                    )

                Image(systemName: achievement.iconName)
                    .font(.hostGrotesk(.title2))
                    .foregroundStyle(achievement.isUnlocked ? .white : .gray)
            }
            .overlay {
                if achievement.isUnlocked && showShimmer {
                    ShimmerView()
                        .clipShape(Circle())
                        .frame(width: 60, height: 60)
                }
            }

            VStack(spacing: 6) {
                Text(achievement.title)
                    .font(.hostGrotesk(.subheadline))
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)

                Text(achievement.description)
                    .font(.hostGrotesk(.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            if let date = achievement.unlockedAt {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.hostGrotesk(.caption2))
                        .foregroundStyle(.green)
                    Text(date, style: .date)
                        .font(.hostGrotesk(.caption2))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .background(
            achievement.isUnlocked
                ? AnyShapeStyle(
                    LinearGradient(
                        colors: [.yellow.opacity(0.08), .orange.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                : AnyShapeStyle(.ultraThinMaterial),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    achievement.isUnlocked
                        ? LinearGradient(colors: [.yellow.opacity(0.4), .orange.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.5
                )
        )
        .shadow(
            color: achievement.isUnlocked ? .orange.opacity(0.15) : .black.opacity(0.05),
            radius: achievement.isUnlocked ? 15 : 8,
            y: achievement.isUnlocked ? 8 : 4
        )
        .opacity(achievement.isUnlocked ? 1 : 0.7)
        .onAppear {
            if achievement.isUnlocked {

                if let unlocked = achievement.unlockedAt,
                   Date().timeIntervalSince(unlocked) < 5 {
                    showShimmer = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showShimmer = false
                    }
                }
            }
        }
    }
}

struct ShimmerView: View {
    @State private var animating = false

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    .white.opacity(0),
                    .white.opacity(0.6),
                    .white.opacity(0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width * 2)
            .offset(x: animating ? geometry.size.width : -geometry.size.width)
            .animation(
                .linear(duration: 1)
                .repeatForever(autoreverses: false),
                value: animating
            )
        }
        .onAppear {
            animating = true
        }
    }
}

#Preview {
    AchievementsGalleryView()
}
