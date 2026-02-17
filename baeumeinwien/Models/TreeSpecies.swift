import Foundation

struct TreeSpecies: Codable, Identifiable, Hashable {
    let id: Int
    let nameGerman: String
    let nameScientific: String?
    let category: String?

    var displayName: String {
        if let scientific = nameScientific {
            return "\(nameGerman) (\(scientific))"
        }
        return nameGerman
    }

    enum CodingKeys: String, CodingKey {
        case id
        case nameGerman = "name_german"
        case nameScientific = "name_scientific"
        case category
    }
}
