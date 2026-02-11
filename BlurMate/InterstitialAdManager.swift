import SwiftUI
import GoogleMobileAds

class InterstitialAdManager: NSObject, ObservableObject {
    private var interstitial: InterstitialAd?
    private var onAdDismissed: (() -> Void)?
    
    // ⚠️ 광고 단위 ID 설정
    // DEBUG: 테스트 ID (ca-app-pub-3940256099942544/4411468910)
    // RELEASE: 실제 ID (ca-app-pub-9373931451334451/2998792605)
    private var adUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/4411468910"
        #else
        return "ca-app-pub-9373931451334451/2998792605"
        #endif
    }
    
    override init() {
        super.init()
        loadAd()
    }
    
    /// 광고 로드
    func loadAd() {
        let request = Request()
        InterstitialAd.load(with: adUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("❌ 광고 로드 실패: \(error.localizedDescription)")
                return
            }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
        }
    }
    
    /// 광고 표시
    func showAd(completion: @escaping () -> Void) {
        guard let ad = interstitial else {
            print("⚠️ 광고가 준비되지 않았습니다. 바로 완료 처리합니다.")
            completion()
            loadAd() // 다음을 위해 로드 시도
            return
        }
        
        // 최상위 뷰 컨트롤러 찾기
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            // 완료 핸들러 저장 (광고 닫힐 때 호출됨)
            self.onAdDismissed = completion
            
            ad.present(from: rootViewController)
        } else {
            print("❌ RootViewController를 찾을 수 없습니다.")
            completion()
        }
    }
}

// MARK: - GADFullScreenContentDelegate
extension InterstitialAdManager: FullScreenContentDelegate {
    /// 광고가 닫혔을 때 (사용자가 X 버튼 누름)
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        print("✅ 광고가 닫혔습니다.")
        // 저장된 완료 핸들러 실행 (이미지 저장 로직 등)
        onAdDismissed?()
        onAdDismissed = nil // 초기화
        
        loadAd() // 다음 광고 미리 로드
    }
    
    /// 광고 표시 실패 시
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("❌ 광고 표시 중 오류 발생: \(error.localizedDescription)")
        onAdDismissed?() // 실패해도 완료 처리는 해서 다음 로직 진행되게 함
        onAdDismissed = nil
        
        loadAd()
    }
}
