import SwiftUI
import GoogleMobileAds

struct AdBannerView: UIViewRepresentable {
    private let adUnitID = "ca-app-pub-3221548260696384/5818012541" // Test Ad Unit ID

    @Binding var adDidLoad: Bool
    @Binding var adHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> GADBannerView {
        let viewWidth = UIScreen.main.bounds.width
        let adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(viewWidth)
        let bannerView = GADBannerView(adSize: adSize)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = UIApplication.shared.getRootViewController()
        bannerView.delegate = context.coordinator
        bannerView.load(GADRequest())
        return bannerView
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        let viewWidth = UIScreen.main.bounds.width
        uiView.adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(viewWidth)
    }

    class Coordinator: NSObject, GADBannerViewDelegate {
        var parent: AdBannerView

        init(_ parent: AdBannerView) {
            self.parent = parent
        }

        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            print("AdBannerView: Ad loaded successfully")
            DispatchQueue.main.async {
                self.parent.adDidLoad = true
                self.parent.adHeight = bannerView.adSize.size.height
                print("AdBannerView: adDidLoad set to true, adHeight set to \(self.parent.adHeight)")
            }
        }

        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            print("AdBannerView: Failed to load ad: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.parent.adDidLoad = false
                self.parent.adHeight = 0
                print("AdBannerView: adDidLoad set to false, adHeight set to 0")
            }
        }
    }
}

// Extension to get the root view controller
extension UIApplication {
    func getRootViewController() -> UIViewController? {
        guard let windowScene = connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            print("AdBannerView: Root view controller not found")
            return nil
        }
        print("AdBannerView: Found root view controller")
        return window.rootViewController
    }
}
