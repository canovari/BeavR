import SwiftUI

struct EventLikeButton: View {
    let isLiked: Bool
    let likeCount: Int
    let isLoading: Bool
    let action: () -> Void
    var iconSize: CGFloat = 18

    @Namespace private var likeNamespace

    @State private var heartOpacity = 1.0
    @State private var fadeAnimationID = 0
    @State private var showCount = false
    @State private var maxCountDigits = 1
    @State private var countOpacity = 0.0

    var body: some View {
        Button {
            guard !isLoading else { return }
            action()
        } label: {
            HStack(spacing: 6) {
                if showCount {
                    iconContainer
                        .matchedGeometryEffect(id: "heart", in: likeNamespace)
                    countContainer
                } else {
                    countContainer
                    iconContainer
                        .matchedGeometryEffect(id: "heart", in: likeNamespace)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
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
            updateMaxDigits(with: sanitizedLikeCount)
            let shouldShow = sanitizedLikeCount > 0
            showCount = shouldShow
            countOpacity = shouldShow ? 1 : 0
        }
        .onChange(of: likeCount) { newValue in
            let sanitizedValue = max(newValue, 0)
            let shouldShow = sanitizedValue > 0

            updateMaxDigits(with: sanitizedValue)

            if shouldShow && !showCount {
                countOpacity = 0
                withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.85, blendDuration: 0.2)) {
                    showCount = true
                }
                withAnimation(.easeOut(duration: 0.12).delay(0.04)) {
                    countOpacity = 1
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showCount = shouldShow
                }

                if shouldShow {
                    withAnimation(.easeOut(duration: 0.12)) {
                        countOpacity = 1
                    }
                } else {
                    countOpacity = 0
                }
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

    private var iconFrameSize: CGFloat {
        iconSize + 8
    }

    private var countPlaceholder: String {
        guard maxCountDigits > 0 else { return "" }
        return String(repeating: "8", count: maxCountDigits)
    }

    private func updateMaxDigits(with value: Int) {
        let digits = max(1, String(value).count)
        if digits > maxCountDigits {
            maxCountDigits = digits
        }
    }

    private var accessibilityValueText: String {
        if sanitizedLikeCount == 0 {
            return "No likes yet"
        }
        return "\(sanitizedLikeCount) likes"
    }

    private var iconContainer: some View {
        Image(systemName: isLiked ? "heart.fill" : "heart")
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundColor(isLiked ? Color("LSERed") : .secondary)
            .opacity(heartOpacity)
        .frame(width: iconFrameSize, height: iconFrameSize)
    }

    private var countContainer: some View {
        ZStack(alignment: .trailing) {
            if showCount {
                Text("\(sanitizedLikeCount)")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .opacity(countOpacity)
            }

            Text(countPlaceholder)
                .font(.footnote)
                .fontWeight(.semibold)
                .opacity(0)
        }
    }
}
