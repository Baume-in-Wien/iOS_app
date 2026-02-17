import Foundation
import CoreLocation

struct CommunityTree: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let userDisplayName: String?
    let speciesGerman: String
    let speciesScientific: String?
    let latitude: Double
    let longitude: Double
    let district: Int?
    let street: String?
    let estimatedHeight: Double?
    let estimatedTrunkCircumference: Int?
    let gpsAccuracyMeters: Double?
    let locationMethod: String
    let status: String
    let confirmationCount: Int
    let createdAt: String?

    let userRole: String?
    let userIsVerified: Bool?
    let showCreatorName: Bool?

    var displayName: String {
        if let scientific = speciesScientific {
            return "\(speciesGerman) (\(scientific))"
        }
        return speciesGerman
    }

    var creatorDisplayText: String {
        if userRole == "official" && userIsVerified == true {
            return "Bäume in Wien Official Team"
        }
        if showCreatorName == false {
            return "Community-Mitglied"
        }
        return userDisplayName ?? "Community-Mitglied"
    }

    var officialStatusText: String? {
        if isOfficialTree {
            return "Überprüft vom offiziellen Bäume in Wien Team"
        }
        return nil
    }

    var isOfficialTree: Bool {
        userRole == "official" && userIsVerified == true
    }

    var isVerified: Bool {
        status == "verified" || isOfficialTree
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case userDisplayName = "user_display_name"
        case speciesGerman = "species_german"
        case speciesScientific = "species_scientific"
        case latitude, longitude, district, street
        case estimatedHeight = "estimated_height"
        case estimatedTrunkCircumference = "estimated_trunk_circumference"
        case gpsAccuracyMeters = "gps_accuracy_meters"
        case locationMethod = "location_method"
        case status
        case confirmationCount = "confirmation_count"
        case createdAt = "created_at"
        case userRole = "user_role"
        case userIsVerified = "user_is_verified"
        case showCreatorName = "show_creator_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        userDisplayName = try container.decodeIfPresent(String.self, forKey: .userDisplayName)
        speciesGerman = try container.decode(String.self, forKey: .speciesGerman)
        speciesScientific = try container.decodeIfPresent(String.self, forKey: .speciesScientific)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        district = try container.decodeIfPresent(Int.self, forKey: .district)
        street = try container.decodeIfPresent(String.self, forKey: .street)
        estimatedHeight = try container.decodeIfPresent(Double.self, forKey: .estimatedHeight)
        estimatedTrunkCircumference = try container.decodeIfPresent(Int.self, forKey: .estimatedTrunkCircumference)
        gpsAccuracyMeters = try container.decodeIfPresent(Double.self, forKey: .gpsAccuracyMeters)
        locationMethod = try container.decodeIfPresent(String.self, forKey: .locationMethod) ?? "gps"
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "approved"
        confirmationCount = try container.decodeIfPresent(Int.self, forKey: .confirmationCount) ?? 0
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        userRole = try container.decodeIfPresent(String.self, forKey: .userRole)
        userIsVerified = try container.decodeIfPresent(Bool.self, forKey: .userIsVerified)
        showCreatorName = try container.decodeIfPresent(Bool.self, forKey: .showCreatorName)
    }
}

struct CommunityTreeInsert: Encodable {
    let userId: String
    let userDisplayName: String?
    let speciesGerman: String
    let speciesScientific: String?
    let latitude: Double
    let longitude: Double
    let district: Int?
    let street: String?
    let estimatedHeight: Double?
    let estimatedTrunkCircumference: Int?
    let gpsAccuracyMeters: Double?
    let locationMethod: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case userDisplayName = "user_display_name"
        case speciesGerman = "species_german"
        case speciesScientific = "species_scientific"
        case latitude, longitude, district, street
        case estimatedHeight = "estimated_height"
        case estimatedTrunkCircumference = "estimated_trunk_circumference"
        case gpsAccuracyMeters = "gps_accuracy_meters"
        case locationMethod = "location_method"
    }
}
