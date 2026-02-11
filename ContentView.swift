import SwiftUI

struct ContentView: View {
    @StateObject private var vm = BlurViewModel()
    @State private var showingImagePicker = false
    @State private var inputImage: UIImage?

    var body: some View {
        ZStack {
            // ⬛ 배경
            Color.black.ignoresSafeArea()

            VStack {
                // 1. 헤더 (타이틀 + 저장/초기화)
                HStack {
                    Text("BlurMate")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: { vm.paths.removeAll(); vm.maskPath = Path() }) {
                        Image(systemName: "arrow.uturn.backward")
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, 16)

                    Button("저장") { vm.saveImage() }
                        .foregroundColor(.blue)
                }
                .padding()

                Spacer()

                // 2. 메인 캔버스: 이미지 + 블러 마스크 (ZStack)
                ZStack {
                    if let image = inputImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .overlay(
                                // 🔥 실제 블러 효과 적용할 뷰 (Masked Blur)
                                Canvas { context, size in
                                    // 1. 블러된 이미지 그리기 (배경)
                                    // 2. 마스크 경로 (사용자 터치) 그리기
                                    // MVP: 단순 빨간 선으로 터치 확인 (추후 블러 적용)
                                    for path in vm.paths {
                                        context.stroke(path, with: .color(.red.opacity(0.5)), lineWidth: vm.brushSize)
                                    }
                                    // 현재 그리고 있는 경로
                                    context.stroke(vm.maskPath, with: .color(.red.opacity(0.5)), lineWidth: vm.brushSize)
                                }
                                .allowsHitTesting(false) // 터치 통과 (제스처는 아래 배경 이미지에서 처리)
                            )
                            // 🔥 제스처 인식 (터치 위치 추적)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let location = value.location
                                        // 터치 좌표를 vm에 전달
                                        vm.onDrag(location: location) 
                                    }
                                    .onEnded { _ in
                                        vm.onDragEnd()
                                        vm.maskPath = Path() // 현재 패스 초기화 (배열에 저장됨)
                                    }
                            )
                    } else {
                        // 📷 사진 선택 버튼
                        Button {
                            showingImagePicker = true
                        } label: {
                            VStack {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 80))
                                    .foregroundColor(.gray)
                                Text("터치해서 사진을 불러오세요")
                                    .foregroundColor(.gray)
                                    .padding(.top)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.2)) // 캔버스 배경

                Spacer()

                // 3. 하단 툴바 (브러시 크기 + 블러 타입)
                if inputImage != nil {
                    VStack(spacing: 20) {
                        // 브러시 크기 슬라이더
                        HStack {
                            Image(systemName: "circle.fill").font(.system(size: 10)).foregroundColor(.white)
                            Slider(value: $vm.brushSize, in: 10...100)
                                .accentColor(.white)
                            Image(systemName: "circle.fill").font(.system(size: 30)).foregroundColor(.white)
                        }
                        .padding(.horizontal)

                        // 블러 타입 선택 (가우시안 / 모자이크)
                        HStack(spacing: 40) {
                            ForEach(BlurViewModel.BlurStyle.allCases) { style in
                                Button {
                                    vm.currentStyle = style
                                } label: {
                                    VStack {
                                        Image(systemName: style == .gaussian ? "drop.fill" : "square.grid.3x3.fill")
                                            .font(.title2)
                                        Text(style.rawValue).font(.caption)
                                    }
                                    .foregroundColor(vm.currentStyle == style ? .blue : .gray)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 30)
                    .background(Color.black.opacity(0.8))
                }
            }
        }
        // ImagePicker 시트
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $inputImage)
        }
        .onChange(of: inputImage) { newImage in
            vm.pickedImage = newImage
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
