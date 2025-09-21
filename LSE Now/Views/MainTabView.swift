import SwiftUI
import UIKit

struct MainTabView: View {
    @StateObject private var eventsViewModel: PostListViewModel
    @StateObject private var dealsViewModel: DealListViewModel
    @State private var selection = 0

    init(eventsViewModel: PostListViewModel, dealsViewModel: DealListViewModel) {
        _eventsViewModel = StateObject(wrappedValue: eventsViewModel)
        _dealsViewModel = StateObject(wrappedValue: dealsViewModel)

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemGroupedBackground

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selection) {
            MapView(vm: eventsViewModel)
                .tag(0)
                .tabItem { Label("Map", systemImage: "map") }

            FeedView(vm: eventsViewModel)
                .tag(1)
                .tabItem { Label("Feed", systemImage: "list.bullet.rectangle") }

            WhiteboardView()
                .tag(2)
                .tabItem { Label("Pinboard", systemImage: "square.grid.3x3.fill") }

            DealsView(viewModel: dealsViewModel)
                .tag(3)
                .tabItem { Label("Deals", systemImage: "tag") }

            NewEventView()
                .environmentObject(eventsViewModel)
                .tag(4)
                .tabItem { Label("New Event", systemImage: "plus.circle") }
        }
        .accentColor(Color("LSERed"))
    }
}
