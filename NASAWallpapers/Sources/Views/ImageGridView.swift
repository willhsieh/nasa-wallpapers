import SwiftUI

struct ImageGridView: View {
    @ObservedObject var viewModel: ImageSearchViewModel
    
    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 16)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Results Header
            if viewModel.totalHits > 0 || viewModel.isLoading {
                HStack {
                    if viewModel.isLoading && viewModel.searchResults.isEmpty {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                        Text("Searching...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(viewModel.totalHits.formatted()) results")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.bar)
            }
            
            // MARK: - Grid Content
            if viewModel.searchResults.isEmpty && !viewModel.isLoading {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.searchResults) { item in
                            ImageGridCell(item: item, isSelected: viewModel.selectedItem?.id == item.id)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        viewModel.selectedItem = item
                                    }
                                }
                                .onAppear {
                                    if item.id == viewModel.searchResults.last?.id {
                                        Task { await viewModel.loadMore() }
                                    }
                                }
                        }
                    }
                    .padding(20)
                    
                    if viewModel.isLoading && !viewModel.searchResults.isEmpty {
                        ProgressView()
                            .padding()
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Search Space Imagery")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Enter a query and press Search to explore\nimages from NASA, Webb, and Hubble.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Grid Cell

struct ImageGridCell: View {
    let item: UnifiedImageResult
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Thumbnail
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: item.thumbnailURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                            .aspectRatio(4/3, contentMode: .fit)
                            .overlay {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                    case .success(let image):
                        GeometryReader { geo in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                        }
                        .frame(height: 160)
                        .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                            .aspectRatio(4/3, contentMode: .fit)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundStyle(.tertiary)
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
                // Source badge
                Text(item.sourceBadge)
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(6)
            }
            
            // Title & metadata
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack(spacing: 4) {
                    let date = item.shortDate
                    if !date.isEmpty {
                        Text(date)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let center = item.center ?? item.instrument {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(center)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
    }
}
