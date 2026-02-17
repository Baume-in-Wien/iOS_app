import Foundation
import SwiftUI

struct HerbariumEntry: Identifiable, Codable, Hashable {
    let id: String
    let treeId: String?
    let speciesGerman: String
    let speciesLatin: String?
    let photoData: Data?
    let imagePath: String?
    let capturedAt: Date
    let latitude: Double?
    let longitude: Double?
    let rallyId: String?
    let emojiBadge: String

    init(id: UUID = UUID(), date: Date = Date(), imagePath: String, treeSpecies: String? = nil) {
        self.id = id.uuidString
        self.treeId = nil
        self.speciesGerman = treeSpecies ?? "Unbekannt"
        self.speciesLatin = nil
        self.photoData = nil
        self.imagePath = imagePath
        self.capturedAt = date
        self.latitude = nil
        self.longitude = nil
        self.rallyId = nil
        self.emojiBadge = HerbariumEntry.randomLeafEmoji()
    }

    init(
        id: String,
        treeId: String?,
        speciesGerman: String,
        speciesLatin: String?,
        photoData: Data?,
        capturedAt: Date,
        latitude: Double?,
        longitude: Double?,
        rallyId: String?
    ) {
        self.id = id
        self.treeId = treeId
        self.speciesGerman = speciesGerman
        self.speciesLatin = speciesLatin
        self.photoData = photoData
        self.imagePath = nil
        self.capturedAt = capturedAt
        self.latitude = latitude
        self.longitude = longitude
        self.rallyId = rallyId
        self.emojiBadge = HerbariumEntry.randomLeafEmoji()
    }

    static func randomLeafEmoji() -> String {
        let emojis = ["🍃", "🍂", "🍁", "🌿", "🌱", "🌲", "🌳", "🍀", "☘️", "🪴", "🎋", "🎍"]
        return emojis.randomElement() ?? "🍃"
    }

    var date: Date { capturedAt }
    var treeSpecies: String? { speciesGerman }

    var photo: UIImage? {
        guard let data = photoData else { return nil }
        return UIImage(data: data)
    }
}
