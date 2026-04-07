import Foundation

// MARK: - Image Source

enum ImageSource: String, CaseIterable, Identifiable, Codable {
    case nasaLibrary = "NASA Library"
    case esaWebb = "ESA/Webb"
    case esaHubble = "ESA/Hubble"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var iconName: String {
        switch self {
        case .nasaLibrary: return "building.columns"
        case .esaWebb: return "sparkles"
        case .esaHubble: return "moon.stars"
        }
    }
    
    var description: String {
        switch self {
        case .nasaLibrary: return "NASA media archive (press, events, missions)"
        case .esaWebb: return "James Webb Space Telescope imagery"
        case .esaHubble: return "Hubble Space Telescope imagery"
        }
    }
}

// MARK: - Unified Image Result

struct UnifiedImageResult: Identifiable {
    let id: String
    let source: ImageSource
    let title: String
    let description: String?
    let dateString: String?
    let thumbnailURL: URL?
    let previewURL: URL?
    let originalURL: URL?
    let credit: String?
    let keywords: [String]
    
    // Source-specific metadata
    let center: String?
    let photographer: String?
    let location: String?
    let nasaId: String?
    let instrument: String?
    let facility: String?
    let referenceURL: String?
    
    // ESA-specific: multiple download formats
    let downloadFormats: [String: URL]
    
    var formattedDate: String {
        guard let dateString else { return "Unknown date" }
        return Self.formatDate(dateString, style: "MMMM d, yyyy")
    }
    
    var shortDate: String {
        guard let dateString else { return "" }
        return Self.formatDate(dateString, style: "MMM d, yyyy")
    }
    
    var sourceBadge: String {
        switch source {
        case .nasaLibrary: return "NASA"
        case .esaWebb: return "Webb"
        case .esaHubble: return "Hubble"
        }
    }
    
    static func formatDate(_ dateString: String, style: String) -> String {
        let formatters: [(String, ISO8601DateFormatter.Options)] = [
            (dateString, [.withInternetDateTime, .withFractionalSeconds]),
            (dateString, [.withInternetDateTime]),
        ]
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = style
        
        for (_, options) in formatters {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = options
            if let date = isoFormatter.date(from: dateString) {
                return displayFormatter.string(from: date)
            }
        }
        
        // Try yyyy-MM-dd'T'HH:mm:ss (no timezone, as ESA uses)
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = fallbackFormatter.date(from: dateString) {
            return displayFormatter.string(from: date)
        }
        
        // Try just date portion
        if dateString.count >= 10 {
            let dateOnly = String(dateString.prefix(10))
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            if let date = df.date(from: dateOnly) {
                return displayFormatter.string(from: date)
            }
        }
        
        return dateString
    }
}

// MARK: - NASA Image and Video Library API Response Models

struct NASASearchResponse: Codable {
    let collection: NASACollection
}

struct NASACollection: Codable {
    let version: String?
    let href: String?
    let items: [NASAItem]
    let metadata: NASAMetadata?
    let links: [NASACollectionLink]?
}

struct NASAMetadata: Codable {
    let totalHits: Int?
    
    enum CodingKeys: String, CodingKey {
        case totalHits = "total_hits"
    }
}

struct NASACollectionLink: Codable {
    let rel: String?
    let prompt: String?
    let href: String?
}

struct NASAItem: Codable, Identifiable {
    let href: String?
    let data: [NASAItemData]
    let links: [NASAItemLink]?
    
    var id: String {
        data.first?.nasaId ?? UUID().uuidString
    }
    
    var thumbnailURL: URL? {
        guard let link = links?.first(where: { $0.rel == "preview" }),
              let href = link.href else { return nil }
        return URL(string: href)
    }
    
    var metadata: NASAItemData? {
        data.first
    }
}

struct NASAItemData: Codable {
    let center: String?
    let title: String?
    let nasaId: String?
    let dateCreated: String?
    let mediaType: String?
    let description: String?
    let keywords: [String]?
    let photographer: String?
    let location: String?
    let secondaryCreator: String?
    let album: [String]?
    
    enum CodingKeys: String, CodingKey {
        case center, title
        case nasaId = "nasa_id"
        case dateCreated = "date_created"
        case mediaType = "media_type"
        case description, keywords, photographer, location
        case secondaryCreator = "secondary_creator"
        case album
    }
    
    var formattedDate: String {
        guard let dateString = dateCreated else { return "Unknown date" }
        return UnifiedImageResult.formatDate(dateString, style: "MMMM d, yyyy")
    }
    
    var shortDate: String {
        guard let dateString = dateCreated else { return "" }
        return UnifiedImageResult.formatDate(dateString, style: "MMM d, yyyy")
    }
}

struct NASAItemLink: Codable {
    let href: String?
    let rel: String?
    let render: String?
}

// MARK: - Asset Manifest Response

struct NASAAssetResponse: Codable {
    let collection: NASAAssetCollection
}

struct NASAAssetCollection: Codable {
    let version: String?
    let href: String?
    let items: [NASAAssetItem]
}

struct NASAAssetItem: Codable {
    let href: String?
}

// MARK: - NASAItem -> UnifiedImageResult

extension NASAItem {
    func toUnified() -> UnifiedImageResult {
        let meta = metadata
        return UnifiedImageResult(
            id: "nasa-\(id)",
            source: .nasaLibrary,
            title: meta?.title ?? "Untitled",
            description: meta?.description,
            dateString: meta?.dateCreated,
            thumbnailURL: thumbnailURL,
            previewURL: thumbnailURL,
            originalURL: nil,
            credit: meta?.secondaryCreator,
            keywords: meta?.keywords ?? [],
            center: meta?.center,
            photographer: meta?.photographer ?? meta?.secondaryCreator,
            location: meta?.location,
            nasaId: meta?.nasaId,
            instrument: nil,
            facility: nil,
            referenceURL: nil,
            downloadFormats: [:]
        )
    }
}

