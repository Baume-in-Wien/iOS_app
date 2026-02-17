import Foundation

struct WikipediaSummary: Codable {
    let title: String
    let extract: String
    let thumbnail: WikipediaImage?
    let originalimage: WikipediaImage?
    let content_urls: WikipediaURLs?
}

struct WikipediaImage: Codable {
    let source: String
    let width: Int
    let height: Int
}

struct WikipediaURLs: Codable {
    let desktop: WikipediaPageURL?
    let mobile: WikipediaPageURL?
}

struct WikipediaPageURL: Codable {
    let page: String
}

class WikipediaService {
    static let shared = WikipediaService()

    private let baseURL = "https://de.wikipedia.org/api/rest_v1/page/summary/"

    func fetchSummary(for title: String) async throws -> WikipediaSummary? {

        var cleanTitle = title
        if let parenIndex = title.firstIndex(of: "(") {
            cleanTitle = String(title[..<parenIndex])
        }
        cleanTitle = cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let formattedTitle = cleanTitle.replacingOccurrences(of: " ", with: "_")

        if let summary = await fetch(title: formattedTitle) {
            return summary
        }

        let hyphenTitle = formattedTitle.replacingOccurrences(of: "-", with: "_")
        if hyphenTitle != formattedTitle, let summary = await fetch(title: hyphenTitle) {
            return summary
        }

        let noHyphenTitle = cleanTitle.replacingOccurrences(of: "-", with: "")
        if noHyphenTitle != cleanTitle, let summary = await fetch(title: noHyphenTitle) {
            return summary
        }

        return nil
    }

    private func fetch(title: String) async -> WikipediaSummary? {
        guard let url = URL(string: baseURL + title) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("BaumkatasterApp/1.0 (pauli@example.com)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(WikipediaSummary.self, from: data)
        } catch {
            return nil
        }
    }
}
