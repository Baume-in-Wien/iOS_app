import Foundation

struct UserProfile: Codable, Identifiable {
    let id: String
    let displayName: String?
    let showNameOnTrees: Bool
    let role: String
    let isVerified: Bool
    let createdAt: String?

    var isAdmin: Bool { role == "admin" }
    var isOfficial: Bool { role == "official" }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case showNameOnTrees = "show_name_on_trees"
        case role
        case isVerified = "is_verified"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        showNameOnTrees = try container.decodeIfPresent(Bool.self, forKey: .showNameOnTrees) ?? true
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? "user"
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }
}
