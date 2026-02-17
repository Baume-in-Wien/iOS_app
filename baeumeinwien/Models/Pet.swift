import Foundation
import SwiftUI

enum PetNeedType: String, CaseIterable, Codable {
    case hunger = "hunger"
    case happiness = "happiness"
    case energy = "energy"
    case cleanliness = "cleanliness"

    var displayName: String {
        switch self {
        case .hunger: return "Hunger"
        case .happiness: return "Glück"
        case .energy: return "Energie"
        case .cleanliness: return "Sauberkeit"
        }
    }

    var emoji: String {
        switch self {
        case .hunger: return "🍎"
        case .happiness: return "💚"
        case .energy: return "⚡"
        case .cleanliness: return "🛁"
        }
    }

    var color: Color {
        switch self {
        case .hunger: return .orange
        case .happiness: return .green
        case .energy: return .yellow
        case .cleanliness: return .blue
        }
    }

    var icon: String {
        switch self {
        case .hunger: return "leaf.fill"
        case .happiness: return "heart.fill"
        case .energy: return "bolt.fill"
        case .cleanliness: return "sparkles"
        }
    }

    var decayIntervalSeconds: TimeInterval {
        switch self {
        case .hunger: return 8 * 3600
        case .happiness: return 12 * 3600
        case .energy: return 24 * 3600
        case .cleanliness: return 16 * 3600
        }
    }

    var increasePerAction: Double {
        switch self {
        case .hunger: return 0.20
        case .happiness: return 0.15
        case .energy: return 0.50
        case .cleanliness: return 0.25
        }
    }
}

enum PetMood: String, Codable {
    case happy = "happy"
    case content = "content"
    case sad = "sad"
    case hungry = "hungry"
    case tired = "tired"
    case sleeping = "sleeping"

    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .content: return "🙂"
        case .sad: return "😢"
        case .hungry: return "😋"
        case .tired: return "😴"
        case .sleeping: return "💤"
        }
    }

    var displayName: String {
        switch self {
        case .happy: return "Glücklich"
        case .content: return "Zufrieden"
        case .sad: return "Traurig"
        case .hungry: return "Hungrig"
        case .tired: return "Müde"
        case .sleeping: return "Schläft"
        }
    }
}

class Pet: Identifiable, Codable {
    var id: UUID
    var species: PetSpecies
    var name: String
    var level: Int
    var experience: Int
    var createdAt: Date

    var hungerLevel: Double
    var happinessLevel: Double
    var energyLevel: Double
    var cleanlinessLevel: Double

    var lastFedAt: Date
    var lastPettedAt: Date
    var lastPlayedAt: Date
    var lastCleanedAt: Date
    var lastDecayUpdate: Date

    var homeTreeId: String?
    var homeTreeName: String?

    var unlockedAccessoryRawValues: [String]
    var equippedAccessoryRawValue: String

    var unlockedAccessories: [PetAccessory] {
        get { unlockedAccessoryRawValues.compactMap { PetAccessory(rawValue: $0) } }
        set { unlockedAccessoryRawValues = newValue.map { $0.rawValue } }
    }

    var equippedAccessory: PetAccessory {
        get { PetAccessory(rawValue: equippedAccessoryRawValue) ?? .none }
        set { equippedAccessoryRawValue = newValue.rawValue }
    }

    init(species: PetSpecies, name: String? = nil) {
        self.id = UUID()
        self.species = species
        self.name = name ?? species.defaultNickname
        self.level = 1
        self.experience = 0
        self.createdAt = Date()

        self.hungerLevel = 1.0
        self.happinessLevel = 1.0
        self.energyLevel = 1.0
        self.cleanlinessLevel = 1.0

        let now = Date()
        self.lastFedAt = now
        self.lastPettedAt = now
        self.lastPlayedAt = now
        self.lastCleanedAt = now
        self.lastDecayUpdate = now

        self.homeTreeId = nil
        self.homeTreeName = nil

        self.unlockedAccessoryRawValues = [PetAccessory.none.rawValue]
        self.equippedAccessoryRawValue = PetAccessory.none.rawValue
    }

    var evolutionStage: PetEvolutionStage {
        PetEvolutionStage.forLevel(level)
    }

