#!/usr/bin/swift

import Cocoa

// 앱 아이콘 생성 스크립트
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

// 1. 흰색 배경
NSColor.white.setFill()
NSRect(origin: .zero, size: size).fill()

// 2. "BlurMate" 텍스트 (빨간색)
let themeRed = NSColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 1.0)

// 두 줄로 분리: "Blur" + "Mate"
let font = NSFont.systemFont(ofSize: 220, weight: .black)

let paragraphStyle = NSMutableParagraphStyle()
paragraphStyle.alignment = .center

let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: themeRed,
    .paragraphStyle: paragraphStyle,
    .kern: -8 // 자간 줄이기
]

let text = "BlurMate"
let attributedString = NSAttributedString(string: text, attributes: attributes)

let textSize = attributedString.size()
let textRect = NSRect(
    x: (size.width - textSize.width) / 2,
    y: (size.height - textSize.height) / 2 - 20,
    width: textSize.width,
    height: textSize.height
)

attributedString.draw(in: textRect)

image.unlockFocus()

// 3. PNG로 저장
guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    print("❌ 이미지 생성 실패")
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1 
    ? CommandLine.arguments[1] 
    : NSString(string: "~/Desktop/Xcode/BlurMate/BlurMate/Assets.xcassets/AppIcon.appiconset/AppIcon.png").expandingTildeInPath

try! pngData.write(to: URL(fileURLWithPath: outputPath))
print("✅ 앱 아이콘 저장 완료: \(outputPath)")
