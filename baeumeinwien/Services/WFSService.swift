import Foundation
import CoreLocation
import CoreData
import MapKit

@MainActor
final class WFSService {
    static let shared = WFSService()

    private let cdnBaseURL = "https://pub-5061dbde1e5d428583b6722a65924e3c.r2.dev"
    private let totalDistricts = 23

    private let loadedDistrictsKey = "loadedDistricts"
    private let loadingModeKey = "loadingMode"

    private var isLoaded = false

    private func cdnURL(forDistrict district: Int) -> URL {
        URL(string: "\(cdnBaseURL)/BAUMKATOGD_\(district).json")!
    }

    private var loadedDistricts: Set<Int> {
        get {
            let array = UserDefaults.standard.array(forKey: loadedDistrictsKey) as? [Int] ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: loadedDistrictsKey)
        }
    }

    var loadingMode: LoadingMode? {
        get {
            guard let raw = UserDefaults.standard.string(forKey: loadingModeKey) else { return nil }
            return LoadingMode(rawValue: raw)
        }
        set {
            UserDefaults.standard.set(newValue?.rawValue, forKey: loadingModeKey)
        }
    }

    var hasChosenLoadingMode: Bool {
        loadingMode != nil
    }

    func loadDataWithProgress() async throws {
        if isLoaded { return }

        let appState = AppState.shared

        var loaded = loadedDistricts

        if loaded.count >= totalDistricts {
            isLoaded = true
            await MainActor.run {
                appState.loadingProgress = 1.0
                appState.loadingMessage = "Bereit!"
            }
            return
        }

        let allDistricts = Set(1...totalDistricts)
        let remainingDistricts = allDistricts.subtracting(loaded).sorted()

        await MainActor.run {
            appState.loadingMessage = "Lade Bezirke..."
            appState.loadingProgress = Double(loaded.count) / Double(totalDistricts)
        }

        for (index, district) in remainingDistricts.enumerated() {
            let overallProgress = min(1.0, Double(loaded.count + index) / Double(totalDistricts))

            await MainActor.run {
                appState.loadingProgress = overallProgress
                appState.loadingMessage = "Lade Bezirk \(district)/\(totalDistricts)..."
            }

            do {
                try await loadDistrict(district)
                loaded.insert(district)
                loadedDistricts = loaded
            } catch {
                print("Failed to load district \(district): \(error)")

            }
        }

        isLoaded = true

        await MainActor.run {
            appState.loadingProgress = 1.0
            appState.loadingMessage = "Fertig!"
        }
    }

    private func loadDistrict(_ district: Int) async throws {
        let url = cdnURL(forDistrict: district)

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw WFSError.serverError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = json["features"] as? [[String: Any]] else {
            throw WFSError.parseError
        }

        print("District \(district): Downloaded \(features.count) trees")

        await importFeaturesToDB(features)
    }

    func resetLoadedDistricts() {
        UserDefaults.standard.removeObject(forKey: loadedDistrictsKey)
        UserDefaults.standard.removeObject(forKey: loadingModeKey)
        isLoaded = false

        let context = TreeCachePersistence.shared.container.newBackgroundContext()
        context.performAndWait {
            let deleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CachedTree")
            let batchDelete = NSBatchDeleteRequest(fetchRequest: deleteRequest)
            _ = try? context.execute(batchDelete)
        }
    }

    func loadDistrictOnDemand(_ district: Int) async {

        guard !loadedDistricts.contains(district) else { return }

        do {
            try await loadDistrict(district)
            var updated = loadedDistricts
            updated.insert(district)
            loadedDistricts = updated
            print("On-demand: Loaded district \(district)")
        } catch {
            print("On-demand: Failed to load district \(district): \(error)")
        }
    }

    func loadDistrictsForCoordinate(_ coordinate: CLLocationCoordinate2D) async {

        var closestDistrict = 1
        var closestDistance = Double.infinity

        for (district, center) in DistrictCoordinates.centers {
            let distance = sqrt(
                pow(coordinate.latitude - center.latitude, 2) +
                pow(coordinate.longitude - center.longitude, 2)
            )
            if distance < closestDistance {
                closestDistance = distance
                closestDistrict = district
            }
        }

        let neighbors = getNeighborDistricts(closestDistrict)
        let districtsToLoad = [closestDistrict] + neighbors.prefix(2)

        for district in districtsToLoad {
            await loadDistrictOnDemand(district)
        }
    }

    private func getNeighborDistricts(_ district: Int) -> [Int] {

        let neighbors: [Int: [Int]] = [
            1: [2, 3, 4, 6, 7, 8, 9],
            2: [1, 3, 20],
            3: [1, 2, 4, 10, 11],
            4: [1, 3, 5, 10],
            5: [4, 6, 10, 12],
            6: [1, 5, 7, 15],
            7: [1, 6, 8, 15, 16],
            8: [1, 7, 9, 16, 17],
            9: [1, 8, 17, 18, 19],
            10: [3, 4, 5, 11, 12, 23],
            11: [3, 10, 23],
            12: [5, 10, 13, 23],
            13: [12, 14, 23],
            14: [13, 15, 16],
            15: [6, 7, 14, 16],
            16: [7, 8, 15, 17],
            17: [8, 9, 16, 18],
            18: [9, 17, 19],
            19: [9, 18, 20, 21],
            20: [2, 19, 21],
            21: [20, 22],
            22: [21],
            23: [10, 11, 12, 13]
        ]
        return neighbors[district] ?? []
    }

    func startBackgroundLoading() {
        Task {
            let allDistricts = Set(1...totalDistricts)
            let remaining = allDistricts.subtracting(loadedDistricts).sorted()

            for district in remaining {
                await loadDistrictOnDemand(district)

                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func importFeaturesToDBWithProgress(_ features: [[String: Any]], appState: AppState) async {
        let startTime = Date()

        await TreeCachePersistence.shared.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            let totalCount = features.count
            var currentIndex = 0
            let batchSize = 5000

            while currentIndex < totalCount {
                let endIndex = min(currentIndex + batchSize, totalCount)
                let batchFeatures = features[currentIndex..<endIndex]

                var batchInput: [[String: Any]] = []
                batchInput.reserveCapacity(batchFeatures.count)

                for feature in batchFeatures {
                    guard let properties = feature["properties"] as? [String: Any],
                          let geometry = feature["geometry"] as? [String: Any],
                          let coordinates = geometry["coordinates"] as? [Double],
                          coordinates.count >= 2 else {
                        continue
                    }

                    let id = properties["OBJECTID"] as? Int ?? 0
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

                    var dict: [String: Any] = [
                        "id": "BAUM_\(id)",
                        "speciesGerman": speciesGerman,
                        "speciesLatin": speciesLatin,
                        "latitude": coordinates[1],
                        "longitude": coordinates[0]
                    ]

                    if let street = properties["OBJEKT_STRASSE"] as? String { dict["streetName"] = street }
                    if let district = properties["BEZIRK"] as? Int { dict["district"] = district }
                    if let height = (properties["BAUMHOEHE"] as? NSNumber)?.doubleValue { dict["height"] = height }
                    if let crown = (properties["KRONENDURCHMESSER"] as? NSNumber)?.doubleValue { dict["crownDiameter"] = crown }
                    if let trunk = (properties["STAMMUMFANG"] as? NSNumber)?.doubleValue { dict["trunkCircumference"] = trunk }
                    if let year = properties["PFLANZJAHR"] as? Int { dict["yearPlanted"] = year }

                    batchInput.append(dict)
                }

                let batchInsert = NSBatchInsertRequest(entityName: "CachedTree", objects: batchInput)
                batchInsert.resultType = .statusOnly

                do {
                    try context.execute(batchInsert)
                } catch {
                    print("Batch insert failed: \(error)")
                }

                currentIndex += batchSize

                let importProgress = Double(currentIndex) / Double(totalCount)
                Task { @MainActor in
                    appState.loadingProgress = 0.6 + (importProgress * 0.4)
                    appState.loadingMessage = "Importiere Bäume... \(min(currentIndex, totalCount)) / \(totalCount)"
                }
            }
        }

        print("Import finished in \(Date().timeIntervalSince(startTime)) seconds.")
    }

    private func ensureLoaded() async throws {
        if isLoaded { return }

        let loaded = loadedDistricts
        if loaded.count >= totalDistricts {
            isLoaded = true
            return
        }

        let allDistricts = Set(1...totalDistricts)
        let remainingDistricts = allDistricts.subtracting(loaded).sorted()

        for district in remainingDistricts {
            do {
                try await loadDistrict(district)
                var updated = loadedDistricts
                updated.insert(district)
                loadedDistricts = updated
            } catch {
                print("Failed to load district \(district): \(error)")
            }
        }

        isLoaded = true
    }

    private func importFeaturesToDB(_ features: [[String: Any]]) async {
        let startTime = Date()

        await TreeCachePersistence.shared.performBackgroundTask { context in
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

            let totalCount = features.count
            var currentIndex = 0
            let batchSize = 5000

            while currentIndex < totalCount {
                let endIndex = min(currentIndex + batchSize, totalCount)
                let batchFeatures = features[currentIndex..<endIndex]

                var batchInput: [[String: Any]] = []
                batchInput.reserveCapacity(batchFeatures.count)

                for feature in batchFeatures {
                    guard let properties = feature["properties"] as? [String: Any],
                          let geometry = feature["geometry"] as? [String: Any],
                          let coordinates = geometry["coordinates"] as? [Double],
                          coordinates.count >= 2 else {
                        continue
                    }

                    let id = properties["OBJECTID"] as? Int ?? 0
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

                    var dict: [String: Any] = [
                        "id": "BAUM_\(id)",
                        "speciesGerman": speciesGerman,
                        "speciesLatin": speciesLatin,
                        "latitude": coordinates[1],
                        "longitude": coordinates[0]
                    ]

                    if let street = properties["OBJEKT_STRASSE"] as? String { dict["streetName"] = street }
                    if let district = properties["BEZIRK"] as? Int { dict["district"] = district }
                    if let height = (properties["BAUMHOEHE"] as? NSNumber)?.doubleValue { dict["height"] = height }
                    if let crown = (properties["KRONENDURCHMESSER"] as? NSNumber)?.doubleValue { dict["crownDiameter"] = crown }
                    if let trunk = (properties["STAMMUMFANG"] as? NSNumber)?.doubleValue { dict["trunkCircumference"] = trunk }
                    if let year = properties["PFLANZJAHR"] as? Int { dict["yearPlanted"] = year }

                    batchInput.append(dict)
                }

                let batchInsert = NSBatchInsertRequest(entityName: "CachedTree", objects: batchInput)
                batchInsert.resultType = .statusOnly

                do {
                    try context.execute(batchInsert)
                } catch {
                    print("Batch insert failed: \(error)")
                }

                currentIndex += batchSize
            }
        }

        print("Import finished in \(Date().timeIntervalSince(startTime)) seconds.")
    }

    func fetchTrees(bbox: String) async throws -> [Tree] {
        try await ensureLoaded()

        let components = bbox.split(separator: ",").compactMap { Double($0) }
        guard components.count == 4 else { return [] }

        let minLon = components[0]
        let minLat = components[1]
        let maxLon = components[2]
        let maxLat = components[3]

        return fetchFromCoreData(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
    }

    func fetchTrees(around location: CLLocationCoordinate2D, radius: Double) async throws -> [Tree] {
        try await ensureLoaded()

        let latDelta = radius / 111320.0
        let lonDelta = radius / (111320.0 * cos(location.latitude * .pi / 180))

        let minLat = location.latitude - latDelta
        let maxLat = location.latitude + latDelta
        let minLon = location.longitude - lonDelta
        let maxLon = location.longitude + lonDelta

        return fetchFromCoreData(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
    }

    private func fetchFromCoreData(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) -> [Tree] {
        let context = TreeCachePersistence.shared.container.newBackgroundContext()
        var result: [Tree] = []

        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CachedTree")

            request.predicate = NSPredicate(
                format: "latitude >= %f AND latitude <= %f AND longitude >= %f AND longitude <= %f",
                minLat, maxLat, minLon, maxLon
            )

            request.fetchLimit = 0

            do {
                let results = try context.fetch(request)
                print("CoreData: Found \(results.count) trees in bounds [\(minLat), \(minLon)] to [\(maxLat), \(maxLon)]")
                result = results.map { obj in
                    Tree(
                        id: obj.value(forKey: "id") as? String ?? "",
                        speciesGerman: obj.value(forKey: "speciesGerman") as? String ?? "",
                        speciesLatin: obj.value(forKey: "speciesLatin") as? String ?? "",
                        streetName: obj.value(forKey: "streetName") as? String,
                        district: obj.value(forKey: "district") as? Int,
                        height: obj.value(forKey: "height") as? Double,
                        crownDiameter: obj.value(forKey: "crownDiameter") as? Double,
                        trunkCircumference: obj.value(forKey: "trunkCircumference") as? Double,
                        yearPlanted: obj.value(forKey: "yearPlanted") as? Int,
                        latitude: obj.value(forKey: "latitude") as? Double ?? 0,
                        longitude: obj.value(forKey: "longitude") as? Double ?? 0
                    )
                }
            } catch {
                print("CoreData fetch error: \(error)")
            }
        }
        return result
    }

    func searchTrees(query: String) async throws -> [Tree] {
        try await ensureLoaded()

        let context = TreeCachePersistence.shared.container.newBackgroundContext()
        var result: [Tree] = []

        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CachedTree")

            request.predicate = NSPredicate(
                format: "speciesGerman CONTAINS[cd] %@ OR streetName CONTAINS[cd] %@",
                query, query
            )
            request.fetchLimit = 100

            do {
                let results = try context.fetch(request)
                result = results.map { obj in
                    Tree(
                        id: obj.value(forKey: "id") as? String ?? "",
                        speciesGerman: obj.value(forKey: "speciesGerman") as? String ?? "",
                        speciesLatin: obj.value(forKey: "speciesLatin") as? String ?? "",
                        streetName: obj.value(forKey: "streetName") as? String,
                        district: obj.value(forKey: "district") as? Int,
                        height: obj.value(forKey: "height") as? Double,
                        crownDiameter: obj.value(forKey: "crownDiameter") as? Double,
                        trunkCircumference: obj.value(forKey: "trunkCircumference") as? Double,
                        yearPlanted: obj.value(forKey: "yearPlanted") as? Int,
                        latitude: obj.value(forKey: "latitude") as? Double ?? 0,
                        longitude: obj.value(forKey: "longitude") as? Double ?? 0
                    )
                }
            } catch {
                print("CoreData search error: \(error)")
            }
        }
        return result
    }

    func fetchTreesByIds(_ ids: [String]) async throws -> [Tree] {
        guard !ids.isEmpty else { return [] }

        try await ensureLoaded()

        let context = TreeCachePersistence.shared.container.newBackgroundContext()
        var result: [Tree] = []

        var normalizedIds: [String] = []
        for id in ids {
            normalizedIds.append(id)

            if id.hasPrefix("BAUM_") {

                normalizedIds.append(String(id.dropFirst(5)))
            } else {

                normalizedIds.append("BAUM_\(id)")
            }
        }

        print("WFSService: Looking for trees with IDs (original + normalized): \(normalizedIds.prefix(5))...")

        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CachedTree")

            request.predicate = NSPredicate(format: "id IN %@", normalizedIds)
            request.fetchLimit = ids.count * 2

            do {
                let results = try context.fetch(request)
                print("WFSService: Found \(results.count) trees matching \(ids.count) requested IDs")

                var seenIds = Set<String>()
                result = results.compactMap { obj -> Tree? in
                    guard let treeId = obj.value(forKey: "id") as? String else { return nil }
                    if seenIds.contains(treeId) { return nil }
                    seenIds.insert(treeId)

                    return Tree(
                        id: treeId,
                        speciesGerman: obj.value(forKey: "speciesGerman") as? String ?? "",
                        speciesLatin: obj.value(forKey: "speciesLatin") as? String ?? "",
                        streetName: obj.value(forKey: "streetName") as? String,
                        district: obj.value(forKey: "district") as? Int,
                        height: obj.value(forKey: "height") as? Double,
                        crownDiameter: obj.value(forKey: "crownDiameter") as? Double,
                        trunkCircumference: obj.value(forKey: "trunkCircumference") as? Double,
                        yearPlanted: obj.value(forKey: "yearPlanted") as? Int,
                        latitude: obj.value(forKey: "latitude") as? Double ?? 0,
                        longitude: obj.value(forKey: "longitude") as? Double ?? 0
                    )
                }

                if result.isEmpty && !ids.isEmpty {
                    print("WFSService: WARNING - No trees found! Check if tree data is loaded.")
                    print("WFSService: First few IDs being searched: \(ids.prefix(3))")
                }
            } catch {
                print("WFSService: CoreData fetch by IDs error: \(error)")
            }
        }
        return result
    }

    func getDistrictClusters() async -> [DistrictCluster] {
        let context = TreeCachePersistence.shared.container.newBackgroundContext()

        return await context.perform {
            let request = NSFetchRequest<NSDictionary>(entityName: "CachedTree")
            request.resultType = .dictionaryResultType

            let countExpr = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "id")])

            let countDesc = NSExpressionDescription()
            countDesc.name = "count"
            countDesc.expression = countExpr
            countDesc.expressionResultType = .integer64AttributeType

            request.propertiesToFetch = ["district", countDesc]
            request.propertiesToGroupBy = ["district"]

            do {
                let results = try context.fetch(request)
                var clusters: [DistrictCluster] = []

                for result in results {
                    if let district = result["district"] as? Int,
                       let count = result["count"] as? Int {
                        if let center = DistrictCoordinates.centers[district] {
                            clusters.append(DistrictCluster(id: district, count: count, coordinate: center))
                        }
                    }
                }
                return clusters
            } catch {
                print("Failed to fetch district clusters: \(error)")
                return []
            }
        }
    }

    func fetchTrees(in region: MKCoordinateRegion, limit: Int = 5000) async throws -> [Tree] {
        let context = TreeCachePersistence.shared.container.newBackgroundContext()

        return try await context.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CachedTree")

            let minLat = region.center.latitude - region.span.latitudeDelta / 2
            let maxLat = region.center.latitude + region.span.latitudeDelta / 2
            let minLon = region.center.longitude - region.span.longitudeDelta / 2
            let maxLon = region.center.longitude + region.span.longitudeDelta / 2

            request.predicate = NSPredicate(format: "latitude >= %f AND latitude <= %f AND longitude >= %f AND longitude <= %f", minLat, maxLat, minLon, maxLon)
            request.fetchLimit = limit

            let results = try context.fetch(request)
            return results.map { self.mapToTree($0) }
        }
    }

    nonisolated private func mapToTree(_ object: NSManagedObject) -> Tree {
        let id = object.value(forKey: "id") as? String ?? ""
        let speciesGerman = object.value(forKey: "speciesGerman") as? String ?? "Unbekannt"
        let speciesLatin = object.value(forKey: "speciesLatin") as? String ?? "Unknown"
        let streetName = object.value(forKey: "streetName") as? String
        let district = object.value(forKey: "district") as? Int
        let height = object.value(forKey: "height") as? Double
        let crownDiameter = object.value(forKey: "crownDiameter") as? Double
        let trunkCircumference = object.value(forKey: "trunkCircumference") as? Double
        let yearPlanted = object.value(forKey: "yearPlanted") as? Int
        let latitude = object.value(forKey: "latitude") as? Double ?? 0.0
        let longitude = object.value(forKey: "longitude") as? Double ?? 0.0

        return Tree(
            id: id,
            speciesGerman: speciesGerman,
            speciesLatin: speciesLatin,
            streetName: streetName,
            district: district,
            height: height,
            crownDiameter: crownDiameter,
            trunkCircumference: trunkCircumference,
            yearPlanted: yearPlanted,
            latitude: latitude,
            longitude: longitude
        )
    }

    private static func parseGeoJSON(_ data: Data) throws -> [Tree] {

        return []
    }
}

