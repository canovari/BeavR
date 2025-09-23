import SwiftUI
import CoreGraphics

struct GuidedIntroductionOverlay: View {
    @Binding var isPresented: Bool
    @Binding var selectedTab: Int
    var onFinish: () -> Void

    @State private var currentStep = 0
    @State private var hasStartedTour = false
    @State private var welcomeTextAppeared = false
    @State private var showStartButton = false

    @Namespace private var welcomeNamespace

    private let steps = IntroStep.steps

    var body: some View {
        ZStack(alignment: .topLeading) {
            backgroundView

            if hasStartedTour {
                startedTourContent
                    .transition(.opacity)
            } else {
                startScreen
                    .transition(.opacity)
            }
        }
        .onAppear {
            currentStep = 0
            hasStartedTour = false
            welcomeTextAppeared = false
            showStartButton = false

            withAnimation(.spring(response: 0.7, dampingFraction: 0.82).delay(0.05)) {
                welcomeTextAppeared = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.easeOut(duration: 0.45)) {
                    showStartButton = true
                }
            }
        }
        .onChange(of: currentStep, initial: false) { _, newStep in
            guard hasStartedTour else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTab = steps[newStep].tabSelection
            }
        }
        .onChange(of: hasStartedTour, initial: false) { _, started in
            guard started else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTab = steps[currentStep].tabSelection
            }
        }
        .transition(.opacity)
    }

    private var backgroundView: some View {
        GeometryReader { geometry in
            let highlight = highlightCircle(in: geometry)

            ZStack {
                if hasStartedTour {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.55),
                            Color.black.opacity(0.5),
                            Color.black.opacity(0.3),
                            Color.black.opacity(0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                } else {
                    Color.white
                        .ignoresSafeArea()
                }
            }
            .overlay {
                if let highlight, hasStartedTour {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 3)
                        .frame(width: highlight.diameter, height: highlight.diameter)
                        .position(highlight.center)
                        .transition(.opacity)
                }
            }
            .overlay {
                if let highlight, hasStartedTour {
                    Circle()
                        .fill(Color.black)
                        .frame(width: highlight.diameter, height: highlight.diameter)
                        .position(highlight.center)
                        .blendMode(.destinationOut)
                }
            }
            .compositingGroup()
        }
    }

    private var startScreen: some View {
        VStack(spacing: 0) {
            skipButton

            Spacer()

            VStack(spacing: 28) {
                Text("Welcome to BeavR")
                    .matchedGeometryEffect(id: "welcomeText", in: welcomeNamespace)
                    .font(.largeTitle.weight(.bold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .scaleEffect(welcomeTextAppeared ? 1 : 0.82)
                    .opacity(welcomeTextAppeared ? 1 : 0)
                    .animation(.spring(response: 0.65, dampingFraction: 0.85), value: welcomeTextAppeared)

                startCallToAction
            }
            .padding(.horizontal, 36)

            Spacer()
        }
        .padding(.bottom, 48)
    }

    private var startCallToAction: some View {
        Button(action: startTour) {
            Text("Start")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color("LSERed"))
                )
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .opacity(showStartButton ? 1 : 0)
        .animation(.easeOut(duration: 0.45), value: showStartButton)
        .allowsHitTesting(showStartButton)
    }

    private var startedTourContent: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                skipButton

                Spacer(minLength: 0)

                Text("Welcome to BeavR")
                    .matchedGeometryEffect(id: "welcomeText", in: welcomeNamespace)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)

                introPanel
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 72)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var skipButton: some View {
        HStack {
            Button(action: finish) {
                Text("Skip Intro")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(skipButtonColor)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.top, 20)
        .padding(.horizontal, 24)
    }

    private var skipButtonColor: Color {
        hasStartedTour ? .white.opacity(0.9) : Color("LSERed")
    }

    private var introPanel: some View {
        VStack(spacing: 20) {
            TabView(selection: $currentStep) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    IntroCard(step: step)
                        .tag(index)
                        .padding(.horizontal, 4)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 280)

            HStack(spacing: 8) {
                ForEach(Array(steps.indices), id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(index == currentStep ? steps[currentStep].accent : Color.white.opacity(0.35))
                        .frame(width: index == currentStep ? 24 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.25), value: currentStep)
                }
            }
            .frame(maxWidth: .infinity)

            Button(action: advance) {
                Text(currentStep == steps.count - 1 ? "Get Started" : "Next")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color("LSERed"))
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 28)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color("LSERed").opacity(0.18))
        )
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 12)
        .padding(.horizontal, 24)
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

    private func startTour() {
        withAnimation(.easeOut(duration: 0.2)) {
            showStartButton = false
        }

        withAnimation(.easeInOut(duration: 0.6)) {
            hasStartedTour = true
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            selectedTab = steps[currentStep].tabSelection
        }
    }

    private func finish() {
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedTab = steps[0].tabSelection
        }

        withAnimation(.easeInOut(duration: 0.32)) {
            isPresented = false
        }

        onFinish()
    }

    private func highlightCircle(in geometry: GeometryProxy) -> HighlightCircleInfo? {
        guard hasStartedTour else { return nil }

        let totalTabs = max(steps.count, 1)
        let currentIndex = steps[currentStep].tabSelection
        let clampedIndex = min(max(currentIndex, 0), totalTabs - 1)
        let width = geometry.size.width
        let segmentWidth = width / CGFloat(totalTabs)
        let centerX = segmentWidth * (CGFloat(clampedIndex) + 0.5)
        let bottomInset = geometry.safeAreaInsets.bottom
        let tabBarHeight: CGFloat = 49
        let verticalOffset: CGFloat = 4
        let centerY = geometry.size.height - bottomInset - (tabBarHeight / 2) - verticalOffset
        let diameter: CGFloat = 118

        return HighlightCircleInfo(center: CGPoint(x: centerX, y: centerY), diameter: diameter)
    }
}

