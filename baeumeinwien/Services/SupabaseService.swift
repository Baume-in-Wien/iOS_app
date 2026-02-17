import Foundation
import UIKit
import CoreLocation
import Combine

actor SupabaseService {
    static let shared = SupabaseService()

    private let supabaseURL = "https://awkwclebcnzgvpnmypwd.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3a3djbGViY256Z3Zwbm15cHdkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcxNTU2ODgsImV4cCI6MjA4MjczMTY4OH0.z29RXjO5wZxt0BKZsZINs_9bnpF25439fUbN3U3A-qc"

    private var cachedDeviceId: String?

    private var deviceId: String {
        get async {
            if let cached = cachedDeviceId {
                return cached
            }
            let id = await MainActor.run {
                UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            }
            cachedDeviceId = id
            return id
        }
    }

    private let platform = "ios"

    func createRally(
        name: String,
        description: String?,
        mode: RallyMode,
        districtFilter: [Int]? = nil,
        targetSpeciesCount: Int? = nil,
        timeLimitMinutes: Int? = nil,
        radiusMeters: Int? = nil,
        centerLocation: CLLocationCoordinate2D? = nil,
        targetTreeIds: [String]? = nil
    ) async -> RallyResult<Rally> {
        let currentDeviceId = await deviceId

        var params: [String: Any] = [
            "p_name": name,
            "p_description": description ?? "",
            "p_creator_id": currentDeviceId,
            "p_creator_platform": platform,
            "p_mode": mode.rawValue
        ]

        if let districts = districtFilter {
            params["p_district_filter"] = districts
        }
        if let speciesCount = targetSpeciesCount {
            params["p_target_species_count"] = speciesCount
        }
        if let timeLimit = timeLimitMinutes {
            params["p_time_limit_minutes"] = timeLimit
        }
        if let radius = radiusMeters {
            params["p_radius_meters"] = radius
        }
        if let lat = centerLocation?.latitude {
            params["p_center_lat"] = lat
        }
        if let lng = centerLocation?.longitude {
            params["p_center_lng"] = lng
        }
        if let treeIds = targetTreeIds {
            params["p_target_tree_ids"] = treeIds
            print("🌳 [SupabaseService] createRally: Sending \(treeIds.count) tree IDs: \(treeIds.prefix(5))")
        } else {
            print("🌳 [SupabaseService] createRally: No tree IDs provided")
        }

        print("🌳 [SupabaseService] createRally: Calling RPC with params: \(params.keys)")

        do {
            let data = try await rpcRequest(function: "create_rally", params: params)

            struct CreateResult: Codable {
                let rally_id: String
                let join_code: String
            }

            print("🌳 [SupabaseService] createRally: RPC response received, parsing...")

            if let results = try? JSONDecoder().decode([CreateResult].self, from: data),
               let result = results.first {
                print("🌳 [SupabaseService] createRally: Parsed as array, rally_id: \(result.rally_id)")

                if let rally = try await getRallyById(result.rally_id) {

                    let _ = try await joinRallyInternal(rallyId: rally.id, displayName: "Organisator")
                    return .success(rally)
                } else {
                    return .error("Rally wurde erstellt, konnte aber nicht geladen werden")
                }
            }

            if let result = try? JSONDecoder().decode(CreateResult.self, from: data) {
                print("🌳 [SupabaseService] createRally: Parsed as single object, rally_id: \(result.rally_id)")

                if let rally = try await getRallyById(result.rally_id) {
                    let _ = try await joinRallyInternal(rallyId: rally.id, displayName: "Organisator")
                    return .success(rally)
                } else {
                    return .error("Rally wurde erstellt, konnte aber nicht geladen werden")
                }
            }

            let responseStr = String(data: data, encoding: .utf8) ?? "no data"
            print("🌳 [SupabaseService] createRally: Failed to parse response: \(responseStr)")
            return .error("RPC Response konnte nicht geparst werden")

        } catch {

            print("🌳 [SupabaseService] createRally ERROR: \(error.localizedDescription)")
            return .error("Fehler beim Erstellen der Rallye: \(error.localizedDescription)")
        }
    }

    private func createRallyDirect(
        name: String,
        description: String?,
        mode: RallyMode,
        districtFilter: [Int]? = nil,
        targetSpeciesCount: Int? = nil,
        timeLimitMinutes: Int? = nil,
        radiusMeters: Int? = nil,
        centerLocation: CLLocationCoordinate2D? = nil,
        targetTreeIds: [String]? = nil
    ) async -> RallyResult<Rally> {
        let code = generateRallyCode()
        let rallyId = UUID().uuidString
        let currentDeviceId = await deviceId

        let rally = Rally(
            id: rallyId,
            code: code,
            name: name,
            description: description,
            creatorId: currentDeviceId,
            creatorPlatform: platform,
            mode: mode,
            status: .active,
            maxParticipants: 50,
            targetSpeciesCount: targetSpeciesCount,
            timeLimitMinutes: timeLimitMinutes,
            districtFilter: districtFilter,
            radiusMeters: radiusMeters,
            targetTreeIds: targetTreeIds,
            centerLat: centerLocation?.latitude,
            centerLng: centerLocation?.longitude,
            createdAt: Date(),
            startedAt: nil,
            endedAt: nil,
            isPublic: false,
            allowJoinAfterStart: true
        )

        do {
            let createdRally = try await insertRally(rally)
            let _ = try await joinRallyInternal(rallyId: createdRally.id, displayName: "Organisator")
            return .success(createdRally)
        } catch {
            return .error("Fehler beim Erstellen der Rallye: \(error.localizedDescription)")
        }
    }

    func joinRally(code: String, displayName: String = "Teilnehmer") async -> RallyResult<Rally> {
        let trimmedCode = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedCode.count == 6 else {
            return .error("Ungültiger Code. Der Code muss 6 Zeichen haben.")
        }

        let currentDeviceId = await deviceId

        let params: [String: Any] = [
            "p_code": trimmedCode,
            "p_device_id": currentDeviceId,
            "p_platform": platform,
            "p_display_name": displayName
        ]

        do {
            let data = try await rpcRequest(function: "join_rally", params: params)

            struct JoinResult: Codable {
                let rally_id: String
                let participant_id: String
                let already_joined: Bool?
            }

            let result = try JSONDecoder().decode(JoinResult.self, from: data)

            if let rally = try await findRallyById(result.rally_id) {
                return .success(rally)
            }
            return .error("Rally nicht gefunden nach Beitritt")

        } catch {

            print("RPC join_rally failed, trying fallback: \(error)")
            return await joinRallyDirect(code: trimmedCode, displayName: displayName)
        }
    }

    private func joinRallyDirect(code: String, displayName: String) async -> RallyResult<Rally> {
        do {
            guard let rally = try await findRallyByCode(code) else {
                return .error("Rallye mit Code '\(code)' nicht gefunden")
            }

            let currentDeviceId = await deviceId
            if try await isAlreadyParticipant(rallyId: rally.id, deviceId: currentDeviceId) {
                return .success(rally)
            }

            let _ = try await joinRallyInternal(rallyId: rally.id, displayName: displayName)
            return .success(rally)
        } catch {

            let errorMessage = error.localizedDescription
            if errorMessage.contains("23505") || errorMessage.contains("unique") || errorMessage.contains("duplicate") {

                if let rally = try? await findRallyByCode(code) {
                    return .success(rally)
                }
            }
            return .error("Fehler beim Beitreten: \(error.localizedDescription)")
        }
    }

    private func isAlreadyParticipant(rallyId: String, deviceId: String) async throws -> Bool {
        let data = try await makeRequest(endpoint: "rally_participants?rally_id=eq.\(rallyId)&device_id=eq.\(deviceId)&select=id")

        struct ParticipantCheck: Codable {
            let id: String
        }

        let participants = try JSONDecoder().decode([ParticipantCheck].self, from: data)
        return !participants.isEmpty
    }

    private func joinRallyInternal(rallyId: String, displayName: String) async throws -> RallyParticipant {
        let currentDeviceId = await deviceId
        let participant = RallyParticipant(
            id: UUID().uuidString,
            rallyId: rallyId,
            deviceId: currentDeviceId,
            platform: platform,
            displayName: displayName,
            joinedAt: Date(),
            lastActiveAt: Date(),
            isActive: true,
            speciesCollected: 0,
            treesScanned: 0
        )

        return try await insertParticipant(participant)
    }

    func collectTree(
        rallyId: String,
        participantId: String,
        tree: Tree,
        photoUrl: String? = nil,
        notes: String? = nil
    ) async -> RallyResult<CollectTreeResult> {
        do {
            if let rally = try await getRally(rallyId: rallyId) {
                if !isTreeWithinRallyRadius(tree: tree, rally: rally) {
                    return .error("Baum außerhalb des Rally-Radius!")
                }
            }

            let collection = RallyCollection(
                id: UUID().uuidString,
                rallyId: rallyId,
                participantId: participantId,
                treeId: tree.id,
                species: tree.speciesGerman,
                latitude: tree.latitude,
                longitude: tree.longitude,
                photoUrl: photoUrl,
                notes: notes,
                collectedAt: Date()
            )

            let result = try await insertCollection(collection)
            return .success(result)
        } catch {
            return .error("Fehler beim Sammeln des Baums: \(error.localizedDescription)")
        }
    }

    func getRallyProgress(rallyId: String) async -> RallyResult<RallyProgress?> {
        let currentDeviceId = await deviceId
        do {
            let progress = try await fetchRallyProgress(rallyId: rallyId, deviceId: currentDeviceId)
            return .success(progress)
        } catch {
            return .error("Fehler beim Laden des Fortschritts: \(error.localizedDescription)")
        }
    }

    func getRallyStats(rallyId: String) async -> RallyResult<RallyStatistics> {
        do {
            let stats = try await fetchRallyStats(rallyId: rallyId)
            return .success(stats)
        } catch {
            return .error("Fehler beim Laden der Statistiken: \(error.localizedDescription)")
        }
    }

    func getLeaderboard(rallyId: String) async -> RallyResult<[LeaderboardEntry]> {
        do {
            let leaderboard = try await fetchLeaderboard(rallyId: rallyId)
            return .success(leaderboard)
        } catch {
            return .error("Fehler beim Laden des Leaderboards: \(error.localizedDescription)")
        }
    }

    func leaveRally(rallyId: String) async -> RallyResult<Bool> {
        let currentDeviceId = await deviceId
        do {
            try await updateParticipantStatus(rallyId: rallyId, deviceId: currentDeviceId, isActive: false)
            return .success(true)
        } catch {
            return .error("Fehler beim Verlassen der Rallye: \(error.localizedDescription)")
        }
    }

    func endRally(rallyId: String) async -> RallyResult<Bool> {
        do {
            try await updateRallyStatus(rallyId: rallyId, status: .finished)
            return .success(true)
        } catch {
            return .error("Fehler beim Beenden der Rallye: \(error.localizedDescription)")
        }
    }

    private func generateRallyCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }

    func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let earthRadiusMeters = 6371000.0

        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLat = (to.latitude - from.latitude) * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1) * cos(lat2) *
                sin(deltaLon / 2) * sin(deltaLon / 2)

        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadiusMeters * c
    }

    func isTreeWithinRallyRadius(tree: Tree, rally: Rally) -> Bool {
        guard let centerLat = rally.centerLat,
              let centerLng = rally.centerLng,
              let radiusMeters = rally.radiusMeters else {
            return true
        }

        let rallyCenter = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng)
        let treeLocation = CLLocationCoordinate2D(latitude: tree.latitude, longitude: tree.longitude)

        let distance = calculateDistance(from: rallyCenter, to: treeLocation)
        return distance <= Double(radiusMeters)
    }

    private func makeRequest(endpoint: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/\(endpoint)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        if let body = body {
            request.httpBody = body
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "SupabaseError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        return data
    }

    private func rpcRequest(function: String, params: [String: Any]) async throws -> Data {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/rpc/\(function)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let body = try JSONSerialization.data(withJSONObject: params)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "SupabaseRPCError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        return data
    }

    private func getRallyById(_ rallyId: String) async throws -> Rally? {
        let data = try await makeRequest(endpoint: "rallies?id=eq.\(rallyId)&select=*")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let rallies = try decoder.decode([Rally].self, from: data)
        return rallies.first
    }

    private func insertRally(_ rally: Rally) async throws -> Rally {
        let insertData: [String: Any?] = [
            "id": rally.id,
            "code": rally.code,
            "name": rally.name,
            "description": rally.description,
            "creator_id": rally.creatorId,
            "creator_platform": rally.creatorPlatform,
            "mode": rally.mode.rawValue,
            "status": rally.status.rawValue,
            "max_participants": rally.maxParticipants,
            "target_species_count": rally.targetSpeciesCount,
            "time_limit_minutes": rally.timeLimitMinutes,
            "radius_meters": rally.radiusMeters,
            "center_lat": rally.centerLat,
            "center_lng": rally.centerLng,
            "is_public": rally.isPublic,
            "allow_join_after_start": rally.allowJoinAfterStart
        ]

        let body = try JSONSerialization.data(withJSONObject: insertData.compactMapValues { $0 })
        let _ = try await makeRequest(endpoint: "rallies", method: "POST", body: body)

        return rally
    }

    private func insertParticipant(_ participant: RallyParticipant) async throws -> RallyParticipant {
        let insertData: [String: Any] = [
            "id": participant.id,
            "rally_id": participant.rallyId,
            "device_id": participant.deviceId,
            "platform": participant.platform,
            "display_name": participant.displayName,
            "is_active": participant.isActive,
            "species_collected": participant.speciesCollected,
            "trees_scanned": participant.treesScanned
        ]

        let body = try JSONSerialization.data(withJSONObject: insertData)
        let _ = try await makeRequest(endpoint: "rally_participants", method: "POST", body: body)

        return participant
    }

    private func insertCollection(_ collection: RallyCollection) async throws -> CollectTreeResult {
        let insertData: [String: Any?] = [
            "id": collection.id,
            "rally_id": collection.rallyId,
            "participant_id": collection.participantId,
            "tree_id": collection.treeId,
            "species": collection.species,
            "latitude": collection.latitude,
            "longitude": collection.longitude,
            "photo_url": collection.photoUrl,
            "notes": collection.notes
        ]

        let body = try JSONSerialization.data(withJSONObject: insertData.compactMapValues { $0 })
        let _ = try await makeRequest(endpoint: "rally_collections", method: "POST", body: body)

        return CollectTreeResult(collectionId: collection.id, isNewSpecies: true)
    }

    private func findRallyByCode(_ code: String) async throws -> Rally? {

        let data = try await makeRequest(endpoint: "rallies?code=eq.\(code)&select=*")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var rallies = try decoder.decode([Rally].self, from: data)

        guard var rally = rallies.first(where: { $0.status == .active }) ?? rallies.first else {
            return nil
        }

        if rally.targetTreeIds == nil || rally.targetTreeIds?.isEmpty == true {
            let treeIds = try await fetchRallyTargetTreeIds(rallyId: rally.id)
            if !treeIds.isEmpty {
                rally = rally.withTargetTreeIds(treeIds)
                print("SupabaseService: Loaded \(treeIds.count) tree IDs from rally_targets for rally \(rally.code)")
            }
        }

        return rally
    }

    private func findRallyById(_ rallyId: String) async throws -> Rally? {
        print("SupabaseService.findRallyById: Looking for rally with ID: \(rallyId)")
        let data = try await makeRequest(endpoint: "rallies?id=eq.\(rallyId)&select=*")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var rallies = try decoder.decode([Rally].self, from: data)
        guard var rally = rallies.first else {
            print("SupabaseService.findRallyById: No rally found with ID \(rallyId)")
            return nil
        }

        print("SupabaseService.findRallyById: Found rally '\(rally.name)' with code \(rally.code)")
        print("SupabaseService.findRallyById: Rally has targetTreeIds: \(rally.targetTreeIds?.description ?? "nil")")

        if rally.targetTreeIds == nil || rally.targetTreeIds?.isEmpty == true {
            print("SupabaseService.findRallyById: No tree IDs in column, fetching from rally_targets table...")
            let treeIds = try await fetchRallyTargetTreeIds(rallyId: rally.id)
            if !treeIds.isEmpty {
                rally = rally.withTargetTreeIds(treeIds)
                print("SupabaseService.findRallyById: SUCCESS! Loaded \(treeIds.count) tree IDs from rally_targets: \(treeIds.prefix(3))...")
            } else {
                print("SupabaseService.findRallyById: WARNING - No tree IDs found in rally_targets table either!")
            }
        } else {
            print("SupabaseService.findRallyById: Rally already has \(rally.targetTreeIds?.count ?? 0) tree IDs in column")
        }

        return rally
    }

    private func getRally(rallyId: String) async throws -> Rally? {
        let data = try await makeRequest(endpoint: "rallies?id=eq.\(rallyId)&select=*")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var rallies = try decoder.decode([Rally].self, from: data)
        guard var rally = rallies.first else {
            return nil
        }

        if rally.targetTreeIds == nil || rally.targetTreeIds?.isEmpty == true {
            let treeIds = try await fetchRallyTargetTreeIds(rallyId: rally.id)
            if !treeIds.isEmpty {
                rally = rally.withTargetTreeIds(treeIds)
            }
        }

        return rally
    }

    private func fetchRallyTargetTreeIds(rallyId: String) async throws -> [String] {
        let data = try await makeRequest(endpoint: "rally_targets?rally_id=eq.\(rallyId)&select=tree_id")

        struct TargetRow: Codable {
            let tree_id: String
        }

        let targets = try JSONDecoder().decode([TargetRow].self, from: data)
        return targets.map { $0.tree_id }
    }

    private func fetchRallyProgress(rallyId: String, deviceId: String) async throws -> RallyProgress? {
        let data = try await makeRequest(endpoint: "rally_progress?rally_id=eq.\(rallyId)&device_id=eq.\(deviceId)&select=*")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let progressList = try decoder.decode([RallyProgress].self, from: data)
        return progressList.first
    }

    private func fetchRallyStats(rallyId: String) async throws -> RallyStatistics {

        do {
            let params: [String: Any] = ["p_rally_id": rallyId]
            let data = try await rpcRequest(function: "get_rally_stats", params: params)

            let decoder = JSONDecoder()

            let stats = try await MainActor.run {
                try decoder.decode(RallyStatistics.self, from: data)
            }
            return stats
        } catch {

            return try await fetchRallyStatsManual(rallyId: rallyId)
        }
    }

    private func fetchRallyStatsManual(rallyId: String) async throws -> RallyStatistics {

        let participantsData = try await makeRequest(endpoint: "rally_participants?rally_id=eq.\(rallyId)&is_active=eq.true&select=display_name,platform,species_collected,trees_scanned")

        struct ParticipantRow: Codable {
            let display_name: String
            let platform: String
            let species_collected: Int
            let trees_scanned: Int
        }

        let participants = try JSONDecoder().decode([ParticipantRow].self, from: participantsData)

        let collectionsData = try await makeRequest(endpoint: "rally_collections?rally_id=eq.\(rallyId)&select=species")

        struct CollectionRow: Codable {
            let species: String
        }

        let collections = try JSONDecoder().decode([CollectionRow].self, from: collectionsData)
        let uniqueSpecies = Set(collections.map { $0.species })

        let topCollectors = participants
            .sorted { $0.species_collected > $1.species_collected }
            .prefix(5)
            .map { p in
                TopCollector(
                    name: p.display_name,
                    platform: p.platform,
                    speciesCount: p.species_collected,
                    treeCount: p.trees_scanned
                )
            }

        var speciesCounts: [String: Int] = [:]
        for collection in collections {
            speciesCounts[collection.species, default: 0] += 1
        }

        let mostCollected = speciesCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { SpeciesCount(species: $0.key, count: $0.value) }

        return RallyStatistics(
            totalParticipants: participants.count,
            totalTreesCollected: collections.count,
            totalUniqueSpecies: uniqueSpecies.count,
            topCollectors: Array(topCollectors),
            mostCollectedSpecies: Array(mostCollected)
        )
    }

    private func fetchLeaderboard(rallyId: String) async throws -> [LeaderboardEntry] {
        let data = try await makeRequest(endpoint: "rally_participants?rally_id=eq.\(rallyId)&order=species_collected.desc,trees_scanned.desc&select=device_id,display_name,platform,species_collected,trees_scanned")

        struct ParticipantRow: Codable {
            let device_id: String
            let display_name: String
            let platform: String
            let species_collected: Int
            let trees_scanned: Int
        }

        let participants = try JSONDecoder().decode([ParticipantRow].self, from: data)

        return participants.map { p in
            LeaderboardEntry(
                deviceId: p.device_id,
                displayName: p.display_name,
                platform: p.platform,
                speciesCollected: p.species_collected,
                treesScanned: p.trees_scanned,
                hasCompleted: false
            )
        }
    }

    func getRallyParticipants(rallyId: String) async -> RallyResult<[RallyParticipant]> {
        do {
            let data = try await makeRequest(endpoint: "rally_participants?rally_id=eq.\(rallyId)&is_active=eq.true&select=*")

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let participants = try decoder.decode([RallyParticipant].self, from: data)
            return .success(participants)
        } catch {
            return .error("Fehler beim Laden der Teilnehmer: \(error.localizedDescription)")
        }
    }

    func getRallyCollections(rallyId: String) async -> RallyResult<[RallyCollection]> {
        do {
            let data = try await makeRequest(endpoint: "rally_collections?rally_id=eq.\(rallyId)&select=*")

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let collections = try decoder.decode([RallyCollection].self, from: data)
            return .success(collections)
        } catch {
            return .error("Fehler beim Laden der Collections: \(error.localizedDescription)")
        }
    }

    func searchPublicRallies() async -> RallyResult<[Rally]> {
        do {
            let data = try await makeRequest(endpoint: "rallies?is_public=eq.true&status=eq.active&select=*")

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let rallies = try decoder.decode([Rally].self, from: data)
            return .success(rallies)
        } catch {
            return .error("Fehler beim Suchen der Rallies: \(error.localizedDescription)")
        }
    }

    private func updateParticipantStatus(rallyId: String, deviceId: String, isActive: Bool) async throws {
        let updateData: [String: Any] = ["is_active": isActive]
        let body = try JSONSerialization.data(withJSONObject: updateData)

        let _ = try await makeRequest(
            endpoint: "rally_participants?rally_id=eq.\(rallyId)&device_id=eq.\(deviceId)",
            method: "PATCH",
            body: body
        )
    }

    private func updateRallyStatus(rallyId: String, status: RallyStatus) async throws {
        let currentDeviceId = await deviceId
        let updateData: [String: Any] = [
            "status": status.rawValue,
            "ended_at": ISO8601DateFormatter().string(from: Date())
        ]
        let body = try JSONSerialization.data(withJSONObject: updateData)

        let _ = try await makeRequest(
            endpoint: "rallies?id=eq.\(rallyId)&creator_id=eq.\(currentDeviceId)",
            method: "PATCH",
            body: body
        )
    }
}

