import SwiftUI

struct EventLikeButton: View {
    let isLiked: Bool
    let likeCount: Int
    let isLoading: Bool
    let action: () -> Void

    @State private var animate = false

    var body: some View {
        Button {
            guard !isLoading else { return }
            action()
        } label: {
            HStack(spacing: 6) {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(isLiked ? Color("LSERed") : .secondary)
                    }
                }

                Text("\(likeCount)")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .scaleEffect(animate ? 1.15 : 1.0)
        .onChange(of: isLiked) { newValue in
            guard newValue else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.45, blendDuration: 0.15)) {
                animate = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                animate = false
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .disabled(isLoading)
        .accessibilityLabel(Text(isLiked ? "Unlike event" : "Like event"))
        .accessibilityValue(Text("\(likeCount) likes"))
    }
}
