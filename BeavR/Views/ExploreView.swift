import SwiftUI

struct ExploreView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundColor(Color("LSERed")) // ✅ fixed
                
                Text("Explore")
                    .font(.largeTitle)
                    .bold()
                
                Text("Discover trending events, societies, and recommendations.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Explore")
        }
    }
}