class RallyRealtimeManager: ObservableObject {
    @Published var currentState: RallyState = .idle
    @Published var recentEvents: [RallyEvent] = []
    @Published var participants: [RallyParticipant] = []
    @Published var collections: [RallyCollection] = []
    @Published var lastUpdate: Date = Date()

    private var rallyId: String?
    private var pollingTask: Task<Void, Never>?
    private let pollingInterval: TimeInterval = 5.0

    private var previousParticipantIds = Set<String>()
    private var previousCollectionIds = Set<String>()

    func subscribeToRally(rallyId: String) {
        self.rallyId = rallyId
        currentState = .loading

        pollingTask?.cancel()
        pollingTask = Task {
            await startPolling()
        }
    }

    func unsubscribe() {
        pollingTask?.cancel()
        pollingTask = nil
        rallyId = nil
        currentState = .idle
        participants = []
        collections = []
        previousParticipantIds = []
        previousCollectionIds = []
    }

    private func startPolling() async {
        guard let rallyId = rallyId else { return }

        while !Task.isCancelled {
            await fetchUpdates(for: rallyId)

            try? await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
        }
    }

    private func fetchUpdates(for rallyId: String) async {

        let participantsResult = await SupabaseService.shared.getRallyParticipants(rallyId: rallyId)
        if case .success(let newParticipants) = participantsResult {
            await MainActor.run {

                let newIds = Set(newParticipants.map { $0.id })
                let addedParticipants = newParticipants.filter { !previousParticipantIds.contains($0.id) }
                let removedIds = previousParticipantIds.subtracting(newIds)

                for participant in addedParticipants {
                    if !previousParticipantIds.isEmpty {
                        currentState = .participantJoined(participant)
                    }
                }

                for removedId in removedIds {
                    if let removed = participants.first(where: { $0.id == removedId }) {
                        currentState = .participantLeft(removed)
                    }
                }

                self.participants = newParticipants
                self.previousParticipantIds = newIds
                self.lastUpdate = Date()

                if currentState == .loading {
                    currentState = .idle
                }
            }
        }

        let collectionsResult = await SupabaseService.shared.getRallyCollections(rallyId: rallyId)
        if case .success(let newCollections) = collectionsResult {
            await MainActor.run {

                let newIds = Set(newCollections.map { $0.id })
                let addedCollections = newCollections.filter { !previousCollectionIds.contains($0.id) }

                for collection in addedCollections {
                    if !previousCollectionIds.isEmpty {
                        currentState = .treeCollected(collection)
                    }
                }

                self.collections = newCollections
                self.previousCollectionIds = newIds
            }
        }
    }

    func refresh() async {
        guard let rallyId = rallyId else { return }
        await fetchUpdates(for: rallyId)
    }
}
