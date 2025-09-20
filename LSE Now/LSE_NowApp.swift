import SwiftUI

@main
struct LSE_NowApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            LaunchView()
                .environmentObject(locationManager)
        }
    }
}
