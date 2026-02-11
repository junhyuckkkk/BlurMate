//
//  BlurMateApp.swift
//  BlurMate
//
//  Created by 권준혁 on 2/9/26.
//

import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency

@main
struct BlurMateApp: App {
    init() {
        MobileAds.shared.start(completionHandler: nil)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    requestATT()
                }
        }
    }
    
    private func requestATT() {
        // ATT 권한 요청 (iOS 14.5+)
        if #available(iOS 14.5, *) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    switch status {
                    case .authorized:
                        print("✅ 광고 추적 허용됨")
                    case .denied:
                        print("❌ 광고 추적 거부됨")
                    case .notDetermined:
                        print("⏳ 광고 추적 미결정")
                    case .restricted:
                        print("🚫 광고 추적 제한됨")
                    @unknown default:
                        break
                    }
                }
            }
        }
    }
}
