import SwiftUI

struct LaunchView: View {
    @State private var animate = false
    @State private var finished = false
    @State private var zooming = false
    @State private var fadeBackground = false
    @State private var hideLaunchContent = false
    @StateObject private var viewModel = PostListViewModel() // preload in background
    @StateObject private var authViewModel = AuthViewModel()
    @EnvironmentObject private var locationManager: LocationManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if authViewModel.isLoggedIn {
                MainTabView(viewModel: viewModel) // pass loaded VM forward
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
            // Start fetching posts immediately in the background
            viewModel.fetchPosts()
            authViewModel.loadExistingSession()

            if authViewModel.isLoggedIn {
                locationManager.handleLoginStateChange(
                    isLoggedIn: true,
                    emailProvider: { authViewModel.email } // ✅ now using emailProvider
                )
            }

            locationManager.updateAppActivity(isActive: scenePhase == .active)

            // Kick off animation
            animate = true

            // Transition to app after ~2 seconds with a zoom + fade sequence
            let zoomDelay = 2.0
            let zoomDuration = 0.7

            DispatchQueue.main.asyncAfter(deadline: .now() + zoomDelay) {
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
                    emailProvider: { authViewModel.email } // ✅ emailProvider here too
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

            VStack(spacing: 28) {
                BeaverFaceView()
                    .frame(width: 180, height: 180)
                    .scaleEffect(zooming ? 7.5 : (animate ? 1.0 : 0.8))
                    .animation(.easeOut(duration: 1.0), value: animate)
                    .animation(.easeInOut(duration: 0.7), value: zooming)

                Text("BeavR")
                    .font(.custom("HelveticaNeue-Bold", size: 44))
                    .foregroundColor(.white)
                    .opacity(zooming ? 0.0 : (animate ? 1.0 : 0.0))
                    .scaleEffect(animate ? 1.0 : 0.8)
                    .animation(.easeOut(duration: 1.0), value: animate)
                    .animation(.easeInOut(duration: 0.3), value: zooming)
            }
            .opacity(hideLaunchContent ? 0.0 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: hideLaunchContent)
        }
    }
}
