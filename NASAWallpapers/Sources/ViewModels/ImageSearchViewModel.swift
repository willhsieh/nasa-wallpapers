import Foundation
import SwiftUI
import Combine

@MainActor
class ImageSearchViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var searchResults: [UnifiedImageResult] = []
    @Published var selectedItem: UnifiedImageResult?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var totalHits: Int = 0
    
    // Search parameters
    @Published var query: String = ""
    @Published var mediaType: MediaType = .image
    @Published var yearStart: String = ""
    @Published var yearEnd: String = ""
    @Published var center: String = ""
    
    // Source selection (checklist)
    @Published var enabledSources: Set<ImageSource> = Set(ImageSource.allCases)
    
    // Download state
    @Published var isDownloading = false
    @Published var downloadProgress: String?
    
    // Pagination (NASA Library only)
    @Published var currentPage = 1
    @Published var hasMorePages = false
    
    // Per-source loading status
    @Published var sourceStatus: [ImageSource: SourceLoadStatus] = [:]
    
    private let nasaAPI = NASAAPIService.shared
    private let esaAPI = ESAImageService.shared
    
    enum SourceLoadStatus {
        case idle
        case loading
        case loaded(Int)
        case error(String)
    }
    
    // MARK: - Search
    
    func search() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty else { return }
        guard !enabledSources.isEmpty else {
            errorMessage = "Select at least one source"
            return
        }
        
        isLoading = true
        errorMessage = nil
        currentPage = 1
        searchResults = []
        selectedItem = nil
        totalHits = 0
        hasMorePages = false
        sourceStatus = [:]
        
        // Search all enabled sources in parallel
        await withTaskGroup(of: (ImageSource, [UnifiedImageResult]?, String?).self) { group in
            for source in enabledSources {
                sourceStatus[source] = .loading
                group.addTask { [self] in
                    do {
                        let results = try await self.searchSource(source, query: trimmedQuery)
                        return (source, results, nil)
                    } catch {
                        return (source, nil, error.localizedDescription)
                    }
                }
            }
            
            for await (source, results, error) in group {
                if let results {
                    searchResults.append(contentsOf: results)
                    totalHits += results.count
                    sourceStatus[source] = .loaded(results.count)
                } else if let error {
                    sourceStatus[source] = .error(error)
                }
            }
        }
        
        // Sort by date descending
        searchResults.sort { a, b in
            (a.dateString ?? "") > (b.dateString ?? "")
        }
        
        if let first = searchResults.first {
            selectedItem = first
        }
        
        isLoading = false
    }
    
    private func searchSource(_ source: ImageSource, query: String) async throws -> [UnifiedImageResult] {
        switch source {
        case .nasaLibrary:
            var params = SearchParameters()
            params.query = query
            params.mediaType = mediaType
            
            if let year = Int(yearStart), year >= 1900, year <= 2100 {
                params.yearStart = year
            }
            if let year = Int(yearEnd), year >= 1900, year <= 2100 {
                params.yearEnd = year
            }
            if !center.isEmpty {
                params.center = center
            }
            
            let response = try await nasaAPI.search(params: params, page: 1)
            
            // Update pagination state on main actor
            await MainActor.run {
                hasMorePages = response.collection.links?.contains(where: { $0.rel == "next" }) ?? false
            }
            
            return response.collection.items.map { $0.toUnified() }
            
        case .esaWebb, .esaHubble:
            return try await esaAPI.search(query: query, source: source)
        }
    }
    
    // MARK: - Load More (NASA Library only)
    
    func loadMore() async {
        guard hasMorePages, !isLoading, enabledSources.contains(.nasaLibrary) else { return }
        
        isLoading = true
        currentPage += 1
        
        var params = SearchParameters()
        params.query = query
        params.mediaType = mediaType
        
        if let year = Int(yearStart), year >= 1900, year <= 2100 {
            params.yearStart = year
        }
        if let year = Int(yearEnd), year >= 1900, year <= 2100 {
            params.yearEnd = year
        }
        if !center.isEmpty {
            params.center = center
        }
        
        do {
            let response = try await nasaAPI.search(params: params, page: currentPage)
            let newResults = response.collection.items.map { $0.toUnified() }
            searchResults.append(contentsOf: newResults)
            totalHits += newResults.count
            hasMorePages = response.collection.links?.contains(where: { $0.rel == "next" }) ?? false
        } catch {
            errorMessage = error.localizedDescription
            currentPage -= 1
        }
        
        isLoading = false
    }
    
    // MARK: - Download Original
    
    func downloadOriginal() async {
        guard let item = selectedItem else { return }
        
        isDownloading = true
        downloadProgress = "Fetching asset info..."
        
        do {
            let downloadURL: URL?
            
            switch item.source {
            case .nasaLibrary:
                if let nasaId = item.nasaId {
                    downloadURL = try await nasaAPI.getOriginalImageURL(nasaId: nasaId)
                } else {
                    downloadURL = item.originalURL
                }
            case .esaWebb, .esaHubble:
                // Prefer wallpaper5 > large > original
                downloadURL = item.downloadFormats["wallpaper5"]
                    ?? item.downloadFormats["large"]
                    ?? item.originalURL
            }
            
            guard let url = downloadURL else {
                downloadProgress = "No original found"
                isDownloading = false
                return
            }
            
            downloadProgress = "Downloading..."
            
            let config = URLSessionConfiguration.default
            let session = URLSession(configuration: config)
            let (tempURL, _) = try await session.download(from: url)
            
            let panel = NSSavePanel()
            panel.nameFieldStringValue = url.lastPathComponent
            panel.allowedContentTypes = [.image, .jpeg, .png, .tiff]
            panel.canCreateDirectories = true
            
            if let window = NSApp.keyWindow {
                let response = await panel.beginSheetModal(for: window)
                if response == .OK, let saveURL = panel.url {
                    try FileManager.default.moveItem(at: tempURL, to: saveURL)
                    downloadProgress = "Downloaded!"
                } else {
                    try? FileManager.default.removeItem(at: tempURL)
                    downloadProgress = nil
                }
            } else {
                try? FileManager.default.removeItem(at: tempURL)
                downloadProgress = nil
            }
        } catch {
            downloadProgress = "Error: \(error.localizedDescription)"
        }
        
        isDownloading = false
        
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        if !isDownloading {
            downloadProgress = nil
        }
    }
    
    // MARK: - Clear
    
    func clearFilters() {
        query = ""
        yearStart = ""
        yearEnd = ""
        center = ""
        mediaType = .image
    }
    
    // MARK: - Toggle Source
    
    func toggleSource(_ source: ImageSource) {
        if enabledSources.contains(source) {
            enabledSources.remove(source)
        } else {
            enabledSources.insert(source)
        }
    }
}
