import Foundation
import CoreLocation

enum RallyMode: String, Codable, CaseIterable, Sendable {
    case solo = "solo"
    case student = "student"
    case teacher = "teacher"

    var displayName: String {
        switch self {
        case .solo: return "Solo Entdecker:in"
        case .student: return "Schüler:innen"
        case .teacher: return "Lehrer:innen"
        }
    }
}

enum RallyStatus: String, Codable, Sendable {
    case active = "active"
    case finished = "finished"
    case archived = "archived"
}

struct Rally: Codable, Identifiable, Sendable {
    let id: String
    let code: String
    let name: String
    let description: String?
    let creatorId: String
    let creatorPlatform: String
    let mode: RallyMode
    let status: RallyStatus
    let maxParticipants: Int
    let targetSpeciesCount: Int?
    let timeLimitMinutes: Int?
    let districtFilter: [Int]?
    let radiusMeters: Int?
    let targetTreeIds: [String]?
    let centerLat: Double?
    let centerLng: Double?
    let createdAt: Date
    let startedAt: Date?
    let endedAt: Date?
    let isPublic: Bool
    let allowJoinAfterStart: Bool

    enum CodingKeys: String, CodingKey {
        case id, code, name, description, mode, status
        case creatorId = "creator_id"
        case creatorPlatform = "creator_platform"
        case maxParticipants = "max_participants"
        case targetSpeciesCount = "target_species_count"
        case timeLimitMinutes = "time_limit_minutes"
        case districtFilter = "district_filter"
        case radiusMeters = "radius_meters"
        case targetTreeIds = "target_tree_ids"
        case centerLat = "center_lat"
        case centerLng = "center_lng"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case isPublic = "is_public"
        case allowJoinAfterStart = "allow_join_after_start"
    }

    var centerCoordinate: CLLocationCoordinate2D? {
        guard let lat = centerLat, let lng = centerLng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var qrCodeString: String {
        "baumkataster://rally/\(code)"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        code = try container.decode(String.self, forKey: .code)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        creatorId = try container.decode(String.self, forKey: .creatorId)
        creatorPlatform = try container.decode(String.self, forKey: .creatorPlatform)
        mode = try container.decode(RallyMode.self, forKey: .mode)
        status = try container.decode(RallyStatus.self, forKey: .status)

        maxParticipants = try container.decodeIfPresent(Int.self, forKey: .maxParticipants) ?? 50
        targetSpeciesCount = try container.decodeIfPresent(Int.self, forKey: .targetSpeciesCount)
        timeLimitMinutes = try container.decodeIfPresent(Int.self, forKey: .timeLimitMinutes)
        districtFilter = try container.decodeIfPresent([Int].self, forKey: .districtFilter)
        radiusMeters = try container.decodeIfPresent(Int.self, forKey: .radiusMeters)

        if container.contains(.targetTreeIds) {
            do {
                targetTreeIds = try container.decodeIfPresent([String].self, forKey: .targetTreeIds)
            } catch {

                print("Rally.init: Warning - targetTreeIds decode error: \(error). Setting to nil.")
                targetTreeIds = nil
            }
        } else {
            targetTreeIds = nil
        }

        centerLat = try container.decodeIfPresent(Double.self, forKey: .centerLat)
        centerLng = try container.decodeIfPresent(Double.self, forKey: .centerLng)

        createdAt = try container.decode(Date.self, forKey: .createdAt)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)

        isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic) ?? false
        allowJoinAfterStart = try container.decodeIfPresent(Bool.self, forKey: .allowJoinAfterStart) ?? true
    }

    init(
        id: String, code: String, name: String, description: String?, creatorId: String,
        creatorPlatform: String, mode: RallyMode, status: RallyStatus, maxParticipants: Int,
        targetSpeciesCount: Int?, timeLimitMinutes: Int?, districtFilter: [Int]?, radiusMeters: Int?,
        targetTreeIds: [String]?, centerLat: Double?, centerLng: Double?, createdAt: Date, startedAt: Date?, endedAt: Date?,
        isPublic: Bool, allowJoinAfterStart: Bool
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.description = description
        self.creatorId = creatorId
        self.creatorPlatform = creatorPlatform
        self.mode = mode
        self.status = status
        self.maxParticipants = maxParticipants
        self.targetSpeciesCount = targetSpeciesCount
        self.timeLimitMinutes = timeLimitMinutes
        self.districtFilter = districtFilter
        self.radiusMeters = radiusMeters
        self.targetTreeIds = targetTreeIds
        self.centerLat = centerLat
        self.centerLng = centerLng
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.isPublic = isPublic
        self.allowJoinAfterStart = allowJoinAfterStart
    }

    func withTargetTreeIds(_ treeIds: [String]) -> Rally {
        return Rally(
            id: id,
            code: code,
            name: name,
            description: description,
            creatorId: creatorId,
            creatorPlatform: creatorPlatform,
            mode: mode,
            status: status,
            maxParticipants: maxParticipants,
            targetSpeciesCount: targetSpeciesCount,
            timeLimitMinutes: timeLimitMinutes,
            districtFilter: districtFilter,
            radiusMeters: radiusMeters,
            targetTreeIds: treeIds,
            centerLat: centerLat,
            centerLng: centerLng,
            createdAt: createdAt,
            startedAt: startedAt,
            endedAt: endedAt,
            isPublic: isPublic,
            allowJoinAfterStart: allowJoinAfterStart
        )
    }
}

