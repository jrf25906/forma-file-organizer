#!/usr/bin/env swift

import AppKit
import Foundation

private struct Options {
    let sourceSVGPath: String
    let appIconSetPath: String
    let docsOutputPath: String?
}

private func parseOptions() -> Options {
    var sourceSVGPath = "forma-marketing-site/public/app-icon-1024.svg"
    var appIconSetPath = "Forma File Organizing/Assets.xcassets/AppIcon.appiconset"
    var docsOutputPath: String?

    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = iterator.next() {
        switch arg {
        case "--source":
            if let value = iterator.next() { sourceSVGPath = value }
        case "--appiconset":
            if let value = iterator.next() { appIconSetPath = value }
        case "--docs-output":
            if let value = iterator.next() { docsOutputPath = value }
        default:
            continue
        }
    }

    return Options(sourceSVGPath: sourceSVGPath, appIconSetPath: appIconSetPath, docsOutputPath: docsOutputPath)
}

private struct OutputSpec: Sendable {
    let filename: String
    let pixelSize: Int
}

private func writePNG(data: Data, to path: String) throws {
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: [.atomic])
}

private func renderSVGToPNGData(svgPath: String, pixelSize: Int, background: NSColor) throws -> Data {
    guard let image = NSImage(contentsOfFile: svgPath) else {
        throw NSError(domain: "GenerateAppIcons", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load SVG: \(svgPath)"])
    }

    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "GenerateAppIcons", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create bitmap rep (\(pixelSize)x\(pixelSize))."])
    }

    rep.size = NSSize(width: pixelSize, height: pixelSize)

    guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
        throw NSError(domain: "GenerateAppIcons", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create graphics context."])
    }

    let rect = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
    let sourceRect = NSRect(origin: .zero, size: image.size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.shouldAntialias = true

    background.setFill()
    rect.fill()

    image.draw(in: rect, from: sourceRect, operation: .sourceOver, fraction: 1.0, respectFlipped: true, hints: nil)

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "GenerateAppIcons", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG data."])
    }

    return data
}

private let outputSpecs: [OutputSpec] = [
    OutputSpec(filename: "icon_16x16.png", pixelSize: 16),
    OutputSpec(filename: "icon_16x16@2x.png", pixelSize: 32),
    OutputSpec(filename: "icon_32x32.png", pixelSize: 32),
    OutputSpec(filename: "icon_32x32@2x.png", pixelSize: 64),
    OutputSpec(filename: "icon_128x128.png", pixelSize: 128),
    OutputSpec(filename: "icon_128x128@2x.png", pixelSize: 256),
    OutputSpec(filename: "icon_256x256.png", pixelSize: 256),
    OutputSpec(filename: "icon_256x256@2x.png", pixelSize: 512),
    OutputSpec(filename: "icon_512x512.png", pixelSize: 512),
    OutputSpec(filename: "icon_512x512@2x.png", pixelSize: 1024),
]

private func main() throws {
    let options = parseOptions()

    // Keep the background full-bleed so macOS can apply its own icon mask cleanly.
    let boneWhite = NSColor(srgbRed: 250 / 255.0, green: 250 / 255.0, blue: 248 / 255.0, alpha: 1.0)

    for spec in outputSpecs {
        let png = try renderSVGToPNGData(svgPath: options.sourceSVGPath, pixelSize: spec.pixelSize, background: boneWhite)
        let outPath = "\(options.appIconSetPath)/\(spec.filename)"
        try writePNG(data: png, to: outPath)
        print("Wrote \(outPath)")
    }

    if let docsOutputPath = options.docsOutputPath {
        let png = try renderSVGToPNGData(svgPath: options.sourceSVGPath, pixelSize: 1024, background: boneWhite)
        try writePNG(data: png, to: docsOutputPath)
        print("Wrote \(docsOutputPath)")
    }
}

do {
    try main()
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}

