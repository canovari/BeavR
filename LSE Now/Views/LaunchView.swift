import SwiftUI

struct LaunchView: View {
    @State private var animate = false
    @State private var finished = false
    @StateObject private var viewModel = PostListViewModel() // preload in background

    var body: some View {
        ZStack {
            if finished {
                MainTabView(viewModel: viewModel) // pass loaded VM forward
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

            // Kick off animation
            animate = true

            // Transition to app after ~2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    finished = true
                }
            }
        }
    }
}
