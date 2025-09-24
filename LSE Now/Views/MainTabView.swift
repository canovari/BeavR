import SwiftUI
import UIKit

struct MainTabView: View {
    @StateObject private var eventsViewModel: PostListViewModel
    @StateObject private var dealsViewModel: DealListViewModel
    @State private var selection = 0
    @State private var tabTarget = 0
    @State private var tabIconFrames: [Int: CGRect] = [:]
    @State private var tabAnimationTask: Task<Void, Never>?
    @State private var currentTabAnimationID = UUID()
    private let tabTransitionDuration: Double = 0.45
    @AppStorage("hasSeenMainGuide") private var hasSeenMainGuide = false
    @State private var showIntroduction = false
    @State private var didTriggerIntroduction = false
    @State private var permissionsCompleted = false
    @EnvironmentObject private var locationManager: LocationManager
    @Environment(\.scenePhase) private var scenePhase
    private let launchAnimationFinished: Bool

    init(eventsViewModel: PostListViewModel, dealsViewModel: DealListViewModel, launchAnimationFinished: Bool) {
        _eventsViewModel = StateObject(wrappedValue: eventsViewModel)
        _dealsViewModel = StateObject(wrappedValue: dealsViewModel)
        _selection = State(initialValue: 0)
        _tabTarget = State(initialValue: 0)
        self.launchAnimationFinished = launchAnimationFinished

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
                GuidedIntroductionOverlay(
                    isPresented: $showIntroduction,
                    selectedTab: $tabTarget,
                    tabIconFrames: tabIconFrames
                ) {
                    hasSeenMainGuide = true
                }
                .transition(.opacity)
                .zIndex(2)
            }

            if !permissionsCompleted {
                if launchAnimationFinished {
                    PermissionsGateView(isComplete: $permissionsCompleted)
                        .transition(.opacity)
                        .zIndex(3)
                }
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
        .onChange(of: tabTarget, initial: false) { _, newTarget in
            guard newTarget != selection else { return }
            animateTabTransition(to: newTarget)
        }
        .onChange(of: selection, initial: false) { _, newSelection in
            guard tabAnimationTask == nil else { return }
            if tabTarget != newSelection {
                tabTarget = newSelection
            }
        }
        .onDisappear {
            tabAnimationTask?.cancel()
            tabAnimationTask = nil
        }
    }

    private var tabView: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                TabView(selection: $selection) {
                    MapView(vm: eventsViewModel)
                        .tag(MainTab.map.rawValue)

                    FeedView(vm: eventsViewModel)
                        .tag(MainTab.feed.rawValue)

                    WhiteboardView()
                        .tag(MainTab.pinboard.rawValue)

                    DealsView(viewModel: dealsViewModel)
                        .tag(MainTab.deals.rawValue)

                    NewEventView()
                        .environmentObject(eventsViewModel)
                        .tag(MainTab.newEvent.rawValue)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()

                CustomTabBar(
                    items: MainTab.allCases,
                    selection: tabTarget,
                    onSelect: handleTabSelection
                )
                .padding(.horizontal, 4)
                .padding(.top, 8)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 12))
                .background(Color(UIColor.systemGroupedBackground))
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onPreferenceChange(TabIconPreferenceKey.self) { values in
            var frames: [Int: CGRect] = [:]
            for value in values {
                frames[value.index] = value.frame
            }
            tabIconFrames = frames
        }
    }

    private func handleTabSelection(_ index: Int) {
        let clampedIndex = min(max(index, MainTab.map.rawValue), MainTab.newEvent.rawValue)
        guard tabTarget != clampedIndex else { return }
        tabTarget = clampedIndex
    }

    private func animateTabTransition(to target: Int) {
        let clampedTarget = min(max(target, MainTab.map.rawValue), MainTab.newEvent.rawValue)
        let current = selection

        guard clampedTarget != current else { return }

        tabAnimationTask?.cancel()

        let path = tabTransitionPath(from: current, to: clampedTarget)
        guard !path.isEmpty else { return }

        let totalDuration = tabTransitionDuration
        let stepDuration = totalDuration / Double(path.count)
        let delayNanoseconds = UInt64((stepDuration * 1_000_000_000).rounded())

        currentTabAnimationID = UUID()
        let animationID = currentTabAnimationID

        tabAnimationTask = Task { [path, animationID] in
            for (index, value) in path.enumerated() {
                if Task.isCancelled || animationID != currentTabAnimationID { break }

                await MainActor.run {
                    withAnimation(.easeInOut(duration: stepDuration)) {
                        selection = value
                    }
                }

                if index < path.count - 1 {
                    do {
                        try await Task.sleep(nanoseconds: delayNanoseconds)
                    } catch {
                        break
                    }
                }
            }

            await MainActor.run {
                if currentTabAnimationID == animationID {
                    tabAnimationTask = nil
                }
            }
        }
    }

    private func tabTransitionPath(from current: Int, to target: Int) -> [Int] {
        guard current != target else { return [] }

        if target > current {
            return Array((current + 1)...target)
        } else {
            return Array((target..<current).reversed())
        }
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

private enum MainTab: Int, CaseIterable {
    case map
    case feed
    case pinboard
    case deals
    case newEvent

    var title: String {
        switch self {
        case .map:
            return "Map"
        case .feed:
            return "Feed"
        case .pinboard:
            return "Pinboard"
        case .deals:
            return "Deals"
        case .newEvent:
            return "New Event"
        }
    }

    var iconName: String {
        switch self {
        case .map:
            return "map"
        case .feed:
            return "list.bullet.rectangle"
        case .pinboard:
            return "square.grid.3x3.fill"
        case .deals:
            return "tag"
        case .newEvent:
            return "plus.circle"
        }
    }
}

private struct CustomTabBar: View {
    let items: [MainTab]
    let selection: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.rawValue) { item in
                let isSelected = selection == item.rawValue

                Button {
                    onSelect(item.rawValue)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.iconName)
                            .font(.system(size: 21, weight: .semibold))
                            .frame(width: 32, height: 28)
                            .foregroundColor(isSelected ? Color("LSERed") : Color.secondary.opacity(0.7))
                            .background(
                                GeometryReader { geometry in
                                    Color.clear.preference(
                                        key: TabIconPreferenceKey.self,
                                        value: [TabIconPreferenceData(index: item.rawValue, frame: geometry.frame(in: .global))]
                                    )
                                }
                            )

                        Text(item.title)
                            .font(.caption2)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .foregroundColor(isSelected ? Color("LSERed") : Color.secondary.opacity(0.7))
                }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
    }
}

private struct TabIconPreferenceData: Equatable {
    let index: Int
    let frame: CGRect
}

private struct TabIconPreferenceKey: PreferenceKey {
    static var defaultValue: [TabIconPreferenceData] = []

    static func reduce(value: inout [TabIconPreferenceData], nextValue: () -> [TabIconPreferenceData]) {
        value.append(contentsOf: nextValue())
    }
}
