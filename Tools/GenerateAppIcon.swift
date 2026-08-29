import AppKit
import CoreText
import Foundation

func glyphPath(for text: String, font: NSFont) -> CGPath {
    let ctFont = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(
        string: text,
        attributes: [kCTFontAttributeName as NSAttributedString.Key: ctFont]
    ))
    let result = CGMutablePath()

    for case let run as CTRun in CTLineGetGlyphRuns(line) as NSArray {
        let count = CTRunGetGlyphCount(run)
        var glyphs = Array(repeating: CGGlyph(), count: count)
        var positions = Array(repeating: CGPoint.zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)

        for index in 0..<count {
            guard let glyph = CTFontCreatePathForGlyph(ctFont, glyphs[index], nil) else { continue }
            let translation = CGAffineTransform(
                translationX: positions[index].x,
                y: positions[index].y
            )
            result.addPath(glyph, transform: translation)
        }
    }
    return result
}

let outputURL: URL = {
    if CommandLine.arguments.count > 1 {
        return URL(fileURLWithPath: CommandLine.arguments[1])
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Resources/AppIcon-master.png")
}()

let side: CGFloat = 1024
let canvas = NSRect(x: 0, y: 0, width: side, height: side)
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(side),
    pixelsHigh: Int(side),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Unable to create app icon bitmap")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
NSGraphicsContext.current?.imageInterpolation = .high
NSColor.clear.setFill()
canvas.fill()

let tileRect = canvas.insetBy(dx: 58, dy: 58)
let tile = NSBezierPath(roundedRect: tileRect, xRadius: 205, yRadius: 205)

// A solid satin base owns the silhouette. Glass is limited to the rim and
// shallow top highlight instead of becoming a separate glass object.
NSGraphicsContext.current?.saveGraphicsState()
let tileShadow = NSShadow()
tileShadow.shadowColor = NSColor.black.withAlphaComponent(0.34)
tileShadow.shadowBlurRadius = 34
tileShadow.shadowOffset = NSSize(width: 0, height: -18)
tileShadow.set()
NSGradient(colors: [
    NSColor(calibratedWhite: 1.00, alpha: 1),
    NSColor(calibratedWhite: 0.93, alpha: 1)
])?.draw(in: tile, angle: -90)
NSGraphicsContext.current?.restoreGraphicsState()

NSColor.white.withAlphaComponent(0.88).setStroke()
tile.lineWidth = 5
tile.stroke()

let innerRim = NSBezierPath(
    roundedRect: tileRect.insetBy(dx: 11, dy: 11),
    xRadius: 194,
    yRadius: 194
)
NSColor.black.withAlphaComponent(0.075).setStroke()
innerRim.lineWidth = 4
innerRim.stroke()

NSGraphicsContext.current?.saveGraphicsState()
tile.addClip()
let sheenRect = NSRect(x: tileRect.minX, y: tileRect.maxY - 210,
                       width: tileRect.width, height: 210)
NSGradient(
    starting: NSColor.white.withAlphaComponent(0.42),
    ending: NSColor.white.withAlphaComponent(0)
)?.draw(in: sheenRect, angle: -90)
NSGraphicsContext.current?.restoreGraphicsState()

let systemFont = NSFont.systemFont(ofSize: 430, weight: .heavy)
let roundedDescriptor = systemFont.fontDescriptor.withDesign(.rounded)
let monogramFont = roundedDescriptor.flatMap { NSFont(descriptor: $0, size: 430) } ?? systemFont
let rawMonogramPath = glyphPath(for: "DS", font: monogramFont)
let rawBounds = rawMonogramPath.boundingBoxOfPath
var monogramTransform = CGAffineTransform(
    translationX: (side - rawBounds.width) / 2 - rawBounds.minX,
    y: (side - rawBounds.height) / 2 - rawBounds.minY - 24
)
guard let monogramPath = rawMonogramPath.copy(using: &monogramTransform) else {
    fatalError("Unable to position monogram")
}
let monogramBounds = monogramPath.boundingBoxOfPath

let cg = context.cgContext

// A shallow red under-layer remains visible only along the lower edge. At
// Finder sizes it reads as material thickness, not as a second symbol.
var depthTransform = CGAffineTransform(translationX: 0, y: -10)
if let depthPath = monogramPath.copy(using: &depthTransform) {
    cg.saveGState()
    cg.setShadow(
        offset: CGSize(width: 0, height: -5),
        blur: 10,
        color: NSColor(calibratedRed: 0.43, green: 0.01, blue: 0.03, alpha: 0.24).cgColor
    )
    cg.addPath(depthPath)
    cg.setFillColor(NSColor(calibratedRed: 0.63, green: 0.015, blue: 0.045, alpha: 0.72).cgColor)
    cg.fillPath()
    cg.restoreGState()
}

cg.saveGState()
cg.setShadow(offset: CGSize(width: 0, height: -7), blur: 14,
             color: NSColor(calibratedRed: 0.50, green: 0.02, blue: 0.04, alpha: 0.26).cgColor)
cg.addPath(monogramPath)
cg.clip()
let redGlass = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor(calibratedRed: 1.00, green: 0.38, blue: 0.41, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.82, green: 0.025, blue: 0.065, alpha: 1).cgColor
    ] as CFArray,
    locations: [0, 1]
)
if let redGlass {
    cg.drawLinearGradient(
        redGlass,
        start: CGPoint(x: monogramBounds.midX, y: monogramBounds.maxY),
        end: CGPoint(x: monogramBounds.midX, y: monogramBounds.minY),
        options: []
    )
}
cg.restoreGState()

