import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewControllerRepresentable {
    private var adUnitID: String
    
    init(adUnitID: String?) {
        let testUnitId = "ca-app-pub-3940256099942544/2435281174"
        #if DEBUG
        // TEST ID
        self.adUnitID = testUnitId
        #else
        self.adUnitID = adUnitID ?? testUnitId
        #endif
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("✅ Banner loaded successfully.")
        }
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("❌ Banner failed to load:", error.localizedDescription)
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: UIScreen.main.bounds.width)
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.rootViewController = vc
        banner.delegate = context.coordinator
        banner.translatesAutoresizingMaskIntoConstraints = false

        vc.view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            banner.bottomAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.bottomAnchor)
        ])

        banner.load(Request())
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
