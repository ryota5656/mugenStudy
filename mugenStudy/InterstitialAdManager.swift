import GoogleMobileAds
internal import Combine
import SwiftUI

protocol InterstitialAdManagerDelegate: AnyObject {
    func interstitialAdDidDismiss()
}

final class InterstitialAdManager: NSObject, FullScreenContentDelegate, ObservableObject {
    
    private var interstitial: InterstitialAd?
    
    private var adUnitID: String
    @Published var isReady: Bool = false
    private var waitingTask: Task<Void, Never>? = nil
    weak var delegate: InterstitialAdManagerDelegate?

    init(adUnitID: String?) {
        let testUnitId = "ca-app-pub-3940256099942544/4411468910"
        #if DEBUG
        // TEST ID
        self.adUnitID = testUnitId
        #else
        self.adUnitID = adUnitID ?? testUnitId
        #endif
        super.init()
        loadAd()
    }

    func loadAd() {
        let request = Request()
        InterstitialAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("❌ Failed to load interstitial ad: \(error.localizedDescription)")
                self?.isReady = false
                return
            }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
            print("✅ Interstitial ad loaded successfully.")
            self?.isReady = (ad != nil)
        }
    }

    func showAd(from root: UIViewController) {
        if let ad = interstitial {
            ad.present(from: root)
            isReady = false
        } else {
            print("⚠️ Ad not ready yet, loading a new one.")
            loadAd()
        }
    }

    // 最大 timeout 秒間、0.5秒ごとに isReady を監視し、true になったら即表示
    func presentWhenReady(timeout: TimeInterval = 10) {
        if isReady {
            DispatchQueue.main.async { [weak self] in self?.presentInterstitial() }
            return
        }

        // timeOutの時間までisReadyを監視してtrueになったら即広告表示
        let start = Date()
        Task {
            let start = Date()
            while true {
                if isReady {
                    DispatchQueue.main.async { [weak self] in self?.presentInterstitial() }
                    return
                }
                if Date().timeIntervalSince(start) >= timeout {
                    print("😭: 広告の準備が時間切れでできませんでした")
                    return
                }
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            }
        }
    }
    
    // インタースティシャル広告の表示
    func presentInterstitial() {
        let root = UIApplication.shared.windows.first?.rootViewController
        if let ad = interstitial {
            ad.present(from: root!)
            self.isReady = false
        }
    }

    // MARK: - Delegate
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("✅ Ad dismissed, loading a new one.")
        isReady = false
        loadAd() // 再ロード
        delegate?.interstitialAdDidDismiss()
    }
}