// MARK: - ESA Image Models

struct ESAImageEntry: Codable {
    let Title: String?
    let Description: String?
    let Date: String?
    let ID: String?
    let ImageType: String?
    let Credit: String?
    let ReferenceURL: String?
    let Facility: CodableStringOrArray?
    let Instrument: CodableStringOrArray?
    let ResourceURL: String?
    
    // We need custom handling for formats_url
    let formats_url: [String: String]?
    let Resources: [ESAResource]?
    
    // Subject info
    let Distance: CodableStringOrArray?
    
    enum CodingKeys: String, CodingKey {
        case Title, Description, Date, ID
        case ImageType = "Type"
        case Credit, ReferenceURL, Facility, Instrument, ResourceURL
        case formats_url, Resources, Distance
    }
    
    func toUnified(source: ImageSource) -> UnifiedImageResult {
        let thumbURL: URL? = {
            if let urlStr = formats_url?["thumb300y"] ?? formats_url?["thumb350x"] ?? formats_url?["screen640"] {
                return URL(string: urlStr)
            }
            return nil
        }()
        
        let previewURL: URL? = {
            if let urlStr = formats_url?["screen"] ?? formats_url?["large"] {
                return URL(string: urlStr)
            }
            return nil
        }()
        
        let originalURL: URL? = {
            if let urlStr = formats_url?["large"] ?? ResourceURL {
                return URL(string: urlStr)
            }
            return nil
        }()
        
        // Build download formats
        var downloads: [String: URL] = [:]
        if let formats = formats_url {
            let desiredFormats = ["wallpaper5", "wallpaper4", "wallpaper3", "wallpaper2", "wallpaper1", "large", "screen", "original"]
            for key in desiredFormats {
                if let urlStr = formats[key], let url = URL(string: urlStr) {
                    downloads[key] = url
                }
            }
        }
        
        // Clean description (remove b' prefix artifacts)
        let cleanDesc = cleanByteString(Description)
        let cleanTitle = cleanByteString(Title) ?? "Untitled"
        let cleanCredit = cleanByteString(Credit)
        
        let facilities = Facility?.values ?? []
        let instruments = Instrument?.values ?? []
        let uniqueInstruments = Array(Set(instruments)).sorted()
        let uniqueFacilities = Array(Set(facilities)).sorted()
        
        return UnifiedImageResult(
            id: "\(source.rawValue)-\(ID ?? UUID().uuidString)",
            source: source,
            title: cleanTitle,
            description: cleanDesc,
            dateString: Date,
            thumbnailURL: thumbURL,
            previewURL: previewURL,
            originalURL: originalURL,
            credit: cleanCredit,
            keywords: [],
            center: nil,
            photographer: cleanCredit,
            location: nil,
            nasaId: ID,
            instrument: uniqueInstruments.isEmpty ? nil : uniqueInstruments.joined(separator: ", "),
            facility: uniqueFacilities.isEmpty ? nil : uniqueFacilities.joined(separator: ", "),
            referenceURL: ReferenceURL,
            downloadFormats: downloads
        )
    }
    
    private func cleanByteString(_ str: String?) -> String? {
        guard var s = str else { return nil }
        if s.hasPrefix("b'") && s.hasSuffix("'") {
            s = String(s.dropFirst(2).dropLast())
        }
        if s.hasPrefix("b\"") && s.hasSuffix("\"") {
            s = String(s.dropFirst(2).dropLast())
        }
        // Decode common escape sequences
        s = s.replacingOccurrences(of: "\\xe2\\x80\\x99", with: "\u{2019}")
        s = s.replacingOccurrences(of: "\\xe2\\x80\\x98", with: "\u{2018}")
        s = s.replacingOccurrences(of: "\\xe2\\x80\\x93", with: "\u{2013}")
        s = s.replacingOccurrences(of: "\\xe2\\x80\\x94", with: "\u{2014}")
        s = s.replacingOccurrences(of: "\\xc2\\xa0", with: " ")
        s = s.replacingOccurrences(of: "\\n", with: "\n")
        return s.isEmpty ? nil : s
    }
}

struct ESAResource: Codable {
    let ResourceType: String?
    let MediaType: String?
    let URL: String?
    let FileSize: Int?
    let Dimensions: [CodableNumber]?
}

// Helper to decode mixed string/array JSON fields
enum CodableStringOrArray: Codable {
    case string(String)
    case array([String?])
    
    var values: [String] {
        switch self {
        case .string(let s): return [s]
        case .array(let arr): return arr.compactMap { $0 }
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let arr = try? container.decode([String?].self) {
            self = .array(arr)
        } else if let str = try? container.decode(String.self) {
            self = .string(str)
        } else {
            self = .array([])
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .array(let a): try container.encode(a)
        }
    }
}

enum CodableNumber: Codable {
    case int(Int)
    case double(Double)
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else {
            self = .null
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - Search Parameters

struct SearchParameters {
    var query: String = ""
    var mediaType: MediaType = .image
    var yearStart: Int? = nil
    var yearEnd: Int? = nil
    var center: String = ""
}

enum MediaType: String, CaseIterable {
    case image
    case video
    case audio
    
    var displayName: String {
        switch self {
        case .image: return "Images"
        case .video: return "Video"
        case .audio: return "Audio"
        }
    }
}
