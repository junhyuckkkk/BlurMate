import SwiftUI
import Photos
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

class BlurViewModel: ObservableObject {
    @Published var pickedImage: UIImage?
    @Published var paths: [Path] = []
    @Published var maskPath = Path()
    
    // UI Slider 바인딩용
    @Published var brushSize: CGFloat = 30.0
    @Published var blurIntensity: Float = 8.0
    
    // 화면에 표시된 이미지의 실제 크기 (AspectFit)
    @Published var displaySize: CGSize = .zero
    
    // 저장 상태 관리
    @Published var isSaving = false
    @Published var savedSuccessfully = false
    @Published var saveError: String? = nil
    
    // MARK: - Drawing Logic
    
    func onDrag(location: CGPoint) {
        if maskPath.isEmpty {
            maskPath.move(to: location)
        } else {
            maskPath.addLine(to: location)
        }
    }
    
    func onDragEnd() {
        if !maskPath.isEmpty {
            paths.append(maskPath)
            maskPath = Path()
        }
    }
    
    func undo() {
        if !paths.isEmpty {
            paths.removeLast()
        }
    }
    
    // MARK: - Image Processing Helpers
    
    /// 원본 이미지에 블러 적용 (UIKit + CoreImage)
    private func applyBlur(to image: UIImage, intensity: CGFloat) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        let context = CIContext()
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = ciImage
        filter.radius = Float(intensity)
        
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: ciImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    /// 마스크 이미지 생성 (경로들을 하얀색으로 그림)
    private func generateMaskImage(size: CGSize, paths: [Path], brushSize: CGFloat) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        // 배경 투명, 경로는 흰색으로 그리기
        return renderer.image { context in
            UIColor.clear.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            UIColor.white.setStroke()
            for path in paths {
                let cgPath = path.cgPath
                context.cgContext.addPath(cgPath)
                context.cgContext.setLineWidth(brushSize)
                context.cgContext.setLineCap(.round)
                context.cgContext.setLineJoin(.round)
                context.cgContext.strokePath()
            }
        }
    }
    
    /// 최종 이미지 합성 (원본 + 블러 + 마스크)
    private func compositeImages(base: UIImage, overlay: UIImage, mask: UIImage?) -> UIImage? {
        guard let maskCGImage = mask?.cgImage else { return nil }
        
        let size = base.size
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // 1. 원본 그리기
            base.draw(in: CGRect(origin: .zero, size: size))
            
            // 2. 마스크로 클리핑하여 블러 이미지 그리기
            let cgContext = context.cgContext
            cgContext.saveGState()
            
            // 좌표계 보정 (Core Graphics는 Y축이 반대일 수 있음)
            // UIGraphicsImageRenderer를 쓰면 보통 괜찮지만, CGContext 조작 시 주의
            // 여기서는 clip(to:mask:)가 Core Graphics 좌표계를 쓰므로 뒤집어줘야 함
            cgContext.translateBy(x: 0, y: size.height)
            cgContext.scaleBy(x: 1, y: -1)
            
            // 마스크 클리핑
            cgContext.clip(to: CGRect(origin: .zero, size: size), mask: maskCGImage)
            
            // 다시 원복해서 이미지 그리기 (이미지가 거꾸로 그려지는 것 방지)
            cgContext.translateBy(x: 0, y: size.height)
            cgContext.scaleBy(x: 1, y: -1)
            
            overlay.draw(in: CGRect(origin: .zero, size: size))
            
            cgContext.restoreGState()
        }
    }
    
    // MARK: - Save Logic
    
    /// 최종 고해상도 이미지를 생성하는 메서드 (백그라운드 실행 권장)
    func generateFinalImage() -> UIImage? {
        guard let originalImage = pickedImage else { return nil }
        if paths.isEmpty { return nil }
        
        return autoreleasepool { () -> UIImage? in
            // 1. 스케일 계산 (화면상 좌표 -> 실제 이미지 좌표)
            var effectiveDisplaySize = displaySize
            if displaySize.width <= 0 || displaySize.height <= 0 {
                // fallback
                let ratio = originalImage.size.width / originalImage.size.height
                effectiveDisplaySize = CGSize(width: 300, height: 300 / ratio)
            }
            
            let scaleX = originalImage.size.width / effectiveDisplaySize.width
            let scaleY = originalImage.size.height / effectiveDisplaySize.height
            
            // 브러시 크기도 스케일링
            let scaledBrushSize = brushSize * min(scaleX, scaleY)
            
            // 2. 경로 스케일 변환
            var scaledPaths: [Path] = []
            for path in paths {
                var transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
                if let scaledCGPath = path.cgPath.copy(using: &transform) {
                    scaledPaths.append(Path(scaledCGPath))
                }
            }
            
            // 3. 블러 및 마스크 생성
            let scaledBlurIntensity = CGFloat(blurIntensity) * min(scaleX, scaleY)
            
            guard let blurredImage = applyBlur(to: originalImage, intensity: scaledBlurIntensity),
                  let maskImage = generateMaskImage(size: originalImage.size, paths: scaledPaths, brushSize: scaledBrushSize) else {
                return nil
            }
            
            // 4. 합성
            return compositeImages(base: originalImage, overlay: blurredImage, mask: maskImage)
        }
    }
    
    /// 저장 시작
    func saveImage() {
        guard pickedImage != nil else {
            saveError = "이미지가 없습니다."
            return
        }
        guard !paths.isEmpty else {
            saveError = "블러 처리된 부분이 없습니다."
            return
        }
        
        isSaving = true
        saveError = nil
        
        // 타임아웃 방지 (15초)
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self = self else { return }
            if self.isSaving {
                self.isSaving = false
                self.saveError = "저장 시간이 초과되었습니다."
            }
        }
        
        // 백그라운드 작업
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. 이미지 생성
            guard let finalImage = self.generateFinalImage() else {
                DispatchQueue.main.async {
                    self.isSaving = false
                    self.saveError = "이미지 처리에 실패했습니다."
                }
                return
            }
            
            // 2. 저장 (PHPhotoLibrary 사용)
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized || status == .limited {
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAsset(from: finalImage)
                    }) { success, error in
                        DispatchQueue.main.async {
                            self.isSaving = false
                            if success {
                                self.savedSuccessfully = true
                            } else {
                                self.saveError = error?.localizedDescription ?? "저장 실패"
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isSaving = false
                        self.saveError = "사진 라이브러리 접근 권한을 허용해주세요."
                    }
                }
            }
        }
    }
}
