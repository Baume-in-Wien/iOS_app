import Foundation

actor CommunityTreeService {
    static let shared = CommunityTreeService()

    private let supabaseURL = "https://awkwclebcnzgvpnmypwd.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF3a3djbGViY256Z3Zwbm15cHdkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjcxNTU2ODgsImV4cCI6MjA4MjczMTY4OH0.z29RXjO5wZxt0BKZsZINs_9bnpF25439fUbN3U3A-qc"

    func getCommunityTreesInBounds(
        minLat: Double, maxLat: Double,
        minLon: Double, maxLon: Double
    ) async -> [CommunityTree] {
        let params: [String: Any] = [
            "p_min_lat": minLat,
            "p_max_lat": maxLat,
            "p_min_lon": minLon,
            "p_max_lon": maxLon,
            "p_limit": 500
        ]

        do {
            let data = try await rpcRequest(function: "get_community_trees_in_bounds", params: params)
            return try JSONDecoder().decode([CommunityTree].self, from: data)
        } catch {
            print("CommunityTreeService: Failed to load trees in bounds: \(error)")
            return []
        }
    }

    func addCommunityTree(_ insert: CommunityTreeInsert) async throws -> CommunityTree {
        let body = try JSONEncoder().encode(insert)
        let data = try await makeAuthenticatedRequest(
            endpoint: "community_trees",
            method: "POST",
            body: body
        )

        let trees = try JSONDecoder().decode([CommunityTree].self, from: data)
        guard let tree = trees.first else {
            throw NSError(domain: "CommunityTreeService", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Kein Baum in Antwort"])
        }
        return tree
    }

    func searchSpecies(query: String) async -> [TreeSpecies] {
        guard query.count >= 2 else { return [] }

        do {
            let params: [String: Any] = [
                "p_query": query,
                "p_limit": 20
            ]
            let data = try await rpcRequest(function: "search_tree_species", params: params)
            let species = try JSONDecoder().decode([TreeSpecies].self, from: data)
            if !species.isEmpty { return species }
        } catch {
            print("CommunityTreeService: RPC search unavailable, using fallback: \(error)")
        }

        let lowerQuery = query.lowercased()
        return Self.commonViennaSpecies.filter { species in
            species.nameGerman.lowercased().contains(lowerQuery) ||
            (species.nameScientific?.lowercased().contains(lowerQuery) ?? false)
        }.prefix(20).map { $0 }
    }

    func confirmTree(treeId: String, userId: String) async throws {
        let body: [String: Any] = [
            "tree_id": treeId,
            "user_id": userId
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let _ = try await makeAuthenticatedRequest(
            endpoint: "community_tree_confirmations",
            method: "POST",
            body: bodyData
        )
    }

    func reportTree(treeId: String, reporterId: String, reason: String, comment: String?) async throws {
        var body: [String: Any] = [
            "tree_id": treeId,
            "reporter_id": reporterId,
            "reason": reason
        ]
        if let comment = comment {
            body["comment"] = comment
        }
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let _ = try await makeAuthenticatedRequest(
            endpoint: "community_tree_reports",
            method: "POST",
            body: bodyData
        )
    }

    func deleteCommunityTree(treeId: String, userId: String) async throws {
        let _ = try await makeAuthenticatedRequest(
            endpoint: "community_trees?id=eq.\(treeId)&user_id=eq.\(userId)",
            method: "DELETE"
        )
    }

    func getUserProfile(userId: String) async -> UserProfile? {
        do {
            let data = try await makeRequest(endpoint: "user_profiles?id=eq.\(userId)&select=*")
            let profiles = try JSONDecoder().decode([UserProfile].self, from: data)
            return profiles.first
        } catch {
            print("CommunityTreeService: Failed to get user profile: \(error)")
            return nil
        }
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
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "CommunityTreeService", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        return data
    }

    private func makeAuthenticatedRequest(endpoint: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        let token = await MainActor.run { AuthService.shared.accessToken }

        guard let url = URL(string: "\(supabaseURL)/rest/v1/\(endpoint)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"

            if errorMessage.contains("23505") || errorMessage.contains("unique") || errorMessage.contains("duplicate") {
                let userMsg = errorMessage.contains("confirmation") ?
                    "Du hast diesen Baum bereits bestätigt" :
                    "Du hast diesen Baum bereits gemeldet"
                throw NSError(domain: "CommunityTreeService", code: 409,
                              userInfo: [NSLocalizedDescriptionKey: userMsg])
            }

            throw NSError(domain: "CommunityTreeService", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: errorMessage])
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

        let token = await MainActor.run { AuthService.shared.accessToken }
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: params)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "CommunityTreeRPC", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        return data
    }

    static let commonViennaSpecies: [TreeSpecies] = [
        TreeSpecies(id: 1, nameGerman: "Spitzahorn", nameScientific: "Acer platanoides", category: "Laubbaum"),
        TreeSpecies(id: 2, nameGerman: "Bergahorn", nameScientific: "Acer pseudoplatanus", category: "Laubbaum"),
        TreeSpecies(id: 3, nameGerman: "Feldahorn", nameScientific: "Acer campestre", category: "Laubbaum"),
        TreeSpecies(id: 4, nameGerman: "Silberahorn", nameScientific: "Acer saccharinum", category: "Laubbaum"),
        TreeSpecies(id: 5, nameGerman: "Rosskastanie", nameScientific: "Aesculus hippocastanum", category: "Laubbaum"),
        TreeSpecies(id: 6, nameGerman: "Rotbuche", nameScientific: "Fagus sylvatica", category: "Laubbaum"),
        TreeSpecies(id: 7, nameGerman: "Hainbuche", nameScientific: "Carpinus betulus", category: "Laubbaum"),
        TreeSpecies(id: 8, nameGerman: "Winterlinde", nameScientific: "Tilia cordata", category: "Laubbaum"),
        TreeSpecies(id: 9, nameGerman: "Sommerlinde", nameScientific: "Tilia platyphyllos", category: "Laubbaum"),
        TreeSpecies(id: 10, nameGerman: "Silberlinde", nameScientific: "Tilia tomentosa", category: "Laubbaum"),
        TreeSpecies(id: 11, nameGerman: "Stieleiche", nameScientific: "Quercus robur", category: "Laubbaum"),
        TreeSpecies(id: 12, nameGerman: "Traubeneiche", nameScientific: "Quercus petraea", category: "Laubbaum"),
        TreeSpecies(id: 13, nameGerman: "Roteiche", nameScientific: "Quercus rubra", category: "Laubbaum"),
        TreeSpecies(id: 14, nameGerman: "Gemeine Esche", nameScientific: "Fraxinus excelsior", category: "Laubbaum"),
        TreeSpecies(id: 15, nameGerman: "Platane", nameScientific: "Platanus x acerifolia", category: "Laubbaum"),
        TreeSpecies(id: 16, nameGerman: "Gemeine Birke", nameScientific: "Betula pendula", category: "Laubbaum"),
        TreeSpecies(id: 17, nameGerman: "Robinie", nameScientific: "Robinia pseudoacacia", category: "Laubbaum"),
        TreeSpecies(id: 18, nameGerman: "Vogelkirsche", nameScientific: "Prunus avium", category: "Laubbaum"),
        TreeSpecies(id: 19, nameGerman: "Walnuss", nameScientific: "Juglans regia", category: "Laubbaum"),
        TreeSpecies(id: 20, nameGerman: "Ginkgo", nameScientific: "Ginkgo biloba", category: "Laubbaum"),
        TreeSpecies(id: 21, nameGerman: "Götterbaum", nameScientific: "Ailanthus altissima", category: "Laubbaum"),
        TreeSpecies(id: 22, nameGerman: "Schwarzkiefer", nameScientific: "Pinus nigra", category: "Nadelbaum"),
        TreeSpecies(id: 23, nameGerman: "Gemeine Fichte", nameScientific: "Picea abies", category: "Nadelbaum"),
        TreeSpecies(id: 24, nameGerman: "Eibe", nameScientific: "Taxus baccata", category: "Nadelbaum"),
        TreeSpecies(id: 25, nameGerman: "Apfelbaum", nameScientific: "Malus domestica", category: "Obstbaum"),
    ]
}