    var overallWellbeing: Double {
        (hungerLevel + happinessLevel + energyLevel + cleanlinessLevel) / 4.0
    }

    var mood: PetMood {

        if energyLevel < 0.1 {
            return .sleeping
        }
        if hungerLevel < 0.2 {
            return .hungry
        }
        if energyLevel < 0.3 {
            return .tired
        }
        if overallWellbeing < 0.3 {
            return .sad
        }
        if overallWellbeing > 0.7 {
            return .happy
        }
        return .content
    }

    var needsAttention: Bool {
        hungerLevel < 0.3 || happinessLevel < 0.3 || energyLevel < 0.3 || cleanlinessLevel < 0.3
    }

    var experienceToNextLevel: Int {
        level * 100
    }

    var levelProgress: Double {
        Double(experience) / Double(experienceToNextLevel)
    }

    func needValue(for type: PetNeedType) -> Double {
        switch type {
        case .hunger: return hungerLevel
        case .happiness: return happinessLevel
        case .energy: return energyLevel
        case .cleanliness: return cleanlinessLevel
        }
    }

    func feed(isFavoriteTree: Bool = false) {
        let increase = isFavoriteTree ? PetNeedType.hunger.increasePerAction * 2 : PetNeedType.hunger.increasePerAction
        hungerLevel = min(1.0, hungerLevel + increase)
        lastFedAt = Date()
        addExperience(isFavoriteTree ? 20 : 10)
    }

    func pet() {
        happinessLevel = min(1.0, happinessLevel + PetNeedType.happiness.increasePerAction)
        lastPettedAt = Date()
        addExperience(5)
    }

    func play() {
        energyLevel = min(1.0, energyLevel + PetNeedType.energy.increasePerAction)
        happinessLevel = min(1.0, happinessLevel + 0.1)
        lastPlayedAt = Date()
        addExperience(25)
    }

    func clean() {
        cleanlinessLevel = min(1.0, cleanlinessLevel + PetNeedType.cleanliness.increasePerAction)
        lastCleanedAt = Date()
        addExperience(15)
    }

    func addExperience(_ xp: Int) {
        experience += xp

        while experience >= experienceToNextLevel {
            experience -= experienceToNextLevel
            level += 1

            checkAccessoryUnlocks()
        }
    }

    private func checkAccessoryUnlocks() {
        for accessory in PetAccessory.allCases {
            if accessory.requiredLevel <= level && !unlockedAccessoryRawValues.contains(accessory.rawValue) {
                unlockedAccessoryRawValues.append(accessory.rawValue)
            }
        }
    }

    func updateDecay() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastDecayUpdate)

        for needType in PetNeedType.allCases {
            let decayRate = elapsed / needType.decayIntervalSeconds

            switch needType {
            case .hunger:
                hungerLevel = max(0.0, hungerLevel - decayRate)
            case .happiness:
                happinessLevel = max(0.0, happinessLevel - decayRate)
            case .energy:
                energyLevel = max(0.0, energyLevel - decayRate)
            case .cleanliness:
                cleanlinessLevel = max(0.0, cleanlinessLevel - decayRate)
            }
        }

        lastDecayUpdate = now
    }

    func setHome(treeId: String, treeName: String) {
        homeTreeId = treeId
        homeTreeName = treeName
    }
}

extension Pet {
    static var preview: Pet {
        let pet = Pet(species: .squirrel, name: "Nussi")
        pet.level = 7
        pet.experience = 350
        pet.hungerLevel = 0.8
        pet.happinessLevel = 0.65
        pet.energyLevel = 0.9
        pet.cleanlinessLevel = 0.75
        pet.homeTreeName = "Winterlinde"
        pet.unlockedAccessoryRawValues = [PetAccessory.none.rawValue, PetAccessory.bow.rawValue, PetAccessory.flower.rawValue, PetAccessory.hat.rawValue]
        return pet
    }

    static var sadPet: Pet {
        let pet = Pet(species: .hedgehog, name: "Stachel")
        pet.hungerLevel = 0.15
        pet.happinessLevel = 0.2
        pet.energyLevel = 0.3
        pet.cleanlinessLevel = 0.25
        return pet
    }
}