struct RallyParticipant: Codable, Identifiable, Sendable {
    let id: String
    let rallyId: String
    let deviceId: String
    let platform: String
    let displayName: String
    let joinedAt: Date
    let lastActiveAt: Date
    let isActive: Bool
    let speciesCollected: Int
    let treesScanned: Int

    enum CodingKeys: String, CodingKey {
        case id
        case rallyId = "rally_id"
        case deviceId = "device_id"
        case platform
        case displayName = "display_name"
        case joinedAt = "joined_at"
        case lastActiveAt = "last_active_at"
        case isActive = "is_active"
        case speciesCollected = "species_collected"
        case treesScanned = "trees_scanned"
    }
}

struct RallyCollection: Codable, Identifiable, Sendable {
    let id: String
    let rallyId: String
    let participantId: String
    let treeId: String
    let species: String
    let latitude: Double
    let longitude: Double
    let photoUrl: String?
    let notes: String?
    let collectedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case rallyId = "rally_id"
        case participantId = "participant_id"
        case treeId = "tree_id"
        case species
        case latitude, longitude
        case photoUrl = "photo_url"
        case notes
        case collectedAt = "collected_at"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum RallyEventType: String, Codable, Sendable {
    case treeCollected = "tree_collected"
    case participantJoined = "participant_joined"
    case participantLeft = "participant_left"
    case rallyStarted = "rally_started"
    case rallyFinished = "rally_finished"
    case achievementUnlocked = "achievement_unlocked"
}

struct RallyEvent: Codable, Identifiable, Sendable {
    let id: String
    let rallyId: String
    let eventType: RallyEventType
    let participantId: String?
    let eventData: [String: String]?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case rallyId = "rally_id"
        case eventType = "event_type"
        case participantId = "participant_id"
        case eventData = "event_data"
        case createdAt = "created_at"
    }
}

struct RallyStatistics: Codable, Sendable {
    let totalParticipants: Int
    let totalTreesCollected: Int
    let totalUniqueSpecies: Int
    let topCollectors: [TopCollector]?
    let mostCollectedSpecies: [SpeciesCount]?

    enum CodingKeys: String, CodingKey {
        case totalParticipants = "total_participants"
        case totalTreesCollected = "total_trees_collected"
        case totalUniqueSpecies = "total_unique_species"
        case topCollectors = "top_collectors"
        case mostCollectedSpecies = "most_collected_species"
    }
}

struct TopCollector: Codable, Identifiable, Sendable {
    let name: String
    let platform: String
    let speciesCount: Int
    let treeCount: Int

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, platform
        case speciesCount = "species_count"
        case treeCount = "tree_count"
    }
}

struct SpeciesCount: Codable, Identifiable, Sendable {
    let species: String
    let count: Int

    var id: String { species }
}

struct RallyProgress: Codable, Sendable {
    let rallyId: String
    let code: String
    let name: String
    let targetSpeciesCount: Int?
    let deviceId: String
    let speciesCollected: Int
    let treesScanned: Int
    let progressPercent: Double
    let isCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case rallyId = "rally_id"
        case code, name
        case targetSpeciesCount = "target_species_count"
        case deviceId = "device_id"
        case speciesCollected = "species_collected"
        case treesScanned = "trees_scanned"
        case progressPercent = "progress_percent"
        case isCompleted = "is_completed"
    }
}

struct LeaderboardEntry: Codable, Identifiable, Sendable {
    let deviceId: String
    let displayName: String
    let platform: String
    let speciesCollected: Int
    let treesScanned: Int
    let hasCompleted: Bool

    var id: String { deviceId }

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case displayName = "display_name"
        case platform
        case speciesCollected = "species_collected"
        case treesScanned = "trees_scanned"
        case hasCompleted = "has_completed"
    }
}

struct CreateRallyResult: Codable, Sendable {
    let rallyId: String
    let joinCode: String

    enum CodingKeys: String, CodingKey {
        case rallyId = "rally_id"
        case joinCode = "join_code"
    }
}

struct JoinRallyResult: Codable, Sendable {
    let rallyId: String
    let participantId: String

    enum CodingKeys: String, CodingKey {
        case rallyId = "rally_id"
        case participantId = "participant_id"
    }
}

struct CollectTreeResult: Codable, Sendable {
    let collectionId: String
    let isNewSpecies: Bool

    enum CodingKeys: String, CodingKey {
        case collectionId = "collection_id"
        case isNewSpecies = "is_new_species"
    }
}

enum RallyResult<T> {
    case success(T)
    case error(String)

    var value: T? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }

    var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }

    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}

enum RallyState: Equatable {
    case idle
    case loading
    case active(Rally)
    case treeCollected(RallyCollection)
    case participantJoined(RallyParticipant)
    case participantLeft(RallyParticipant)
    case rallyFinished(Rally)
    case error(String)

    static func == (lhs: RallyState, rhs: RallyState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.loading, .loading): return true
        case (.active(let a), .active(let b)): return a.id == b.id
        case (.treeCollected(let a), .treeCollected(let b)): return a.id == b.id
        case (.participantJoined(let a), .participantJoined(let b)): return a.id == b.id
        case (.participantLeft(let a), .participantLeft(let b)): return a.id == b.id
        case (.rallyFinished(let a), .rallyFinished(let b)): return a.id == b.id
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}
