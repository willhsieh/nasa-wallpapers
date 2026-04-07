import SwiftUI

struct SearchSidebar: View {
    @ObservedObject var viewModel: ImageSearchViewModel
    @State private var showAdvancedFilters = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Search Header
            sectionHeader("Search")
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Query
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Query")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Search images...", text: $viewModel.query)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                Task { await viewModel.search() }
                            }
                    }
                    
                    Divider()
                    
                    // MARK: - Sources Checklist
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sources")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        ForEach(ImageSource.allCases) { source in
                            SourceCheckRow(
                                source: source,
                                isEnabled: viewModel.enabledSources.contains(source),
                                status: viewModel.sourceStatus[source]
                            ) {
                                viewModel.toggleSource(source)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // MARK: - Basic Filters
                    Text("Basic Filters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Media Type (NASA Library only)
                    HStack {
                        Text("Media Type")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("", selection: $viewModel.mediaType) {
                            ForEach(MediaType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                    .opacity(viewModel.enabledSources.contains(.nasaLibrary) ? 1 : 0.4)
                    
                    // Year Range
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Year Range")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if !viewModel.yearStart.isEmpty || !viewModel.yearEnd.isEmpty {
                                Button("Clear") {
                                    viewModel.yearStart = ""
                                    viewModel.yearEnd = ""
                                }
                                .font(.caption)
                                .buttonStyle(.plain)
                                .foregroundStyle(.orange)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            TextField("Start", text: $viewModel.yearStart)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 70)
                            Text("—")
                                .foregroundStyle(.secondary)
                            TextField("End", text: $viewModel.yearEnd)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 70)
                        }
                    }
                    .opacity(viewModel.enabledSources.contains(.nasaLibrary) ? 1 : 0.4)
                    
                    Divider()
                    
                    // MARK: - Advanced Filters
                    DisclosureGroup("Advanced Filters", isExpanded: $showAdvancedFilters) {
                        VStack(alignment: .leading, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("NASA Center")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("e.g. MSFC, JPL, KSC", text: $viewModel.center)
                                    .textFieldStyle(.roundedBorder)
                            }
                            .opacity(viewModel.enabledSources.contains(.nasaLibrary) ? 1 : 0.4)
                        }
                        .padding(.top, 8)
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            // MARK: - Action Buttons
            VStack(spacing: 8) {
                Divider()
                HStack {
                    Button("Clear") {
                        viewModel.clearFilters()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Search") {
                        Task { await viewModel.search() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .keyboardShortcut(.return, modifiers: .command)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 240)
        .background(.ultraThinMaterial)
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 4)
    }
}

// MARK: - Source Checklist Row

struct SourceCheckRow: View {
    let source: ImageSource
    let isEnabled: Bool
    let status: ImageSearchViewModel.SourceLoadStatus?
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isEnabled ? .orange : .secondary)
                    .font(.system(size: 14))
                
                Image(systemName: source.iconName)
                    .font(.caption)
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                    .frame(width: 14)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(source.displayName)
                        .font(.caption)
                        .foregroundStyle(isEnabled ? .primary : .secondary)
                    
                    if let status {
                        statusLabel(status)
                    }
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func statusLabel(_ status: ImageSearchViewModel.SourceLoadStatus) -> some View {
        switch status {
        case .idle:
            EmptyView()
        case .loading:
            Text("Loading...")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        case .loaded(let count):
            Text("\(count) results")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        case .error(let msg):
            Text(msg)
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }
}
