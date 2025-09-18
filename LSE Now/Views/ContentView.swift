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
            
            ExploreView()
                .tabItem {
                    Label("Explore", systemImage: "magnifyingglass")
                }
        }
        .onAppear {
            viewModel.fetchPosts()
        }
    }
}
