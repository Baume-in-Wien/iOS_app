import Foundation
import SwiftUI

@MainActor
@Observable
class PetService {
    static let shared = PetService()

    var currentPet: Pet?

    var allPets: [Pet] = []

    var unlockedSpecies: Set<PetSpecies> = [.squirrel]

    var discoveredTreeCount: Int = 0

    var foodInventory: FoodInventory = FoodInventory()

    var lastCollectedFood: [PetFoodType] = []

    private let currentPetKey = "currentPet"
    private let allPetsKey = "allPets"
    private let unlockedSpeciesKey = "unlockedSpecies"
    private let discoveredTreeCountKey = "discoveredTreeCount"
    private let foodInventoryKey = "foodInventory"

    private init() {
        loadData()
        startDecayTimer()
    }

    private func loadData() {
        let defaults = UserDefaults.standard

        if let speciesData = defaults.data(forKey: unlockedSpeciesKey),
           let species = try? JSONDecoder().decode([PetSpecies].self, from: speciesData) {
            unlockedSpecies = Set(species)
        }

        unlockedSpecies.insert(.squirrel)

        discoveredTreeCount = defaults.integer(forKey: discoveredTreeCountKey)

        if let inventoryData = defaults.data(forKey: foodInventoryKey),
           let inventory = try? JSONDecoder().decode(FoodInventory.self, from: inventoryData) {
            foodInventory = inventory
        }

        if let petsData = defaults.data(forKey: allPetsKey),
           let pets = try? JSONDecoder().decode([Pet].self, from: petsData) {
            allPets = pets
        }

        if let petData = defaults.data(forKey: currentPetKey),
           let pet = try? JSONDecoder().decode(Pet.self, from: petData) {
            currentPet = pet

            currentPet?.updateDecay()
        }
    }

    func saveData() {
        let defaults = UserDefaults.standard

        if let data = try? JSONEncoder().encode(Array(unlockedSpecies)) {
            defaults.set(data, forKey: unlockedSpeciesKey)
        }

        defaults.set(discoveredTreeCount, forKey: discoveredTreeCountKey)

        if let data = try? JSONEncoder().encode(foodInventory) {
            defaults.set(data, forKey: foodInventoryKey)
        }

        if let data = try? JSONEncoder().encode(allPets) {
            defaults.set(data, forKey: allPetsKey)
        }

        if let pet = currentPet, let data = try? JSONEncoder().encode(pet) {
            defaults.set(data, forKey: currentPetKey)
        }
    }

    func createPet(species: PetSpecies, name: String? = nil) -> Pet? {
        guard unlockedSpecies.contains(species) else { return nil }

        let pet = Pet(species: species, name: name)
        allPets.append(pet)
        currentPet = pet
        saveData()
        return pet
    }

    func switchToPet(_ pet: Pet) {
        currentPet = pet
        saveData()
    }

    func deletePet(_ pet: Pet) {
        allPets.removeAll { $0.id == pet.id }
        if currentPet?.id == pet.id {
            currentPet = allPets.first
        }
        saveData()
    }

    func renamePet(_ pet: Pet, to newName: String) {
        pet.name = newName
        saveData()
    }

    func onTreeDiscovered(treeName: String, treeId: String) {
        discoveredTreeCount += 1
        checkSpeciesUnlocks()

        let foodTypes = TreeFoodMapping.foodTypes(for: treeName)
        lastCollectedFood = foodTypes

        for food in foodTypes {
            foodInventory.add(food)
        }

        if let pet = currentPet {
            let isFavorite = pet.species.isFavoriteTree(treeName)
            if isFavorite && (pet.homeTreeId == nil || Bool.random()) {
                pet.setHome(treeId: treeId, treeName: treeName)
            }
        }

        saveData()
    }

    func feedPet(with food: PetFoodType) -> Bool {
        guard let pet = currentPet else { return false }
        guard foodInventory.remove(food) else { return false }

        let likesFood = TreeFoodMapping.doesPetLike(food: food, species: pet.species)
        let nutritionMultiplier = likesFood ? 1.5 : 1.0

        pet.hungerLevel = min(1.0, pet.hungerLevel + food.nutritionValue * nutritionMultiplier)
        pet.lastFedAt = Date()

        let xp = likesFood ? food.experienceValue * 2 : food.experienceValue
        pet.addExperience(xp)

        if likesFood {
            pet.happinessLevel = min(1.0, pet.happinessLevel + 0.05)
        }

        saveData()
        return true
    }

    func petAnimal() {
        currentPet?.pet()
        saveData()
    }

    func onRallyCompleted() {
        currentPet?.play()
        saveData()
    }

    func onHerbariumEntryAdded() {
        currentPet?.clean()
        saveData()
    }

    func onMiniGamePlayed(score: Int) {
        guard let pet = currentPet else { return }

        let bonusXP = min(score / 2, 50)
        pet.addExperience(bonusXP)
        pet.happinessLevel = min(1.0, pet.happinessLevel + 0.1)

        saveData()
    }

    func equipAccessory(_ accessory: PetAccessory) {
        guard let pet = currentPet else { return }
        guard pet.unlockedAccessories.contains(accessory) else { return }

        pet.equippedAccessory = accessory
        saveData()
    }

    private func checkSpeciesUnlocks() {
        for species in PetSpecies.allCases {
            if discoveredTreeCount >= species.requiredTreesToUnlock {
                unlockedSpecies.insert(species)
            }
        }
        saveData()
    }

    func isSpeciesUnlocked(_ species: PetSpecies) -> Bool {
        unlockedSpecies.contains(species)
    }

    func progressToNextSpecies() -> (species: PetSpecies?, progress: Double) {
        let locked = PetSpecies.allCases.filter { !unlockedSpecies.contains($0) }
        guard let next = locked.min(by: { $0.requiredTreesToUnlock < $1.requiredTreesToUnlock }) else {
            return (nil, 1.0)
        }

        let progress = Double(discoveredTreeCount) / Double(next.requiredTreesToUnlock)
        return (next, min(progress, 1.0))
    }

    private var decayTimer: Timer?

    private func startDecayTimer() {

        decayTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentPet?.updateDecay()
                self?.saveData()
            }
        }
    }

    func stopDecayTimer() {
        decayTimer?.invalidate()
        decayTimer = nil
    }

    var petNeedsAttention: Bool {
        currentPet?.needsAttention ?? false
    }

    var hasPet: Bool {
        currentPet != nil
    }
}

extension PetService {
    static var preview: PetService {
        let service = PetService.shared
        if service.currentPet == nil {
            _ = service.createPet(species: .squirrel, name: "Nussi")
        }
        return service
    }
}
