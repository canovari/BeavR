import SwiftUI

struct GuidedIntroductionOverlay: View {
    @Binding var isPresented: Bool
    var onFinish: () -> Void

    @State private var currentStep = 0

    private let steps = IntroStep.steps

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 28) {
                Spacer(minLength: 0)

                Text("Welcome to BeavR")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

                TabView(selection: $currentStep) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        IntroCard(step: step)
                            .tag(index)
                            .padding(.horizontal, 12)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 340)

                Button(action: advance) {
                    Text(currentStep == steps.count - 1 ? "Get Started" : "Next")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color("LSERed"), in: Capsule())
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 6)
                }
                .buttonStyle(.plain)

                Button(action: finish) {
                    Text("Skip Intro")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white.opacity(0.88))
                        .padding(.top, 4)
                }

                Spacer(minLength: 16)
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 32)
        }
        .transition(.opacity.combined(with: .scale))
    }

    private func advance() {
        if currentStep < steps.count - 1 {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.86, blendDuration: 0.3)) {
                currentStep += 1
            }
        } else {
            finish()
        }
    }

    private func finish() {
        withAnimation(.easeInOut(duration: 0.32)) {
            isPresented = false
        }
        onFinish()
    }
}

private struct IntroStep: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let icon: String
    let tabIcon: String
    let accent: Color
    let tabLabel: String

    static let steps: [IntroStep] = [
        IntroStep(
            title: "Explore the campus",
            message: "The Map tab shows live pins for everything happening nearby. Tap one to see the essentials instantly.",
            icon: "map.fill",
            tabIcon: "map",
            accent: .blue,
            tabLabel: "Map tab"
        ),
        IntroStep(
            title: "Catch every update",
            message: "Scroll the Feed for a clean timeline of upcoming events. Open any card for full details and directions.",
            icon: "list.bullet.rectangle",
            tabIcon: "list.bullet.rectangle",
            accent: .indigo,
            tabLabel: "Feed tab"
        ),
        IntroStep(
            title: "Drop quick pins",
            message: "The Pinboard is perfect for fast shout-outs and micro-updates from around campus.",
            icon: "square.grid.3x3.fill",
            tabIcon: "square.grid.3x3.fill",
            accent: .purple,
            tabLabel: "Pinboard tab"
        ),
        IntroStep(
            title: "Find exclusive deals",
            message: "Never miss a student offer. Check the Deals tab for fresh perks from local favourites.",
            icon: "tag.fill",
            tabIcon: "tag",
            accent: .orange,
            tabLabel: "Deals tab"
        ),
        IntroStep(
            title: "Share & save events",
            message: "Head to New Event to post your own happenings, track approvals, and revisit favourites in Liked Events.",
            icon: "plus.circle.fill",
            tabIcon: "plus.circle",
            accent: Color("LSERed"),
            tabLabel: "New Event tab"
        )
    ]
}

private struct IntroCard: View {
    let step: IntroStep

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(step.accent.opacity(0.12))
                    .frame(width: 86, height: 86)

                Image(systemName: step.icon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(step.accent)
            }

            Text(step.title)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(step.message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            Label {
                Text(step.tabLabel)
                    .fontWeight(.semibold)
            } icon: {
                Image(systemName: step.tabIcon)
            }
            .font(.subheadline)
            .foregroundColor(step.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(step.accent.opacity(0.16), in: Capsule())
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14))
        )
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 12)
    }
}
