import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ImageSearchViewModel()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SearchSidebar(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } content: {
            ImageGridView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 450, ideal: 600)
        } detail: {
            if let selected = viewModel.selectedItem {
                ImageDetailPanel(item: selected, viewModel: viewModel)
                    .navigationSplitViewColumnWidth(min: 280, ideal: 300, max: 340)
            } else {
                Text("Select an image")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationSplitViewColumnWidth(min: 280, ideal: 300, max: 340)
            }
        }
        .navigationTitle("NASA Images")
        .frame(minWidth: 1000, minHeight: 600)
        .task {
            await viewModel.search()
        }
    }
}
