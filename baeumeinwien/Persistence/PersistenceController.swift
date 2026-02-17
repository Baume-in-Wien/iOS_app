import CoreData

final class PersistenceController: @unchecked Sendable {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext

        for i in 0..<5 {
            let favorite = FavoriteTreeEntity(context: viewContext)
            favorite.id = "BAUM_\(i)"
            favorite.speciesGerman = ["Winterlinde", "Spitzahorn", "Rosskastanie", "Stieleiche", "Hängebirke"][i]
            favorite.speciesLatin = ["Tilia cordata", "Acer platanoides", "Aesculus hippocastanum", "Quercus robur", "Betula pendula"][i]
            favorite.streetName = "Teststraße \(i)"
            favorite.district = Int16(i + 1)
            favorite.latitude = 48.2082 + Double(i) * 0.001
            favorite.longitude = 16.3738 + Double(i) * 0.001
            favorite.addedAt = Date()
        }

        try? viewContext.save()
        return controller
    }()

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Baumkataster")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func addFavorite(_ tree: Tree) {
        let context = container.viewContext
        let favorite = FavoriteTreeEntity(context: context)
        favorite.id = tree.id
        favorite.speciesGerman = tree.speciesGerman
        favorite.speciesLatin = tree.speciesLatin
        favorite.streetName = tree.streetName
        favorite.district = Int16(tree.district ?? 0)
        favorite.latitude = tree.latitude
        favorite.longitude = tree.longitude
        favorite.height = tree.height ?? 0
        favorite.crownDiameter = tree.crownDiameter ?? 0
        favorite.addedAt = Date()

        save()

        let request: NSFetchRequest<FavoriteTreeEntity> = FavoriteTreeEntity.fetchRequest()
        if let count = try? context.count(for: request) {
            if count == 1 {
                AppState.shared.unlockAchievement("first_favorite")
            } else if count >= 10 {
                AppState.shared.unlockAchievement("favorites_10")
            }
        }
    }

    func removeFavorite(_ tree: Tree) {
        let context = container.viewContext
        let request: NSFetchRequest<FavoriteTreeEntity> = FavoriteTreeEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", tree.id)

        if let favorites = try? context.fetch(request) {
            for favorite in favorites {
                context.delete(favorite)
            }
            save()
        }
    }

    func isFavorite(_ tree: Tree) -> Bool {
        let context = container.viewContext
        let request: NSFetchRequest<FavoriteTreeEntity> = FavoriteTreeEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", tree.id)

        return (try? context.count(for: request)) ?? 0 > 0
    }

    func save() {
        let context = container.viewContext
        if context.hasChanges {
            try? context.save()
        }
    }
}

extension FavoriteTreeEntity {
    var tree: Tree {
        Tree(
            id: id ?? "",
            speciesGerman: speciesGerman ?? "Unbekannt",
            speciesLatin: speciesLatin ?? "",
            streetName: streetName,
            district: Int(district),
            height: height > 0 ? height : nil,
            crownDiameter: crownDiameter > 0 ? crownDiameter : nil,
            trunkCircumference: nil,
            yearPlanted: nil,
            latitude: latitude,
            longitude: longitude
        )
    }
}
