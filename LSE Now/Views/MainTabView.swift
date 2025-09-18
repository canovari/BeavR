import SwiftUI

struct MainTabView: View {
    @StateObject var viewModel: PostListViewModel
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            MapView(vm: viewModel)
                .tag(0)
                .tabItem { Label("Map", systemImage: "map") }

            FeedView(vm: viewModel)
                .tag(1)
                .tabItem { Label("Feed", systemImage: "list.bullet.rectangle") }

            ExploreView()
                .tag(2)
                .tabItem { Label("Explore", systemImage: "sparkles") }

            NewEventView()
                .tag(3)
                .tabItem { Label("New Event", systemImage: "plus.circle") }
        }
        .accentColor(Color("LSERed"))
    }
}
