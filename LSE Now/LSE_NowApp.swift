import SwiftUI

@main
struct LSE_NowApp: App {
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            LaunchView()
                .environmentObject(locationManager)
        }
    }
}
