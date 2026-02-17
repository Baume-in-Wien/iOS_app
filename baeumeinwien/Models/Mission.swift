import Foundation
import CoreLocation

enum MissionStatus: String, Codable {
    case pending
    case inProgress
    case completed
}

struct Mission: Identifiable, Codable {
    let id: UUID
    let tree: Tree
    var status: MissionStatus
    var photoData: Data?
    var completedAt: Date?

    init(tree: Tree) {
        self.id = UUID()
        self.tree = tree
        self.status = .pending
    }

    mutating func markCompleted(photoData: Data? = nil) {
        self.status = .completed
        self.completedAt = Date()
        self.photoData = photoData
    }
}

struct ExplorerSession: Identifiable, Codable {
    let id: UUID
    let startedAt: Date
    let radius: ExplorerRadius
    var missions: [Mission]
    var isCompleted: Bool {
        missions.allSatisfy { $0.status == .completed }
    }

    var completedCount: Int {
        missions.filter { $0.status == .completed }.count
    }

    var progressText: String {
        "\(completedCount)/\(missions.count) Missions"
    }

    init(radius: ExplorerRadius, missions: [Mission]) {
        self.id = UUID()
        self.startedAt = Date()
        self.radius = radius
        self.missions = missions
    }
}

enum ExplorerRadius: Int, CaseIterable, Codable {
    case r500m = 500
    case r1km = 1000
    case r2km = 2000
    case r5km = 5000

    var displayName: String {
        switch self {
        case .r500m: return "500m"
        case .r1km: return "1km"
        case .r2km: return "2km"
        case .r5km: return "5km"
        }
    }

    var meters: Double {
        Double(rawValue)
    }
}

extension Mission {
    static let preview = Mission(tree: Tree.preview)
}

extension ExplorerSession {
    static let preview = ExplorerSession(
        radius: .r1km,
        missions: Tree.previewList.prefix(5).map { Mission(tree: $0) }
    )
}
