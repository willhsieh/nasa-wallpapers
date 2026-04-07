import Foundation

actor NASAAPIService {
    static let shared = NASAAPIService()
    
    private let baseURL = "https://images-api.nasa.gov"
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Search
    
    func search(params: SearchParameters, page: Int = 1) async throws -> NASASearchResponse {
        var components = URLComponents(string: "\(baseURL)/search")!
        var queryItems: [URLQueryItem] = []
        
        if !params.query.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: params.query))
        }
        
        queryItems.append(URLQueryItem(name: "media_type", value: params.mediaType.rawValue))
        
        if let yearStart = params.yearStart {
            queryItems.append(URLQueryItem(name: "year_start", value: String(yearStart)))
        }
        
        if let yearEnd = params.yearEnd {
            queryItems.append(URLQueryItem(name: "year_end", value: String(yearEnd)))
        }
        
        if !params.center.isEmpty {
            queryItems.append(URLQueryItem(name: "center", value: params.center))
        }
        
        queryItems.append(URLQueryItem(name: "page", value: String(page)))
        queryItems.append(URLQueryItem(name: "page_size", value: "100"))
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw NASAAPIError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NASAAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NASAAPIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(NASASearchResponse.self, from: data)
    }
    
    // MARK: - Get Asset Manifest (for original download URLs)
    
    func getAssetManifest(nasaId: String) async throws -> [String] {
        let urlString = "\(baseURL)/asset/\(nasaId)"
        guard let url = URL(string: urlString) else {
            throw NASAAPIError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NASAAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NASAAPIError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let assetResponse = try decoder.decode(NASAAssetResponse.self, from: data)
        
        return assetResponse.collection.items.compactMap { $0.href }
    }
    
    // MARK: - Get Original Image URL
    
    func getOriginalImageURL(nasaId: String) async throws -> URL? {
        let assets = try await getAssetManifest(nasaId: nasaId)
        
        // Prefer ~orig, then ~large, then the largest available
        let priorities = ["~orig.", "~large.", "~medium."]
        
        for priority in priorities {
            if let match = assets.first(where: { $0.contains(priority) }) {
                return URL(string: match)
            }
        }
        
        // Fallback to first image asset
        if let first = assets.first(where: { $0.hasSuffix(".jpg") || $0.hasSuffix(".png") || $0.hasSuffix(".tif") || $0.hasSuffix(".tiff") }) {
            return URL(string: first)
        }
        
        return nil
    }
}

// MARK: - Errors

enum NASAAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case noData
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .noData:
            return "No data received"
        }
    }
}
