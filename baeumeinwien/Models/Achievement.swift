import Foundation
import SwiftUI

enum AchievementCategory: String, Codable, CaseIterable {
    case species = "Species"
    case explorer = "Explorer"
    case rally = "Rally"
    case social = "Social"

    var icon: String {
        switch self {
        case .species: return "leaf.fill"
        case .explorer: return "figure.walk"
        case .rally: return "person.3.fill"
        case .social: return "heart.fill"
        }
    }
}

struct Achievement: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let description: String
    let category: AchievementCategory
    let iconName: String
    var isUnlocked: Bool
    var unlockedAt: Date?

    static let goldGradient = LinearGradient(
        colors: [Color.yellow, Color.orange, Color.yellow.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let lockedGradient = LinearGradient(
        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.5)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Achievement {
    static let allAchievements: [Achievement] = [

        Achievement(id: "first_tree", title: "Erster Baum", description: "Entdecke deinen ersten Baum", category: .species, iconName: "leaf.fill", isUnlocked: false),
        Achievement(id: "linde_lover", title: "Lindenliebhaber", description: "Entdecke 10 Linden", category: .species, iconName: "leaf.circle.fill", isUnlocked: false),
        Achievement(id: "kastanie_king", title: "Kastanienkönig", description: "Entdecke 10 Kastanien", category: .species, iconName: "star.circle.fill", isUnlocked: false),
        Achievement(id: "ahorn_ace", title: "Ahorn-Ass", description: "Entdecke 10 Ahornbäume", category: .species, iconName: "leaf.fill", isUnlocked: false),
        Achievement(id: "eiche_expert", title: "Eichen-Experte", description: "Entdecke 10 Eichen", category: .species, iconName: "tree.fill", isUnlocked: false),
        Achievement(id: "species_10", title: "Artenkenner", description: "Entdecke 10 verschiedene Arten", category: .species, iconName: "sparkles", isUnlocked: false),
        Achievement(id: "species_25", title: "Botaniker", description: "Entdecke 25 verschiedene Arten", category: .species, iconName: "graduationcap.fill", isUnlocked: false),
        Achievement(id: "species_50", title: "Dendrologe", description: "Entdecke 50 verschiedene Arten", category: .species, iconName: "crown.fill", isUnlocked: false),

        Achievement(id: "first_mission", title: "Erste Mission", description: "Schließe deine erste Mission ab", category: .explorer, iconName: "flag.fill", isUnlocked: false),
        Achievement(id: "explorer_5", title: "Entdecker", description: "Schließe 5 Explorer-Sessions ab", category: .explorer, iconName: "figure.walk", isUnlocked: false),
        Achievement(id: "explorer_25", title: "Wanderer", description: "Schließe 25 Explorer-Sessions ab", category: .explorer, iconName: "figure.hiking", isUnlocked: false),
        Achievement(id: "district_all", title: "Wien-Kenner", description: "Besuche Bäume in allen 23 Bezirken", category: .explorer, iconName: "map.fill", isUnlocked: false),
        Achievement(id: "walker_5km", title: "5km Wanderer", description: "Lege 5km zu Fuß zurück", category: .explorer, iconName: "shoeprints.fill", isUnlocked: false),
        Achievement(id: "walker_50km", title: "Marathoni", description: "Lege 50km zu Fuß zurück", category: .explorer, iconName: "medal.fill", isUnlocked: false),

        Achievement(id: "first_rally", title: "Erste Rallye", description: "Nimm an deiner ersten Rallye teil", category: .rally, iconName: "person.3.fill", isUnlocked: false),
        Achievement(id: "rally_winner", title: "Rallye-Sieger", description: "Gewinne eine Rallye", category: .rally, iconName: "trophy.fill", isUnlocked: false),
        Achievement(id: "rally_host", title: "Rallye-Leiter", description: "Erstelle deine erste Rallye", category: .rally, iconName: "qrcode", isUnlocked: false),
        Achievement(id: "rally_10", title: "Rallye-Veteran", description: "Nimm an 10 Rallyes teil", category: .rally, iconName: "star.fill", isUnlocked: false),

        Achievement(id: "first_favorite", title: "Erster Favorit", description: "Füge deinen ersten Favoriten hinzu", category: .social, iconName: "heart.fill", isUnlocked: false),
        Achievement(id: "favorites_10", title: "Sammler", description: "Speichere 10 Lieblingsbäume", category: .social, iconName: "heart.circle.fill", isUnlocked: false),
        Achievement(id: "photo_10", title: "Fotograf", description: "Mache 10 Baumfotos", category: .social, iconName: "camera.fill", isUnlocked: false),
    ]

    static let preview = Achievement(
        id: "first_tree",
        title: "Erster Baum",
        description: "Entdecke deinen ersten Baum",
        category: .species,
        iconName: "leaf.fill",
        isUnlocked: true,
        unlockedAt: Date()
    )

    static let previewUnlocked: [Achievement] = [
        Achievement(id: "first_tree", title: "Erster Baum", description: "Entdecke deinen ersten Baum", category: .species, iconName: "leaf.fill", isUnlocked: true, unlockedAt: Date().addingTimeInterval(-86400)),
        Achievement(id: "first_mission", title: "Erste Mission", description: "Schließe deine erste Mission ab", category: .explorer, iconName: "flag.fill", isUnlocked: true, unlockedAt: Date().addingTimeInterval(-3600)),
        Achievement(id: "first_favorite", title: "Erster Favorit", description: "Füge deinen ersten Favoriten hinzu", category: .social, iconName: "heart.fill", isUnlocked: true, unlockedAt: Date()),
    ]
}
