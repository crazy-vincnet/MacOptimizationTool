// DMG 설치 창 배경 이미지 생성기.
// 실행: swift scripts/make_dmg_background.swift <출력경로.png> <배율(1|2)>
//
// Finder 는 배경 이미지를 논리 포인트 크기로 표시하므로, @2x 는 같은 그림을 2배 해상도로
// 그린 뒤 한 파일(TIFF 대신 PNG 2장)로 내보내고 스크립트에서 골라 쓴다.

import AppKit
import CoreGraphics
import Foundation

let args = CommandLine.arguments
guard args.count >= 3, let scale = Int(args[2]), scale == 1 || scale == 2 else {
    FileHandle.standardError.write(Data("사용법: make_dmg_background.swift <출력.png> <1|2>\n".utf8))
    exit(1)
}
let outputPath = args[1]

// 창 논리 크기
let width = 640.0
let height = 400.0
let pixelWidth = Int(width) * scale
let pixelHeight = Int(height) * scale

guard let context = CGContext(
    data: nil,
    width: pixelWidth,
    height: pixelHeight,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    FileHandle.standardError.write(Data("비트맵 컨텍스트 생성 실패\n".utf8))
    exit(1)
}

context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.current = graphicsContext

// MARK: - 배경 그라디언트

// Finder 는 아이콘 이름을 어두운 글씨로 그리므로 배경은 밝게 유지해야 가독성이 확보된다.
let backgroundTop = NSColor(srgbRed: 0.976, green: 0.984, blue: 0.988, alpha: 1)      // #f9fbfc
let backgroundBottom = NSColor(srgbRed: 0.925, green: 0.945, blue: 0.953, alpha: 1)   // #ecf1f3
NSGradient(starting: backgroundBottom, ending: backgroundTop)?
    .draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 90)

// 좌상단 은은한 브랜드 글로우
let accent = NSColor(srgbRed: 0.243, green: 0.812, blue: 0.557, alpha: 1)             // #3ECF8E
if let glow = NSGradient(colorsAndLocations:
    (accent.withAlphaComponent(0.20), 0.0),
    (accent.withAlphaComponent(0.0), 1.0)) {
    glow.draw(in: NSRect(x: -180, y: height - 280, width: 460, height: 460), relativeCenterPosition: .zero)
}

// MARK: - 아이콘 자리 배경 (드롭존 힌트)

func drawSlot(centerX: CGFloat, centerY: CGFloat, dashed: Bool) {
    let size: CGFloat = 150
    let rect = NSRect(x: centerX - size / 2, y: centerY - size / 2, width: size, height: size)
    let path = NSBezierPath(roundedRect: rect, xRadius: 30, yRadius: 30)
    NSColor.black.withAlphaComponent(0.035).setFill()
    path.fill()

    if dashed {
        path.lineWidth = 1.5
        path.setLineDash([6, 5], count: 2, phase: 0)
        accent.withAlphaComponent(0.85).setStroke()
    } else {
        path.lineWidth = 1
        NSColor.black.withAlphaComponent(0.08).setStroke()
    }
    path.stroke()
}

// Finder 좌표계는 창 상단 기준, CoreGraphics 는 하단 기준이라 y 를 뒤집어 맞춘다.
let iconCenterYFromTop: CGFloat = 185
let iconCenterY = height - iconCenterYFromTop
let leftIconX: CGFloat = 165
let rightIconX: CGFloat = 475

drawSlot(centerX: leftIconX, centerY: iconCenterY, dashed: false)
drawSlot(centerX: rightIconX, centerY: iconCenterY, dashed: true)

// MARK: - 화살표

let arrowY = iconCenterY
let arrowStart: CGFloat = leftIconX + 92
let arrowEnd: CGFloat = rightIconX - 92

let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: arrowStart, y: arrowY))
arrowPath.line(to: NSPoint(x: arrowEnd - 10, y: arrowY))
arrowPath.lineWidth = 2
arrowPath.lineCapStyle = .round
accent.withAlphaComponent(0.9).setStroke()
arrowPath.stroke()

let head = NSBezierPath()
head.move(to: NSPoint(x: arrowEnd, y: arrowY))
head.line(to: NSPoint(x: arrowEnd - 12, y: arrowY + 7))
head.line(to: NSPoint(x: arrowEnd - 12, y: arrowY - 7))
head.close()
accent.withAlphaComponent(0.9).setFill()
head.fill()

// MARK: - 텍스트

func draw(_ text: String, x: CGFloat, yFromTop: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor, centeredIn: CGFloat? = nil) {
    let style = NSMutableParagraphStyle()
    style.alignment = centeredIn == nil ? .left : .center

    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: style
    ]
    let attributed = NSAttributedString(string: text, attributes: attributes)
    let drawWidth = centeredIn ?? attributed.size().width
    let originX = centeredIn == nil ? x : x - drawWidth / 2
    attributed.draw(in: NSRect(x: originX, y: height - yFromTop - size * 1.35,
                               width: drawWidth, height: size * 1.6))
}

let titleColor = NSColor(srgbRed: 0.09, green: 0.13, blue: 0.16, alpha: 1)
let subtitleColor = NSColor(srgbRed: 0.29, green: 0.36, blue: 0.40, alpha: 1)

draw("MacOptimizationTool", x: width / 2, yFromTop: 44, size: 22, weight: .bold, color: titleColor, centeredIn: width)
draw("앱을 Applications 폴더로 드래그하세요", x: width / 2, yFromTop: 76, size: 12.5, weight: .medium, color: subtitleColor, centeredIn: width)
draw("Drag the app into the Applications folder", x: width / 2, yFromTop: 96, size: 11, weight: .regular, color: NSColor(srgbRed: 0.47, green: 0.53, blue: 0.56, alpha: 1), centeredIn: width)

// 아이콘 이름은 Finder 가 직접 그리므로 여기서는 그리지 않는다 (겹침 방지).

draw("Lab98 Studio", x: width / 2, yFromTop: 358, size: 10, weight: .regular, color: NSColor(srgbRed: 0.60, green: 0.65, blue: 0.68, alpha: 1), centeredIn: width)

NSGraphicsContext.current = nil

// MARK: - 저장

guard let image = context.makeImage() else {
    FileHandle.standardError.write(Data("이미지 생성 실패\n".utf8))
    exit(1)
}

let bitmap = NSBitmapImageRep(cgImage: image)
bitmap.size = NSSize(width: width, height: height)
guard let data = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("PNG 인코딩 실패\n".utf8))
    exit(1)
}

do {
    try data.write(to: URL(fileURLWithPath: outputPath))
    print("생성 완료: \(outputPath) (\(pixelWidth)x\(pixelHeight))")
} catch {
    FileHandle.standardError.write(Data("쓰기 실패: \(error.localizedDescription)\n".utf8))
    exit(1)
}
