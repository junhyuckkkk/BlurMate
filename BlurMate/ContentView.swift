import SwiftUI
import AVFoundation
import Photos

struct ContentView: View {
    @StateObject private var vm = BlurViewModel()
    @State private var showingImagePicker = false
    @State private var inputImage: UIImage?
    
    // 줌 & 팬 상태
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isDrawingMode: Bool = true

    // 🎨 디자인 테마 색상
    let themeRed = Color(red: 1.0, green: 0.1, blue: 0.1)
    
    var body: some View {
        ZStack {
            // ⬜ 배경
            Color.white.ignoresSafeArea()

            if inputImage == nil {
                // 📱 홈 화면 (사진 선택 전)
                HomeView(showingImagePicker: $showingImagePicker, themeRed: themeRed)
            } else {
                // 🖼️ 편집 화면 (사진 선택 후)
                EditorView(
                    vm: vm,
                    inputImage: $inputImage,
                    showingImagePicker: $showingImagePicker,
                    scale: $scale,
                    lastScale: $lastScale,
                    offset: $offset,
                    lastOffset: $lastOffset,
                    isDrawingMode: $isDrawingMode,
                    themeRed: themeRed
                )
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $inputImage)
        }
        .onChange(of: inputImage) { _, newImage in
            vm.pickedImage = newImage
            vm.paths.removeAll()
            vm.maskPath = Path()
            scale = 1.0
            offset = .zero
        }
    }
}

