import SwiftUI
import AppKit

struct ImageDetailPanel: View {
    let item: UnifiedImageResult
    @ObservedObject var viewModel: ImageSearchViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: - Preview Image
                AsyncImage(url: item.previewURL ?? item.thumbnailURL) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                            .aspectRatio(4/3, contentMode: .fit)
                            .overlay { ProgressView() }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxHeight: 240)
                            .clipped()
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                            .aspectRatio(4/3, contentMode: .fit)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.title)
                                    .foregroundStyle(.tertiary)
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(16)
                
                // MARK: - Title
                Text(item.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                
                // MARK: - Metadata Table
                metadataSection
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                
                // MARK: - Description
                if let description = item.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                
                // MARK: - Keywords
                if !item.keywords.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Keywords")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        FlowLayout(spacing: 6) {
                            ForEach(item.keywords, id: \.self) { keyword in
                                Text(keyword)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.gray.opacity(0.12))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                
                // MARK: - Download Button
                Button(action: {
                    Task { await viewModel.downloadOriginal() }
                }) {
                    HStack {
                        if viewModel.isDownloading {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                        }
                        Text(viewModel.downloadProgress ?? "Download Original")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(viewModel.isDownloading)
                .padding(.horizontal, 16)
                
                // MARK: - Reference Link
                if let refURL = item.referenceURL, let url = URL(string: refURL) {
                    Link(destination: url) {
                        HStack {
                            Image(systemName: "safari")
                            Text("View on Website")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                
                Spacer().frame(height: 20)
            }
        }
        .frame(width: 300)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Metadata Section
    
    private var metadataSection: some View {
        let rows = buildMetadataRows()
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                metadataRow(label: row.0, value: row.1, isLast: index == rows.count - 1)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
        )
    }
    
    private func buildMetadataRows() -> [(String, String)] {
        var rows: [(String, String)] = []
        
        rows.append(("Source", item.source.displayName))
        rows.append(("Date", item.formattedDate))
        
        if let center = item.center {
            rows.append(("Center", center))
        }
        if let facility = item.facility {
            rows.append(("Facility", facility))
        }
        if let instrument = item.instrument {
            rows.append(("Instrument", instrument))
        }
        if let photographer = item.photographer {
            rows.append(("Credit", photographer))
        }
        if let location = item.location {
            rows.append(("Location", location))
        }
        if let nasaId = item.nasaId {
            rows.append(("ID", nasaId))
        }
        
        return rows
    }
    
    private func metadataRow(label: String, value: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .leading)
                Text(value)
                    .font(.caption)
                    .textSelection(.enabled)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            if !isLast {
                Divider()
                    .padding(.leading, 12)
            }
        }
    }
}

// MARK: - Flow Layout for Keywords

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }
    
    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }
        
        return (positions, CGSize(width: maxX, height: currentY + lineHeight))
    }
}
