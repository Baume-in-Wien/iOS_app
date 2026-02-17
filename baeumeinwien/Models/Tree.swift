import Foundation
import CoreLocation
import MapKit

struct Tree: Identifiable, Codable, Hashable {
    let id: String
    let speciesGerman: String
    let speciesLatin: String
    let streetName: String?
    let district: Int?
    let height: Double?
    let crownDiameter: Double?
    let trunkCircumference: Double?
    let yearPlanted: Int?
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var speciesIcon: String {
        let species = speciesGerman.lowercased()
        if species.contains("linde") { return "leaf.fill" }
        if species.contains("ahorn") { return "leaf.circle.fill" }
        if species.contains("eiche") { return "tree.fill" }
        if species.contains("kastanie") { return "star.circle.fill" }
        if species.contains("birke") { return "wind" }
        if species.contains("fichte") || species.contains("tanne") { return "triangle.fill" }
        if species.contains("obstbaum") || species.contains("apfel") { return "apple.logo" }
        return "tree.fill"
    }

    var speciesColor: String {
        let species = speciesGerman.lowercased()
        if species.contains("linde") { return "green" }
        if species.contains("ahorn") { return "orange" }
        if species.contains("eiche") { return "brown" }
        if species.contains("kastanie") { return "red" }
        if species.contains("birke") { return "mint" }
        return "teal"
    }

    func distance(from location: CLLocation) -> Double {
        let treeLocation = CLLocation(latitude: latitude, longitude: longitude)
        return location.distance(from: treeLocation)
    }
}

struct TreeCluster: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let count: Int
    let trees: [Tree]
}

extension Tree {
    static let preview = Tree(
        id: "BAUM_001",
        speciesGerman: "Winterlinde",
        speciesLatin: "Tilia cordata",
        streetName: "Ringstraße",
        district: 1,
        height: 15.5,
        crownDiameter: 8.2,
        trunkCircumference: 120,
        yearPlanted: 1985,
        latitude: 48.2082,
        longitude: 16.3738
    )

    static let previewList: [Tree] = [
        Tree(id: "BAUM_001", speciesGerman: "Winterlinde", speciesLatin: "Tilia cordata", streetName: "Ringstraße", district: 1, height: 15.5, crownDiameter: 8.2, trunkCircumference: 120, yearPlanted: 1985, latitude: 48.2082, longitude: 16.3738),
        Tree(id: "BAUM_002", speciesGerman: "Spitzahorn", speciesLatin: "Acer platanoides", streetName: "Mariahilfer Straße", district: 6, height: 12.0, crownDiameter: 6.5, trunkCircumference: 95, yearPlanted: 1990, latitude: 48.1962, longitude: 16.3452),
        Tree(id: "BAUM_003", speciesGerman: "Rosskastanie", speciesLatin: "Aesculus hippocastanum", streetName: "Prater Hauptallee", district: 2, height: 18.0, crownDiameter: 10.0, trunkCircumference: 150, yearPlanted: 1970, latitude: 48.2109, longitude: 16.3950),
        Tree(id: "BAUM_004", speciesGerman: "Stieleiche", speciesLatin: "Quercus robur", streetName: "Schönbrunner Schloßstraße", district: 13, height: 20.0, crownDiameter: 12.0, trunkCircumference: 200, yearPlanted: 1960, latitude: 48.1844, longitude: 16.3119),
        Tree(id: "BAUM_005", speciesGerman: "Hängebirke", speciesLatin: "Betula pendula", streetName: "Donauinsel", district: 22, height: 10.0, crownDiameter: 5.0, trunkCircumference: 60, yearPlanted: 2000, latitude: 48.2350, longitude: 16.4100)
    ]
}
