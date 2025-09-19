import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = PostListViewModel()
    
    var body: some View {
        TabView {
            FeedView(vm: viewModel)   // pass the shared VM
                .tabItem {
                    Label("Feed", systemImage: "list.bullet")
                }
            
            MapView(vm: viewModel)    // ✅ use `vm:` not `viewModel:`
                .tabItem {
                    Label("Map", systemImage: "map")
                }
            
            WhiteboardView()
                .tabItem {
                    Label("Whiteboard", systemImage: "square.grid.3x3.fill")
                }
        }
        .onAppear {
            viewModel.fetchPosts()
        }
    }
}
