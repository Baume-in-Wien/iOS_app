import SwiftUI

enum PetFoodType: String, CaseIterable, Codable, Identifiable {

    case apple = "apple"
    case pear = "pear"
    case cherry = "cherry"
    case plum = "plum"
    case walnut = "walnut"
    case chestnut = "chestnut"
    case acorn = "acorn"
    case hazelnut = "hazelnut"
    case berries = "berries"

    case leaves = "leaves"
    case flowers = "flowers"
    case seeds = "seeds"
    case nectar = "nectar"

    case insects = "insects"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple: return "Apfel"
        case .pear: return "Birne"
        case .cherry: return "Kirsche"
        case .plum: return "Pflaume"
        case .walnut: return "Walnuss"
        case .chestnut: return "Kastanie"
        case .acorn: return "Eichel"
        case .hazelnut: return "Haselnuss"
        case .berries: return "Beeren"
        case .leaves: return "Blätter"
        case .flowers: return "Blüten"
        case .seeds: return "Samen"
        case .nectar: return "Nektar"
        case .insects: return "Insekten"
        }
    }

    var emoji: String {
        switch self {
        case .apple: return "🍎"
        case .pear: return "🍐"
        case .cherry: return "🍒"
        case .plum: return "🫐"
        case .walnut: return "🥜"
        case .chestnut: return "🌰"
        case .acorn: return "🌰"
        case .hazelnut: return "🌰"
        case .berries: return "🫐"
        case .leaves: return "🍂"
        case .flowers: return "🌸"
        case .seeds: return "🌱"
        case .nectar: return "🍯"
        case .insects: return "🐛"
        }
    }

    var color: Color {
        switch self {
        case .apple: return .red
        case .pear: return .green
        case .cherry: return .red
        case .plum: return .purple
        case .walnut, .chestnut, .acorn, .hazelnut: return .brown
        case .berries: return .purple
        case .leaves: return .orange
        case .flowers: return .pink
        case .seeds: return .green
        case .nectar: return .yellow
        case .insects: return .green
        }
    }

    var nutritionValue: Double {
        switch self {
        case .apple, .pear: return 0.25
        case .cherry, .plum, .berries: return 0.15
        case .walnut, .chestnut, .acorn, .hazelnut: return 0.30
        case .leaves, .flowers: return 0.10
        case .seeds: return 0.20
        case .nectar: return 0.20
        case .insects: return 0.25
        }
    }

    var experienceValue: Int {
        switch self {
        case .walnut, .chestnut, .acorn, .hazelnut: return 15
        case .apple, .pear: return 12
        case .cherry, .plum, .berries: return 10
        case .nectar, .insects: return 12
        case .leaves, .flowers, .seeds: return 8
        }
    }
}

struct TreeFoodMapping {

    static func foodTypes(for treeName: String) -> [PetFoodType] {
        let lowerName = treeName.lowercased()

        if lowerName.contains("apfel") {
            return [.apple, .leaves]
        }
        if lowerName.contains("birne") || lowerName.contains("birn") {
            return [.pear, .leaves]
        }
        if lowerName.contains("kirsch") {
            return [.cherry, .flowers]
        }
        if lowerName.contains("pflaume") || lowerName.contains("zwetschge") {
            return [.plum, .leaves]
        }

        if lowerName.contains("walnuss") || lowerName.contains("nussbaum") {
            return [.walnut, .leaves]
        }
        if lowerName.contains("kastanie") || lowerName.contains("rosskastanie") {
            return [.chestnut, .flowers]
        }
        if lowerName.contains("eiche") {
            return [.acorn, .leaves]
        }
        if lowerName.contains("hasel") {
            return [.hazelnut, .leaves]
        }

        if lowerName.contains("linde") {
            return [.nectar, .flowers, .leaves]
        }
        if lowerName.contains("ahorn") {
            return [.seeds, .leaves]
        }
        if lowerName.contains("holunder") {
            return [.berries, .flowers]
        }
        if lowerName.contains("vogelbeere") || lowerName.contains("eberesche") {
            return [.berries]
        }

        if lowerName.contains("fichte") || lowerName.contains("tanne") || lowerName.contains("kiefer") {
            return [.seeds]
        }

        if lowerName.contains("buche") || lowerName.contains("birke") {
            return [.leaves, .seeds]
        }

        return [.leaves]
    }

    static func doesPetLike(food: PetFoodType, species: PetSpecies) -> Bool {
        switch species {
        case .squirrel:

            return [.walnut, .chestnut, .acorn, .hazelnut, .seeds].contains(food)
        case .hedgehog:

            return [.insects, .apple, .berries, .leaves].contains(food)
        case .owl:

            return [.insects].contains(food)
        case .robin:

            return [.berries, .cherry, .insects, .seeds].contains(food)
        case .butterfly:

            return [.nectar, .flowers].contains(food)
        case .ladybug:

            return [.insects, .leaves, .flowers].contains(food)
        }
    }
}

struct FoodInventory: Codable {
    var items: [String: Int] = [:]

    mutating func add(_ food: PetFoodType, amount: Int = 1) {
        items[food.rawValue, default: 0] += amount
    }

    mutating func remove(_ food: PetFoodType, amount: Int = 1) -> Bool {
        guard let current = items[food.rawValue], current >= amount else {
            return false
        }
        items[food.rawValue] = current - amount
        if items[food.rawValue] == 0 {
            items.removeValue(forKey: food.rawValue)
        }
        return true
    }

    func count(of food: PetFoodType) -> Int {
        items[food.rawValue] ?? 0
    }

    var totalCount: Int {
        items.values.reduce(0, +)
    }

    var availableFood: [(type: PetFoodType, count: Int)] {
        items.compactMap { key, value in
            guard let type = PetFoodType(rawValue: key), value > 0 else { return nil }
            return (type, value)
        }.sorted { $0.count > $1.count }
    }
}
