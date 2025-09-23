import SwiftUI
import UIKit

struct MainTabView: View {
    @StateObject private var eventsViewModel: PostListViewModel
    @StateObject private var dealsViewModel: DealListViewModel
    @State private var selection = 0
    @AppStorage("hasSeenMainGuide") private var hasSeenMainGuide = false
    @State private var showIntroduction = false
    @State private var didTriggerIntroduction = false
    @State private var permissionsCompleted = false
    @EnvironmentObject private var locationManager: LocationManager
    @Environment(\.scenePhase) private var scenePhase

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
        ZStack {
            tabView

            if permissionsCompleted && showIntroduction {
                GuidedIntroductionOverlay(isPresented: $showIntroduction, selectedTab: $selection) {
                    hasSeenMainGuide = true
                }
                .transition(.opacity)
                .zIndex(2)
            }

            if !permissionsCompleted {
                PermissionsGateView(isComplete: $permissionsCompleted)
                    .transition(.opacity)
                    .zIndex(3)
            }
        }
        .onAppear {
            enforceLocationPermissionsIfNeeded()
            if permissionsCompleted {
                triggerIntroductionIfNeeded()
            }
        }
        .onChange(of: permissionsCompleted) { _, completed in
            if completed {
                triggerIntroductionIfNeeded()
            } else {
                showIntroduction = false
                didTriggerIntroduction = false
            }
        }
        .onChange(of: locationManager.authorizationStatus) { _, _ in
            enforceLocationPermissionsIfNeeded()
        }
        .onChange(of: locationManager.accuracyAuthorization) { _, _ in
            enforceLocationPermissionsIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                enforceLocationPermissionsIfNeeded()
            }
        }
        .onChange(of: showIntroduction, initial: false) { wasShowing, isShowing in
            if wasShowing && !isShowing {
                hasSeenMainGuide = true
            }
        }
    }

    private var tabView: some View {
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

    private func triggerIntroductionIfNeeded() {
        guard !hasSeenMainGuide, !didTriggerIntroduction else { return }
        didTriggerIntroduction = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.88, blendDuration: 0.3)) {
                showIntroduction = true
            }
        }
    }

    private func enforceLocationPermissionsIfNeeded() {
        guard permissionsCompleted else { return }
        guard locationManager.hasValidLocationPermission else {
            withAnimation(.easeInOut(duration: 0.3)) {
                permissionsCompleted = false
            }
            return
        }
    }
}
