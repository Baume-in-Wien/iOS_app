import SwiftUI

enum PetSpecies: String, CaseIterable, Codable, Identifiable {
    case squirrel = "squirrel"
    case hedgehog = "hedgehog"
    case owl = "owl"
    case robin = "robin"
    case butterfly = "butterfly"
    case ladybug = "ladybug"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .squirrel: return "Eichhörnchen"
        case .hedgehog: return "Igel"
        case .owl: return "Eule"
        case .robin: return "Rotkehlchen"
        case .butterfly: return "Schmetterling"
        case .ladybug: return "Marienkäfer"
        }
    }

    var defaultNickname: String {
        switch self {
        case .squirrel: return "Nussi"
        case .hedgehog: return "Stachel"
        case .owl: return "Eulalia"
        case .robin: return "Piepsi"
        case .butterfly: return "Flattra"
        case .ladybug: return "Glücksi"
        }
    }

    var emoji: String {
        switch self {
        case .squirrel: return "🐿️"
        case .hedgehog: return "🦔"
        case .owl: return "🦉"
        case .robin: return "🐦"
        case .butterfly: return "🦋"
        case .ladybug: return "🐞"
        }
    }

    var systemImage: String {
        switch self {
        case .squirrel: return "hare.fill"
        case .hedgehog: return "tortoise.fill"
        case .owl: return "bird.fill"
        case .robin: return "bird"
        case .butterfly: return "leaf.fill"
        case .ladybug: return "ladybug.fill"
        }
    }

    var color: Color {
        switch self {
        case .squirrel: return .orange
        case .hedgehog: return .brown
        case .owl: return .purple
        case .robin: return .red
        case .butterfly: return .blue
        case .ladybug: return .red
        }
    }

    var favoriteTrees: [String] {
        switch self {
        case .squirrel:
            return ["Eiche", "Kastanie", "Walnuss", "Haselnuss"]
        case .hedgehog:
            return ["Buche", "Ahorn", "Birke", "Linde"]
        case .owl:
            return ["Eiche", "Buche", "Tanne", "Fichte"]
        case .robin:
            return ["Apfel", "Birne", "Kirsche", "Birke"]
        case .butterfly:
            return ["Linde", "Kastanie", "Flieder", "Holunder"]
        case .ladybug:
            return ["Rose", "Apfel", "Kirsche", "Holunder"]
        }
    }

    var description: String {
        switch self {
        case .squirrel:
            return "Das flinke Eichhörnchen liebt Nüsse und klettert gerne auf Bäume. Es sammelt Vorräte für den Winter."
        case .hedgehog:
            return "Der niedliche Igel versteckt sich gerne unter Laubhaufen und ist nachts aktiv."
        case .owl:
            return "Die weise Eule ist nachtaktiv und liebt alte, große Bäume als Schlafplatz."
        case .robin:
            return "Das muntere Rotkehlchen singt wunderschöne Lieder und liebt Obstbäume."
        case .butterfly:
            return "Der bunte Schmetterling flattert von Blüte zu Blüte und liebt blühende Bäume."
        case .ladybug:
            return "Der kleine Glückskäfer bringt Freude und schützt Pflanzen vor Schädlingen."
        }
    }

    var requiredTreesToUnlock: Int {
        switch self {
        case .squirrel: return 0
        case .hedgehog: return 25
        case .owl: return 50
        case .robin: return 100
        case .butterfly: return 150
        case .ladybug: return 200
        }
    }

    var isStarter: Bool {
        self == .squirrel
    }

    func isFavoriteTree(_ treeName: String) -> Bool {
        let lowerName = treeName.lowercased()
        return favoriteTrees.contains { lowerName.contains($0.lowercased()) }
    }
}

enum PetEvolutionStage: Int, Codable, CaseIterable {
    case baby = 1
    case juvenile = 2
    case adult = 3

    var displayName: String {
        switch self {
        case .baby: return "Baby"
        case .juvenile: return "Jungtier"
        case .adult: return "Erwachsen"
        }
    }

    var requiredLevel: Int {
        switch self {
        case .baby: return 1
        case .juvenile: return 5
        case .adult: return 10
        }
    }

    static func forLevel(_ level: Int) -> PetEvolutionStage {
        if level >= 10 {
            return .adult
        } else if level >= 5 {
            return .juvenile
        } else {
            return .baby
        }
    }
}

enum PetAccessory: String, CaseIterable, Codable, Identifiable {
    case none = "none"
    case hat = "hat"
    case bow = "bow"
    case leafCrown = "leafCrown"
    case scarf = "scarf"
    case glasses = "glasses"
    case flower = "flower"
    case star = "star"
    case heart = "heart"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Keines"
        case .hat: return "Hut"
        case .bow: return "Schleife"
        case .leafCrown: return "Blätterkrone"
        case .scarf: return "Schal"
        case .glasses: return "Brille"
        case .flower: return "Blume"
        case .star: return "Stern"
        case .heart: return "Herz"
        }
    }

    var emoji: String {
        switch self {
        case .none: return ""
        case .hat: return "🎩"
        case .bow: return "🎀"
        case .leafCrown: return "🌿"
        case .scarf: return "🧣"
        case .glasses: return "👓"
        case .flower: return "🌸"
        case .star: return "⭐"
        case .heart: return "❤️"
        }
    }

    var requiredLevel: Int {
        switch self {
        case .none: return 0
        case .bow: return 2
        case .flower: return 4
        case .hat: return 6
        case .glasses: return 8
        case .scarf: return 10
        case .leafCrown: return 12
        case .star: return 15
        case .heart: return 20
        }
    }
}
