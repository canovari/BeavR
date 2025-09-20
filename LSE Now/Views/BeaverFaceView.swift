import SwiftUI

struct BeaverFaceView: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let headColor = Color(red: 0.60, green: 0.39, blue: 0.23)
            let muzzleColor = Color(red: 0.82, green: 0.65, blue: 0.50)
            let noseColor = Color(red: 0.32, green: 0.22, blue: 0.17)
            let earSize = size * 0.38
            let earOffset = size * 0.45
            let whiskerColor = Color.white.opacity(0.75)

            ZStack {
                Group {
                    Circle()
                        .fill(headColor)
                        .frame(width: earSize, height: earSize)
                        .offset(x: -earOffset, y: -earOffset * 1.05)
                    Circle()
                        .fill(headColor)
                        .frame(width: earSize, height: earSize)
                        .offset(x: earOffset, y: -earOffset * 1.05)
                }

                Circle()
                    .fill(headColor)
                    .frame(width: size * 0.95, height: size * 0.95)
                    .offset(y: size * 0.08)
                    .shadow(color: Color.black.opacity(0.12), radius: size * 0.08, y: size * 0.03)

                RoundedRectangle(cornerRadius: size * 0.35, style: .continuous)
                    .fill(muzzleColor)
                    .frame(width: size * 0.75, height: size * 0.5)
                    .offset(y: size * 0.32)

                HStack(spacing: size * 0.22) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: size * 0.22)
                        .overlay(
                            Circle()
                                .fill(Color.black)
                                .frame(width: size * 0.1)
                                .offset(x: size * 0.02, y: size * 0.02)
                        )
                    Circle()
                        .fill(Color.white)
                        .frame(width: size * 0.22)
                        .overlay(
                            Circle()
                                .fill(Color.black)
                                .frame(width: size * 0.1)
                                .offset(x: size * 0.02, y: size * 0.02)
                        )
                }
                .offset(y: -size * 0.05)

                RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                    .fill(noseColor)
                    .frame(width: size * 0.22, height: size * 0.14)
                    .offset(y: size * 0.12)

                RoundedRectangle(cornerRadius: size * 0.05, style: .continuous)
                    .fill(Color.white)
                    .frame(width: size * 0.24, height: size * 0.24)
                    .offset(y: size * 0.56)
                    .overlay(
                        Rectangle()
                            .fill(Color(red: 0.86, green: 0.86, blue: 0.86))
                            .frame(width: size * 0.02, height: size * 0.24)
                    )

                Group {
                    VStack(spacing: size * 0.1) {
                        Capsule()
                            .fill(whiskerColor)
                            .frame(width: size * 0.45, height: size * 0.035)
                        Capsule()
                            .fill(whiskerColor)
                            .frame(width: size * 0.45, height: size * 0.035)
                    }
                    .offset(x: -size * 0.46, y: size * 0.32)
                    .rotationEffect(.degrees(-5))

                    VStack(spacing: size * 0.1) {
                        Capsule()
                            .fill(whiskerColor)
                            .frame(width: size * 0.45, height: size * 0.035)
                        Capsule()
                            .fill(whiskerColor)
                            .frame(width: size * 0.45, height: size * 0.035)
                    }
                    .offset(x: size * 0.46, y: size * 0.32)
                    .rotationEffect(.degrees(5))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

