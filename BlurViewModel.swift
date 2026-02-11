import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// 🎨 블러 효과 및 마스크 편집 로직
class BlurViewModel: ObservableObject {
    @Published var pickedImage: UIImage? // 사용자가 선택한 원본
    @Published var isPickingImage: Bool = false
    @Published var brushSize: CGFloat = 40.0
    @Published var blurIntensity: Float = 10.0 // 1~50
    
    // 블러 스타일 (v1.0)
    enum BlurStyle: String, CaseIterable, Identifiable {
        case gaussian = "Gaussian"
        case mosaic = "Mosaic"
        case pixel = "Pixel"
        
        var id: String { self.rawValue }
    }
    
    @Published var currentStyle: BlurStyle = .gaussian

    // 터치 경로 (Path)
    @Published var maskPath: Path = Path()
    @Published var paths: [Path] = [] // Undo 기능을 위한 배열
    
    /// 🖌️ 드래그 이벤트 처리
    func onDrag(location: CGPoint) {
        if maskPath.isEmpty {
            maskPath.move(to: location)
        } else {
            maskPath.addLine(to: location)
        }
    }
    
    /// ✋ 드래그 끝
    func onDragEnd() {
        paths.append(maskPath)
    }
    
    /// ↩️ 되돌리기 (Undo)
    func undo() {
        if !paths.isEmpty {
            paths.removeLast()
            maskPath = Path() // 전체를 다시 그리는 경우 Path 재설정 (MVP에서는 단순화)
            // 실제 구현 시 [Path] 배열 전체를 다시 그려야 함
        }
    }
    
    /// 💾 저장하기 (고해상도) - 구현 예정
    func saveImage() {
        // Core Graphics Context로 원본+블러 합성
    }
}
