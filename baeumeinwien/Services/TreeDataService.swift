import Foundation
import CoreData
import MapKit

@MainActor
final class TreeDataService {
    static let shared = TreeDataService()

    private let cdnURL = URL(string: "https://pub-5061dbde1e5d428583b6722a65924e3c.r2.dev/BAUMKATOGD.json")!
    private let localFileName = "BAUMKATOGD.json"

    private var isImporting = false

    func ensureDataLoaded() async throws {
        let context = PersistenceController.shared.container.newBackgroundContext()

        let count = try await context.perform {
            let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "TreeEntity")
            return try context.count(for: request)
        }

        if count > 0 {
            print("CoreData already has \(count) trees.")
            return
        }

        if isImporting { return }
        isImporting = true

        print("Starting import...")

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(localFileName)

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            print("Downloading JSON...")
            let (data, _) = try await URLSession.shared.data(from: cdnURL)
            try data.write(to: fileURL)
            print("Download complete.")
        }

        let data = try Data(contentsOf: fileURL)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]] else {
            throw WFSError.parseError
        }

        print("Parsing \(features.count) features...")

        var batchInput: [[String: Any]] = []

        for feature in features {
            guard let properties = feature["properties"] as? [String: Any],
                  let geometry = feature["geometry"] as? [String: Any],
                  let coordinates = geometry["coordinates"] as? [Double],
                  coordinates.count >= 2 else { continue }

            let id = properties["OBJECTID"] as? Int ?? Int.random(in: 1...9999999)
            let fullSpecies = properties["GATTUNG_ART"] as? String ?? "Unbekannt"

            var speciesGerman = fullSpecies
            var speciesLatin = ""

            if let startParen = fullSpecies.firstIndex(of: "("),
               let endParen = fullSpecies.lastIndex(of: ")") {
                speciesLatin = String(fullSpecies[..<startParen]).trimmingCharacters(in: .whitespaces)
                speciesGerman = String(fullSpecies[fullSpecies.index(after: startParen)..<endParen])
            } else {
                speciesLatin = fullSpecies
            }

            let streetName = properties["OBJEKT_STRASSE"] as? String
            let district = properties["BEZIRK"] as? Int
            let height = (properties["BAUMHOEHE"] as? NSNumber)?.doubleValue
            let crownDiameter = (properties["KRONENDURCHMESSER"] as? NSNumber)?.doubleValue
            let trunkCircumference = (properties["STAMMUMFANG"] as? NSNumber)?.doubleValue
            let yearPlanted = properties["PFLANZJAHR"] as? Int

            let treeDict: [String: Any] = [
                "id": "BAUM_\(id)",
                "speciesGerman": speciesGerman,
                "speciesLatin": speciesLatin,
                "streetName": streetName ?? "",
                "district": Int16(district ?? 0),
                "height": height ?? 0.0,
                "crownDiameter": crownDiameter ?? 0.0,
                "trunkCircumference": trunkCircumference ?? 0.0,
                "yearPlanted": Int16(yearPlanted ?? 0),
                "latitude": coordinates[1],
                "longitude": coordinates[0]
            ]

            batchInput.append(treeDict)
        }

        print("Inserting \(batchInput.count) trees into CoreData...")

        let batchSize = 5000
        let total = batchInput.count

        for i in stride(from: 0, to: total, by: batchSize) {
            let end = min(i + batchSize, total)
            let chunk = Array(batchInput[i..<end])

            try await context.perform {
                let batchInsert = NSBatchInsertRequest(entityName: "TreeEntity", objects: chunk)
                try context.execute(batchInsert)
            }
            print("Inserted \(end)/\(total)")
        }

        print("Import finished.")
        isImporting = false
    }

    func fetchTrees(in region: MKCoordinateRegion) async throws -> [Tree] {
        let context = PersistenceController.shared.container.newBackgroundContext()

        let minLat = region.center.latitude - region.span.latitudeDelta / 2
        let maxLat = region.center.latitude + region.span.latitudeDelta / 2
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2

        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "TreeEntity")
            request.predicate = NSPredicate(
                format: "latitude >= %f AND latitude <= %f AND longitude >= %f AND longitude <= %f",
                minLat, maxLat, minLon, maxLon
            )

            request.fetchLimit = 2000

            let results = try context.fetch(request)

            return results.map { entity in
                Tree(
                    id: entity.value(forKey: "id") as? String ?? "",
                    speciesGerman: entity.value(forKey: "speciesGerman") as? String ?? "",
                    speciesLatin: entity.value(forKey: "speciesLatin") as? String ?? "",
                    streetName: entity.value(forKey: "streetName") as? String,
                    district: (entity.value(forKey: "district") as? Int16).map { Int($0) },
                    height: entity.value(forKey: "height") as? Double,
                    crownDiameter: entity.value(forKey: "crownDiameter") as? Double,
                    trunkCircumference: entity.value(forKey: "trunkCircumference") as? Double,
                    yearPlanted: (entity.value(forKey: "yearPlanted") as? Int16).map { Int($0) },
                    latitude: entity.value(forKey: "latitude") as? Double ?? 0.0,
                    longitude: entity.value(forKey: "longitude") as? Double ?? 0.0
                )
            }
        }
    }

    func fetchTrees(around location: CLLocationCoordinate2D, radius: Double) async throws -> [Tree] {
        let context = PersistenceController.shared.container.newBackgroundContext()

        let latDelta = radius / 111320.0
        let lonDelta = radius / (111320.0 * cos(location.latitude * .pi / 180))

        let minLat = location.latitude - latDelta
        let maxLat = location.latitude + latDelta
        let minLon = location.longitude - lonDelta
        let maxLon = location.longitude + lonDelta

        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "TreeEntity")
            request.predicate = NSPredicate(
                format: "latitude >= %f AND latitude <= %f AND longitude >= %f AND longitude <= %f",
                minLat, maxLat, minLon, maxLon
            )
            request.fetchLimit = 2000

            let results = try context.fetch(request)

            return results.compactMap { entity -> Tree? in
                let lat = entity.value(forKey: "latitude") as? Double ?? 0.0
                let lon = entity.value(forKey: "longitude") as? Double ?? 0.0

                let treeLoc = CLLocation(latitude: lat, longitude: lon)
                let centerLoc = CLLocation(latitude: location.latitude, longitude: location.longitude)
                if treeLoc.distance(from: centerLoc) > radius { return nil }

                return Tree(
                    id: entity.value(forKey: "id") as? String ?? "",
                    speciesGerman: entity.value(forKey: "speciesGerman") as? String ?? "",
                    speciesLatin: entity.value(forKey: "speciesLatin") as? String ?? "",
                    streetName: entity.value(forKey: "streetName") as? String,
                    district: (entity.value(forKey: "district") as? Int16).map { Int($0) },
                    height: entity.value(forKey: "height") as? Double,
                    crownDiameter: entity.value(forKey: "crownDiameter") as? Double,
                    trunkCircumference: entity.value(forKey: "trunkCircumference") as? Double,
                    yearPlanted: (entity.value(forKey: "yearPlanted") as? Int16).map { Int($0) },
                    latitude: lat,
                    longitude: lon
                )
            }
        }
    }

    func searchTrees(query: String) async throws -> [Tree] {
        let context = PersistenceController.shared.container.newBackgroundContext()

        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "TreeEntity")
            request.predicate = NSPredicate(
                format: "speciesGerman CONTAINS[cd] %@ OR streetName CONTAINS[cd] %@",
                query, query
            )
            request.fetchLimit = 100

            let results = try context.fetch(request)

            return results.map { entity in
                Tree(
                    id: entity.value(forKey: "id") as? String ?? "",
                    speciesGerman: entity.value(forKey: "speciesGerman") as? String ?? "",
                    speciesLatin: entity.value(forKey: "speciesLatin") as? String ?? "",
                    streetName: entity.value(forKey: "streetName") as? String,
                    district: (entity.value(forKey: "district") as? Int16).map { Int($0) },
                    height: entity.value(forKey: "height") as? Double,
                    crownDiameter: entity.value(forKey: "crownDiameter") as? Double,
                    trunkCircumference: entity.value(forKey: "trunkCircumference") as? Double,
                    yearPlanted: (entity.value(forKey: "yearPlanted") as? Int16).map { Int($0) },
                    latitude: entity.value(forKey: "latitude") as? Double ?? 0.0,
                    longitude: entity.value(forKey: "longitude") as? Double ?? 0.0
                )
            }
        }
    }
}
