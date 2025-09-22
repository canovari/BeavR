import SwiftUI

struct EventLikeButton: View {
    let isLiked: Bool
    let likeCount: Int
    let isLoading: Bool
    let action: () -> Void
    var iconSize: CGFloat = 18

    @State private var heartOpacity = 1.0
    @State private var fadeAnimationID = 0
    @State private var showCount = false

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
                            .font(.system(size: iconSize, weight: .semibold))
                            .foregroundColor(isLiked ? Color("LSERed") : .secondary)
                            .opacity(heartOpacity)
                    }
                }

                if showCount {
                    Text("\(sanitizedLikeCount)")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onChange(of: isLiked) { _ in
            fadeAnimationID += 1
            let currentID = fadeAnimationID

            withAnimation(.easeInOut(duration: 0.18)) {
                heartOpacity = 0.35
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                guard currentID == fadeAnimationID else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    heartOpacity = 1.0
                }
            }
        }
        .onAppear {
            heartOpacity = 1.0
            showCount = sanitizedLikeCount > 0
        }
        .onChange(of: likeCount) { newValue in
            let sanitizedValue = max(newValue, 0)
            let shouldShow = sanitizedValue > 0

            let animation: Animation = shouldShow && !showCount
                ? .spring(response: 0.35, dampingFraction: 0.7, blendDuration: 0.2)
                : .easeInOut(duration: 0.2)

            withAnimation(animation) {
                showCount = shouldShow
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .disabled(isLoading)
        .accessibilityLabel(Text(isLiked ? "Unlike event" : "Like event"))
        .accessibilityValue(Text(accessibilityValueText))
        .onDisappear {
            fadeAnimationID += 1
            heartOpacity = 1.0
        }
    }

    private var sanitizedLikeCount: Int {
        max(likeCount, 0)
    }

    private var accessibilityValueText: String {
        if sanitizedLikeCount == 0 {
            return "No likes yet"
        }
        return "\(sanitizedLikeCount) likes"
    }
}
