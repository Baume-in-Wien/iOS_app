import CoreData

final class TreeCachePersistence: @unchecked Sendable {
    static let shared = TreeCachePersistence()

    let container: NSPersistentContainer

    init() {

        let model = NSManagedObjectModel()

        let treeEntity = NSEntityDescription()
        treeEntity.name = "CachedTree"
        treeEntity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .stringAttributeType
        idAttr.isOptional = false

        let speciesGermanAttr = NSAttributeDescription()
        speciesGermanAttr.name = "speciesGerman"
        speciesGermanAttr.attributeType = .stringAttributeType

        let speciesLatinAttr = NSAttributeDescription()
        speciesLatinAttr.name = "speciesLatin"
        speciesLatinAttr.attributeType = .stringAttributeType

        let streetNameAttr = NSAttributeDescription()
        streetNameAttr.name = "streetName"
        streetNameAttr.attributeType = .stringAttributeType

        let districtAttr = NSAttributeDescription()
        districtAttr.name = "district"
        districtAttr.attributeType = .integer16AttributeType

        let heightAttr = NSAttributeDescription()
        heightAttr.name = "height"
        heightAttr.attributeType = .doubleAttributeType

        let crownAttr = NSAttributeDescription()
        crownAttr.name = "crownDiameter"
        crownAttr.attributeType = .doubleAttributeType

        let trunkAttr = NSAttributeDescription()
        trunkAttr.name = "trunkCircumference"
        trunkAttr.attributeType = .doubleAttributeType

        let yearAttr = NSAttributeDescription()
        yearAttr.name = "yearPlanted"
        yearAttr.attributeType = .integer16AttributeType

        let latAttr = NSAttributeDescription()
        latAttr.name = "latitude"
        latAttr.attributeType = .doubleAttributeType

        let lonAttr = NSAttributeDescription()
        lonAttr.name = "longitude"
        lonAttr.attributeType = .doubleAttributeType

        treeEntity.properties = [idAttr, speciesGermanAttr, speciesLatinAttr, streetNameAttr, districtAttr, heightAttr, crownAttr, trunkAttr, yearAttr, latAttr, lonAttr]

        let idIndex = NSFetchIndexDescription(name: "byID", elements: [NSFetchIndexElementDescription(property: idAttr, collationType: .binary)])
        let streetIndex = NSFetchIndexDescription(name: "byStreet", elements: [NSFetchIndexElementDescription(property: streetNameAttr, collationType: .binary)])
        let latIndex = NSFetchIndexDescription(name: "byLat", elements: [NSFetchIndexElementDescription(property: latAttr, collationType: .binary)])
        let lonIndex = NSFetchIndexDescription(name: "byLon", elements: [NSFetchIndexElementDescription(property: lonAttr, collationType: .binary)])

        treeEntity.indexes = [idIndex, streetIndex, latIndex, lonIndex]

        model.entities = [treeEntity]

        container = NSPersistentContainer(name: "TreeCache", managedObjectModel: model)

        let description = NSPersistentStoreDescription()
        description.url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("TreeCache.sqlite")
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error = error {
                print("Failed to load TreeCache: \(error)")
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) async {
        await withCheckedContinuation { continuation in
            container.performBackgroundTask { context in
                block(context)
                continuation.resume()
            }
        }
    }
}
