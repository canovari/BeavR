import SwiftUI

struct EventLikeButton: View {
    let isLiked: Bool
    let likeCount: Int
    let isLoading: Bool
    let action: () -> Void
    var iconSize: CGFloat = 18

    @State private var animate = false
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
        .onAppear {
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