// MARK: - 홈 화면
struct HomeView: View {
    @Binding var showingImagePicker: Bool
    let themeRed: Color
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // 로고 영역
            VStack(spacing: 12) {
                // 아이콘
                ZStack {
                    Circle()
                        .fill(themeRed)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // 앱 이름
                Text("BlurMate")
                    .font(.system(size: 48, weight: .black))
                    .foregroundColor(themeRed)
                    .tracking(-2)
                
                // 캐치프레이즈
                Text("쉽고 빠른 블러 처리")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // 사진 불러오기 버튼
            Button {
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    DispatchQueue.main.async {
                        showingImagePicker = true
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title2)
                    Text("사진 불러오기")
                        .font(.system(size: 20, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(themeRed)
                .cornerRadius(16)
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 50)
        }
    }
}

// MARK: - 편집 화면
struct EditorView: View {
    @ObservedObject var vm: BlurViewModel
    @Binding var inputImage: UIImage?
    @Binding var showingImagePicker: Bool
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize
    @Binding var isDrawingMode: Bool
    let themeRed: Color
    
    @StateObject private var adManager = InterstitialAdManager()
    @State private var canvasSize: CGSize = .zero
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 1. 헤더
                headerView
                
                // 2. 메인 캔버스
                canvasView
                
                // 3. 하단 툴바
                if inputImage != nil {
                    toolbarView
                }
            }
            
            // 로딩 오버레이
            if vm.isSaving {
                savingOverlay
            }
        }
        .alert("저장 완료! 🎉", isPresented: $vm.savedSuccessfully) {
            Button("새 사진 편집") {
                vm.savedSuccessfully = false
                inputImage = nil
                vm.paths.removeAll()
                vm.maskPath = Path()
                scale = 1.0
                offset = .zero
                showingImagePicker = true
            }
            Button("계속 편집", role: .cancel) {
                vm.savedSuccessfully = false
            }
        } message: {
            Text("블러 처리된 사진이 갤러리에 저장되었습니다.\n다음에 무엇을 하시겠습니까?")
        }
        .alert("저장 실패", isPresented: Binding(get: {
            vm.saveError != nil
        }, set: { newValue in
            if !newValue {
                vm.saveError = nil
            }
        })) {
            Button("확인", role: .cancel) {
                vm.saveError = nil
            }
        } message: {
            Text(vm.saveError ?? "알 수 없는 오류가 발생했습니다.")
        }
        .onChange(of: canvasSize) { _, newSize in
            if newSize.width > 0 && newSize.height > 0 {
                vm.displaySize = newSize
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack(alignment: .center) {
            Text("BlurMate")
                .font(.system(size: 28, weight: .black))
                .foregroundColor(themeRed)
                .tracking(-1)
            
            Spacer()
            
            if inputImage != nil {
                Button("사진 변경") {
                    showingImagePicker = true
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            Button(action: {
                adManager.showAd {
                    vm.saveImage()
                }
            }) {
                Text("SAVE")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(themeRed)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.white)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(Color.gray.opacity(0.1)),
            alignment: .bottom
        )
        .zIndex(1)
    }
    
    // MARK: - Canvas View
    private var canvasView: some View {
        ZStack {
            if let image = inputImage {
                GeometryReader { geo in
                    let frame = geo.frame(in: .local)
                    let fitSize = AVMakeRect(aspectRatio: image.size, insideRect: CGRect(origin: .zero, size: frame.size)).size
                    
                    ImageCanvasView(
                        image: image,
                        vm: vm,
                        fitSize: fitSize,
                        frame: frame,
                        scale: $scale,
                        lastScale: $lastScale,
                        offset: $offset,
                        lastOffset: $lastOffset,
                        isDrawingMode: $isDrawingMode
                    )
                    .onAppear {
                        canvasSize = fitSize
                    }
                    .onChange(of: fitSize) { _, newSize in
                        canvasSize = newSize
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
    
    // MARK: - Toolbar View
    private var toolbarView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { isDrawingMode.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: isDrawingMode ? "paintbrush.fill" : "hand.draw.fill")
                        Text(isDrawingMode ? "DRAW" : "MOVE")
                    }
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(isDrawingMode ? .white : themeRed)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(isDrawingMode ? themeRed : Color.white)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(themeRed, lineWidth: 2)
                    )
                }
                
                Spacer()
                
                Button(action: {
                    vm.paths.removeAll()
                    vm.maskPath = Path()
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3)
                        .foregroundColor(.black)
                        .padding(10)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
                .padding(.trailing, 8)
                
                Button(action: { vm.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.title3)
                        .foregroundColor(.black)
                        .padding(10)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            Divider().padding(.vertical, 16)
            
            VStack(spacing: 24) {
                HStack(spacing: 16) {
                    Text("SIZE")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(themeRed)
                        .frame(width: 40, alignment: .leading)
                    
                    Slider(value: $vm.brushSize, in: 10...100)
                        .accentColor(themeRed)
                }
                
                HStack(spacing: 16) {
                    Text("BLUR")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(themeRed)
                        .frame(width: 40, alignment: .leading)
                    
                    Slider(value: Binding(
                        get: { Double(vm.blurIntensity) },
                        set: { vm.blurIntensity = Float($0) }
                    ), in: 0...15)
                    .accentColor(themeRed)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(Color.white)
        .clipShape(RoundedCorner(radius: 24, corners: [.topLeft, .topRight]))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
    }
    
    // MARK: - Saving Overlay
    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                Text("저장 중...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.8)))
        }
    }
}

// MARK: - Image Canvas View (분리된 캔버스)
struct ImageCanvasView: View {
    let image: UIImage
    @ObservedObject var vm: BlurViewModel
    let fitSize: CGSize
    let frame: CGRect
    
    @Binding var scale: CGFloat
    @Binding var lastScale: CGFloat
    @Binding var offset: CGSize
    @Binding var lastOffset: CGSize
    @Binding var isDrawingMode: Bool
    
    private var centerOffsetX: CGFloat {
        (frame.width - fitSize.width) / 2
    }
    
    private var centerOffsetY: CGFloat {
        (frame.height - fitSize.height) / 2
    }
    
    var body: some View {
        ZStack {
            // Layer 1: 원본
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: fitSize.width, height: fitSize.height)
            
            // Layer 2: 블러
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: fitSize.width, height: fitSize.height)
                .blur(radius: CGFloat(vm.blurIntensity))
                .mask(
                    Canvas { context, size in
                        for path in vm.paths {
                            context.stroke(path, with: .color(.black), style: StrokeStyle(lineWidth: vm.brushSize, lineCap: .round, lineJoin: .round))
                        }
                        context.stroke(vm.maskPath, with: .color(.black), style: StrokeStyle(lineWidth: vm.brushSize, lineCap: .round, lineJoin: .round))
                    }
                )
        }
        .gesture(dragGesture) // 🔥 scaleEffect 앞에 배치!
        .simultaneousGesture(magnificationGesture)
        .onTapGesture(count: 2) {
            handleDoubleTap()
        }
        .scaleEffect(scale) // 🔥 gesture 뒤에 배치
        .offset(offset)
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.width / 2, y: frame.height / 2) // 🔥 중앙 정렬
    }
    
    // MARK: - Gestures
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if isDrawingMode {
                    // 🔥 단순화: 터치 좌표가 곧 이미지 좌표!
                    vm.onDrag(location: value.location)
                } else {
                    handlePan(translation: value.translation)
                }
            }
            .onEnded { _ in
                if isDrawingMode {
                    vm.onDragEnd()
                    vm.maskPath = Path()
                } else {
                    lastOffset = offset
                }
            }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if !isDrawingMode {
                    let delta = value / lastScale
                    lastScale = value
                    
                    let newScale = min(5.0, max(0.5, scale * delta))
                    let scaleDiff = newScale / scale
                    offset = CGSize(
                        width: offset.width * scaleDiff,
                        height: offset.height * scaleDiff
                    )
                    lastOffset = offset
                    scale = newScale
                }
            }
            .onEnded { _ in
                lastScale = 1.0
            }
    }
    
    private func handlePan(translation: CGSize) {
        let scaledWidth = fitSize.width * scale
        let scaledHeight = fitSize.height * scale
        let maxOffsetX = max(0, (scaledWidth - frame.width) / 2 + frame.width * 0.3)
        let maxOffsetY = max(0, (scaledHeight - frame.height) / 2 + frame.height * 0.3)
        
        var newOffsetW = lastOffset.width + translation.width
        var newOffsetH = lastOffset.height + translation.height
        
        newOffsetW = min(maxOffsetX, max(-maxOffsetX, newOffsetW))
        newOffsetH = min(maxOffsetY, max(-maxOffsetY, newOffsetH))
        
        offset = CGSize(width: newOffsetW, height: newOffsetH)
    }
    
    private func handleDoubleTap() {
        if !isDrawingMode {
            withAnimation(.easeInOut(duration: 0.3)) {
                if scale > 1.0 {
                    scale = 1.0
                    offset = .zero
                    lastOffset = .zero
                } else {
                    scale = 2.0
                }
            }
        }
    }
}

// MARK: - Helper Shapes
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
