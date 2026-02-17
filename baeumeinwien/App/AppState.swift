import Foundation
import SwiftUI
import CoreLocation

@Observable
final class AppState {
    static let shared = AppState()

    var isInitialLoading = false
    var loadingProgress: Double = 0.0
    var loadingMessage: String = ""
    var isDataReady = false

    var trees: [Tree] = []
    var selectedTree: Tree?
    var highlightedTreeID: String?
    var isLoadingTrees = false
    var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    var currentSession: ExplorerSession?
    var selectedRadius: ExplorerRadius = .r1km
    var explorerHistory: [ExplorerSession] = []

    var activeRally: Rally?
    var isRallyHost = false
    var participantName: String = ""
    var herbariumEntries: [HerbariumEntry] = [] {
        didSet {
            saveHerbarium()
        }
    }

    var achievements: [Achievement] = Achievement.allAchievements
    var recentlyUnlockedAchievement: Achievement?
    var showAchievementUnlock = false

    var searchText = ""
    var searchResults: [Tree] = []
    var recentSearches: [String] = []
    var isSearching = false

    var userLocation: CLLocation?
    var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined

    var communityTrees: [CommunityTree] = []
    var showAddTree = false
    var showLogin = false

    var selectedTab: AppTab = .map
    var showTreeDetail = false
    var showExplorerSetup = false
    var showRallySetup = false
    var showRallyJoin = false
    var showAchievementGallery = false

    var totalTreesDiscovered: Int {
        UserDefaults.standard.integer(forKey: "totalTreesDiscovered")
    }

    var uniqueSpeciesDiscovered: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: "discoveredSpecies") ?? [])
    }

    var totalDistanceWalked: Double {
        UserDefaults.standard.double(forKey: "totalDistanceWalked")
    }

    private init() {
        loadRecentSearches()
        loadHerbarium()
    }

    func discoverTree(_ tree: Tree) {
        var discovered = UserDefaults.standard.stringArray(forKey: "discoveredSpecies") ?? []
        if !discovered.contains(tree.speciesGerman) {
            discovered.append(tree.speciesGerman)
            UserDefaults.standard.set(discovered, forKey: "discoveredSpecies")
            checkSpeciesAchievements()
        }

        let total = UserDefaults.standard.integer(forKey: "totalTreesDiscovered") + 1
        UserDefaults.standard.set(total, forKey: "totalTreesDiscovered")

        if total == 1 {
            unlockAchievement("first_tree")
        }

        PetService.shared.onTreeDiscovered(treeName: tree.speciesGerman, treeId: tree.id)
    }

    func unlockAchievement(_ id: String) {
        guard let index = achievements.firstIndex(where: { $0.id == id && !$0.isUnlocked }) else { return }

        achievements[index].isUnlocked = true
        achievements[index].unlockedAt = Date()
        recentlyUnlockedAchievement = achievements[index]
        showAchievementUnlock = true

        var unlockedIds = UserDefaults.standard.stringArray(forKey: "unlockedAchievements") ?? []
        unlockedIds.append(id)
        UserDefaults.standard.set(unlockedIds, forKey: "unlockedAchievements")
    }

    private func checkSpeciesAchievements() {
        let count = uniqueSpeciesDiscovered.count
        if count >= 10 { unlockAchievement("species_10") }
        if count >= 25 { unlockAchievement("species_25") }
        if count >= 50 { unlockAchievement("species_50") }
    }

    func addRecentSearch(_ search: String) {
        var searches = recentSearches
        searches.removeAll { $0 == search }
        searches.insert(search, at: 0)
        if searches.count > 10 {
            searches = Array(searches.prefix(10))
        }
        recentSearches = searches
        UserDefaults.standard.set(searches, forKey: "recentSearches")
    }

    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: "recentSearches") ?? []

        let unlockedIds = UserDefaults.standard.stringArray(forKey: "unlockedAchievements") ?? []
        for id in unlockedIds {
            if let index = achievements.firstIndex(where: { $0.id == id }) {
                achievements[index].isUnlocked = true
            }
        }
    }

    private func loadHerbarium() {
        if let data = UserDefaults.standard.data(forKey: "herbariumEntries"),
           let entries = try? JSONDecoder().decode([HerbariumEntry].self, from: data) {
            herbariumEntries = entries
        }
    }

    private func saveHerbarium() {
        if let data = try? JSONEncoder().encode(herbariumEntries) {
            UserDefaults.standard.set(data, forKey: "herbariumEntries")
        }
    }
}

enum AppTab: String, CaseIterable, Hashable {

    case map = "Karte"
    case explorer = "Entdecker"
    case ar = "AR"
    case rally = "Rallye"
    case more = "Mehr"

    case leafScanner = "Blatt-Scanner"
    case favorites = "Favoriten"
    case pet = "Mein Tier"
    case achievements = "Erfolge"
    case statistics = "Statistik"
    case info = "Info"

    var icon: String {
        switch self {
        case .map: return "map.fill"
        case .explorer: return "figure.walk"
        case .ar: return "camera.viewfinder"
        case .rally: return "person.3.fill"
        case .more: return "ellipsis.circle.fill"
        case .leafScanner: return "leaf.circle.fill"
        case .favorites: return "star.fill"
        case .pet: return "pawprint.fill"
        case .achievements: return "trophy.fill"
        case .statistics: return "chart.bar.fill"
        case .info: return "info.circle.fill"
        }
    }

    static var mainTabs: [AppTab] {
        [.map, .explorer, .ar, .rally, .more]
    }

    static var moreTabs: [AppTab] {
        [.leafScanner, .favorites, .pet, .achievements, .statistics, .info]
    }
}

import MapKit