enum WFSError: LocalizedError {
    case invalidURL
    case serverError
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .serverError: return "Server error occurred"
        case .parseError: return "Failed to parse response"
        }
    }
}

struct DistrictCluster: Identifiable {
    let id: Int
    let count: Int
    let coordinate: CLLocationCoordinate2D
}

struct DistrictCoordinates {
    static let centers: [Int: CLLocationCoordinate2D] = [
        1: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738),
        2: CLLocationCoordinate2D(latitude: 48.2167, longitude: 16.4000),
        3: CLLocationCoordinate2D(latitude: 48.1983, longitude: 16.3967),
        4: CLLocationCoordinate2D(latitude: 48.1917, longitude: 16.3667),
        5: CLLocationCoordinate2D(latitude: 48.1883, longitude: 16.3567),
        6: CLLocationCoordinate2D(latitude: 48.1950, longitude: 16.3500),
        7: CLLocationCoordinate2D(latitude: 48.2017, longitude: 16.3500),
        8: CLLocationCoordinate2D(latitude: 48.2117, longitude: 16.3483),
        9: CLLocationCoordinate2D(latitude: 48.2217, longitude: 16.3567),
        10: CLLocationCoordinate2D(latitude: 48.1500, longitude: 16.3833),
        11: CLLocationCoordinate2D(latitude: 48.1667, longitude: 16.4500),
        12: CLLocationCoordinate2D(latitude: 48.1667, longitude: 16.3167),
        13: CLLocationCoordinate2D(latitude: 48.1833, longitude: 16.2667),
        14: CLLocationCoordinate2D(latitude: 48.2000, longitude: 16.2667),
        15: CLLocationCoordinate2D(latitude: 48.1967, longitude: 16.3333),
        16: CLLocationCoordinate2D(latitude: 48.2133, longitude: 16.3167),
        17: CLLocationCoordinate2D(latitude: 48.2250, longitude: 16.3167),
        18: CLLocationCoordinate2D(latitude: 48.2333, longitude: 16.3333),
        19: CLLocationCoordinate2D(latitude: 48.2500, longitude: 16.3333),
        20: CLLocationCoordinate2D(latitude: 48.2333, longitude: 16.3667),
        21: CLLocationCoordinate2D(latitude: 48.2667, longitude: 16.4000),
        22: CLLocationCoordinate2D(latitude: 48.2333, longitude: 16.4667),
        23: CLLocationCoordinate2D(latitude: 48.1500, longitude: 16.2833)
    ]
}
