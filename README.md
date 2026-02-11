# 📱 BlurMate - 감성 블러 에디터

> "사진에서 원하는 부분을 쉽고 예쁘게 블러 처리하는 앱"

## 🛠 프로젝트 설정 (Xcode)
1. Xcode 실행 > **Create a new Xcode project**
2. **iOS > App** 선택
3. Product Name: `BlurMate`
4. Interface: **SwiftUI**
5. Language: **Swift**
6. 이 폴더(`/Users/junhyuk/Desktop/Xcode/BlurMate`)에 생성된 파일들을 덮어쓰거나 복사해서 사용하세요.

## 🚀 구현 기능 (MVP)
- [ ] 📷 **사진 불러오기** (`PhotosUI`)
- [ ] 👆 **터치 블러** (Drag Gesture)
- [ ] 🎨 **블러 스타일** (Gaussian, Mosiac)
- [ ] 💾 **저장하기** (High Quality)

## 📁 주요 파일
- `ContentView.swift`: 메인 UI
- `ImagePicker.swift`: 갤러리 연동
- `BlurViewModel.swift`: 로직 처리