// A soft reflection across the upper half makes the red glyphs read as a
// thin polished layer while preserving their solid silhouette.
cg.saveGState()
cg.addPath(monogramPath)
cg.clip()
let reflection = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        NSColor.white.withAlphaComponent(0.30).cgColor,
        NSColor.white.withAlphaComponent(0.08).cgColor,
        NSColor.white.withAlphaComponent(0).cgColor
    ] as CFArray,
    locations: [0, 0.52, 1]
)
if let reflection {
    cg.drawLinearGradient(
        reflection,
        start: CGPoint(x: monogramBounds.midX, y: monogramBounds.maxY),
        end: CGPoint(x: monogramBounds.midX, y: monogramBounds.midY - 18),
        options: []
    )
}
cg.restoreGState()

// Clip the stroke to the glyph interior so it behaves like a glass rim rather
// than a white outline around the letters.
cg.saveGState()
cg.addPath(monogramPath)
cg.clip()
cg.addPath(monogramPath)
cg.setStrokeColor(NSColor.white.withAlphaComponent(0.34).cgColor)
cg.setLineWidth(9)
cg.strokePath()
cg.restoreGState()

let dotRect = NSRect(
    x: monogramBounds.maxX - 9,
    y: monogramBounds.maxY + 12,
    width: 62,
    height: 62
)
NSGraphicsContext.current?.saveGraphicsState()
let dotShadow = NSShadow()
dotShadow.shadowColor = NSColor(calibratedRed: 1, green: 0.56, blue: 0.04, alpha: 0.34)
dotShadow.shadowBlurRadius = 18
dotShadow.shadowOffset = .zero
dotShadow.set()
let dot = NSBezierPath(ovalIn: dotRect)
NSGradient(colors: [
    NSColor(calibratedRed: 1.00, green: 0.82, blue: 0.33, alpha: 1),
    NSColor(calibratedRed: 0.96, green: 0.48, blue: 0.02, alpha: 1)
])?.draw(in: dot, angle: -90)
NSGraphicsContext.current?.restoreGraphicsState()

NSColor.white.withAlphaComponent(0.45).setStroke()
dot.lineWidth = 2
dot.stroke()

NSColor.white.withAlphaComponent(0.34).setFill()
NSBezierPath(ovalIn: NSRect(
    x: dotRect.minX + 13,
    y: dotRect.maxY - 20,
    width: dotRect.width - 26,
    height: 8
)).fill()

context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode app icon")
}
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL, options: .atomic)
print(outputURL.path)
