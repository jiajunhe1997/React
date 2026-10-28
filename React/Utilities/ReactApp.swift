import SwiftUI
import UIKit
import GoogleMobileAds

@main
struct ReactApp: App {
    // Register the AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(StoreManager.shared)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Check if GADApplicationIdentifier is accessible
        if let appID = Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String {
            print("GADApplicationIdentifier: \(appID)")
        } else {
            print("GADApplicationIdentifier not found in Info.plist")
        }

        // Initialize Google Mobile Ads SDK
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        return true
    }
}