private struct HighlightCircleInfo {
    let center: CGPoint
    let diameter: CGFloat
}

private struct IntroStep: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let icon: String
    let tabIcon: String
    let accent: Color
    let tabLabel: String
    let tabSelection: Int

    static let steps: [IntroStep] = [
        IntroStep(
            title: "Explore the campus",
            message: "The Map tab shows live pins for everything happening nearby. Tap one to see the essentials instantly.",
            icon: "map.fill",
            tabIcon: "map",
            accent: Color("LSERed"),
            tabLabel: "Map",
            tabSelection: 0
        ),
        IntroStep(
            title: "Catch every update",
            message: "Scroll the Feed for a clean timeline of upcoming events. Open any card for full details and directions.",
            icon: "list.bullet.rectangle",
            tabIcon: "list.bullet.rectangle",
            accent: Color("LSERed"),
            tabLabel: "Feed",
            tabSelection: 1
        ),
        IntroStep(
            title: "Drop quick pins",
            message: "The Pinboard is perfect for fast shout-outs and micro-updates from around campus.",
            icon: "square.grid.3x3.fill",
            tabIcon: "square.grid.3x3.fill",
            accent: Color("LSERed"),
            tabLabel: "Pinboard",
            tabSelection: 2
        ),
        IntroStep(
            title: "Find exclusive deals",
            message: "Never miss a student offer. Check the Deals tab for fresh perks from local favourites.",
            icon: "tag.fill",
            tabIcon: "tag",
            accent: Color("LSERed"),
            tabLabel: "Deals",
            tabSelection: 3
        ),
        IntroStep(
            title: "Share & save events",
            message: "Head to Share & Save to post your own happenings, track approvals, and revisit favourites in Liked Events.",
            icon: "plus.circle.fill",
            tabIcon: "plus.circle",
            accent: Color("LSERed"),
            tabLabel: "Share & Save",
            tabSelection: 4
        )
    ]
}

private struct IntroCard: View {
    let step: IntroStep

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(step.accent.opacity(0.16))
                    .frame(width: 72, height: 72)

                Image(systemName: step.icon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(step.accent)
            }

            Text(step.title)
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)

            Text(step.message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            Label {
                Text(step.tabLabel)
                    .fontWeight(.semibold)
            } icon: {
                Image(systemName: step.tabIcon)
            }
            .font(.subheadline)
            .foregroundColor(step.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(step.accent.opacity(0.16), in: Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}