import Foundation

actor ESAImageService {
    static let shared = ESAImageService()
    
    private let session: URLSession
    
    // Cached catalogs
    private var webbCatalog: [ESAImageEntry]?
    private var hubbleCatalog: [ESAImageEntry]?
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Fetch Full Catalog
    
    private func fetchCatalog(source: ImageSource) async throws -> [ESAImageEntry] {
        let urlString: String
        switch source {
        case .esaWebb:
            if let cached = webbCatalog { return cached }
            urlString = "https://esawebb.org/images/json/"
        case .esaHubble:
            if let cached = hubbleCatalog { return cached }
            urlString = "https://esahubble.org/images/json/"
        default:
            return []
        }
        
        guard let url = URL(string: urlString) else {
            throw NASAAPIError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NASAAPIError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        // Resilient decoding: parse each entry individually, skip failures
        let entries = Self.resilientDecode([ESAImageEntry].self, from: data, using: decoder)
        
        // Cache
        switch source {
        case .esaWebb: webbCatalog = entries
        case .esaHubble: hubbleCatalog = entries
        default: break
        }
        
        return entries
    }
    
    // MARK: - Search
    
    func search(query: String, source: ImageSource) async throws -> [UnifiedImageResult] {
        let catalog = try await fetchCatalog(source: source)
        
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            // Return all, sorted by date descending
            return catalog.map { $0.toUnified(source: source) }
        }
        
        let lowercasedQuery = query.lowercased()
        let queryTokens = lowercasedQuery.split(separator: " ").map(String.init)
        
        let filtered = catalog.filter { entry in
            let title = entry.Title?.lowercased() ?? ""
            let desc = entry.Description?.lowercased() ?? ""
            let id = entry.ID?.lowercased() ?? ""
            let facilities = entry.Facility?.values.joined(separator: " ").lowercased() ?? ""
            let instruments = entry.Instrument?.values.joined(separator: " ").lowercased() ?? ""
            let searchable = "\(title) \(desc) \(id) \(facilities) \(instruments)"
            
            // All query tokens must match somewhere
            return queryTokens.allSatisfy { token in
                searchable.contains(token)
            }
        }
        
        return filtered.map { $0.toUnified(source: source) }
    }
    
    // MARK: - Cache Management
    
    func clearCache() {
        webbCatalog = nil
        hubbleCatalog = nil
    }
    
    // MARK: - Resilient Decoding
    
    private static func resilientDecode<T: Decodable>(_ type: [T].Type, from data: Data, using decoder: JSONDecoder) -> [T] {
        // First try normal decoding
        if let result = try? decoder.decode([T].self, from: data) {
            return result
        }
        
        // Fall back to per-element decoding
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        
        var results: [T] = []
        for element in jsonArray {
            guard let elementData = try? JSONSerialization.data(withJSONObject: element) else { continue }
            if let decoded = try? decoder.decode(T.self, from: elementData) {
                results.append(decoded)
            }
        }
        
        return results
    }
}
