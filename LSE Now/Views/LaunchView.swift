import SwiftUI

struct LaunchView: View {
    @State private var finished = false
    @State private var zooming = false
    @State private var fadeBackground = false
    @State private var hideLaunchContent = false
    @StateObject private var viewModel = PostListViewModel() // preload in background
    @StateObject private var dealsViewModel = DealListViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    @EnvironmentObject private var locationManager: LocationManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if authViewModel.isLoggedIn {
                MainTabView(eventsViewModel: viewModel, dealsViewModel: dealsViewModel)
                    .environmentObject(authViewModel)
            } else {
                LoginFlowView(viewModel: authViewModel)
            }

            if !finished {
                launchOverlay
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            // Preload
            viewModel.fetchPosts()
            dealsViewModel.fetchDeals()
            authViewModel.loadExistingSession()

            if authViewModel.isLoggedIn {
                locationManager.handleLoginStateChange(
                    isLoggedIn: true,
                    emailProvider: { authViewModel.email }
                )
            }

            locationManager.updateAppActivity(isActive: scenePhase == .active)

            // Run sequence
            let delay = 2.0
            let zoomDuration = 0.7

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: zoomDuration)) {
                    zooming = true
                    fadeBackground = true
                }

                let contentFadeDelay = zoomDuration * 0.6
                DispatchQueue.main.asyncAfter(deadline: .now() + contentFadeDelay) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        hideLaunchContent = true
                    }
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + zoomDuration + 0.2) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        finished = true
                    }
                }
            }
        }
        .onChange(of: authViewModel.isLoggedIn) { _, isLoggedIn in
            if isLoggedIn {
                locationManager.handleLoginStateChange(
                    isLoggedIn: true,
                    emailProvider: { authViewModel.email }
                )
            } else {
                locationManager.handleLoginStateChange(isLoggedIn: false, emailProvider: nil)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            locationManager.updateAppActivity(isActive: newPhase == .active)
        }
    }

    private var launchOverlay: some View {
        ZStack {
            Color("LSERed")
                .opacity(fadeBackground ? 0.0 : 1.0)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.7), value: fadeBackground)

            Text("BeavR")
                .font(.custom("HelveticaNeue-Bold", size: 44))
                .foregroundColor(.white)
                .opacity(zooming ? 0.0 : 1.0)          // 👈 starts visible, fades out on zoom
                .scaleEffect(zooming ? 6.0 : 1.0)      // 👈 zooms up slightly then disappears
                .animation(.easeInOut(duration: 0.6), value: zooming)
        }
        .opacity(hideLaunchContent ? 0.0 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: hideLaunchContent)
    }
}
