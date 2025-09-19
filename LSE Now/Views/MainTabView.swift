import SwiftUI
import UIKit

struct MainTabView: View {
    @StateObject private var viewModel: PostListViewModel
    @State private var selection = 0

    init(viewModel: PostListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemGroupedBackground

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selection) {
            MapView(vm: viewModel)
                .tag(0)
                .tabItem { Label("Map", systemImage: "map") }

            FeedView(vm: viewModel)
                .tag(1)
                .tabItem { Label("Feed", systemImage: "list.bullet.rectangle") }

            WhiteboardView()
                .tag(2)
                .tabItem { Label("Pinboard", systemImage: "square.grid.3x3.fill") }

            NewEventView()
                .tag(3)
                .tabItem { Label("New Event", systemImage: "plus.circle") }
        }
        .accentColor(Color("LSERed"))
    }
}
