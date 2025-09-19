import SwiftUI

struct LaunchView: View {
    @State private var animate = false
    @State private var finished = false
    @StateObject private var viewModel = PostListViewModel() // preload in background
    @StateObject private var authViewModel = AuthViewModel()
    @EnvironmentObject private var locationManager: LocationManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if finished {
                if authViewModel.isLoggedIn {
                    MainTabView(viewModel: viewModel) // pass loaded VM forward
                        .environmentObject(authViewModel)
                } else {
                    LoginFlowView(viewModel: authViewModel)
                }
            } else {
                Color("LSERed")
                    .ignoresSafeArea()

                VStack {
                    Text("BeavR")
                        .font(.custom("HelveticaNeue-Bold", size: 44))
                        .foregroundColor(.white)
                        .scaleEffect(animate ? 1.0 : 0.8)
                        .opacity(animate ? 1.0 : 0.0)
                        .animation(.easeOut(duration: 1.0), value: animate)
                }
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

            // Transition to app after ~2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    finished = true
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
}
