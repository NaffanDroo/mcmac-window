#!/usr/bin/env swift
/// Generates Resources/AppIcon.icns for mcmac-window.
///
/// Design: deep blue-grey gradient background, two white rounded rectangles
/// (left solid, right ghosted) representing a window snapped to the left half.
/// Run once and commit the output; build.sh copies it into the bundle.
///
/// Usage: swift scripts/make_icon.swift

import AppKit
import CoreGraphics

// MARK: - Drawing

func makeIcon(size: CGFloat) -> CGImage {
    let cs   = CGColorSpaceCreateDeviceRGB()
    let bits = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let ctx = CGContext(
        data: nil, width: Int(size), height: Int(size),
        bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: bits.rawValue
    ) else { fatalError("Could not create CGContext") }

    // AppKit icon canvas: origin bottom-left
    ctx.saveGState()

    // Background gradient — deep navy top → charcoal bottom
    let bgColors = [
        CGColor(red: 0.10, green: 0.16, blue: 0.28, alpha: 1.0),   // top
        CGColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1.0),   // bottom
    ] as CFArray
    guard let grad = CGGradient(
        colorsSpace: cs, colors: bgColors, locations: [0.0, 1.0]
    ) else { fatalError("Could not create gradient") }
    ctx.drawLinearGradient(
        grad,
        start: CGPoint(x: size / 2, y: size),
        end:   CGPoint(x: size / 2, y: 0),
        options: []
    )

    // Panel geometry — two equal columns with a gap
    let pad:    CGFloat = size * 0.10
    let gap:    CGFloat = size * 0.036
    let panelH: CGFloat = size * 0.64
    let panelY: CGFloat = (size - panelH) / 2
    let panelW: CGFloat = (size - pad * 2 - gap) / 2
    let cr:     CGFloat = size * 0.048   // corner radius

    // Left panel — active, solid white
    let leftRect = CGRect(x: pad, y: panelY, width: panelW, height: panelH)
    ctx.addPath(CGPath(roundedRect: leftRect, cornerWidth: cr, cornerHeight: cr, transform: nil))
    ctx.setFillColor(CGColor(red: 0.95, green: 0.97, blue: 1.00, alpha: 0.96))
    ctx.fillPath()

    // Subtle top-edge highlight on left panel (gives it depth)
    let hlH: CGFloat = size * 0.006
    let hlRect = CGRect(x: leftRect.minX + cr, y: leftRect.maxY - hlH,
                        width: leftRect.width - cr * 2, height: hlH)
    ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.55))
    ctx.fill(hlRect)

    // Right panel — inactive, semi-transparent
    let rightRect = CGRect(x: pad + panelW + gap, y: panelY, width: panelW, height: panelH)
    ctx.addPath(CGPath(roundedRect: rightRect, cornerWidth: cr, cornerHeight: cr, transform: nil))
    ctx.setFillColor(CGColor(red: 0.85, green: 0.92, blue: 1.00, alpha: 0.14))
    ctx.fillPath()

    // Right panel border
    ctx.addPath(CGPath(roundedRect: rightRect, cornerWidth: cr, cornerHeight: cr, transform: nil))
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.22))
    ctx.setLineWidth(size * 0.003)
    ctx.strokePath()

    ctx.restoreGState()
    guard let img = ctx.makeImage() else { fatalError("makeImage() returned nil") }
    return img
}

// MARK: - Iconset production

func writePNG(_ image: CGImage, to path: String) {
    let url  = URL(fileURLWithPath: path)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
    else { fatalError("Cannot create destination for \(path)") }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("Finalize failed for \(path)") }
}

func resize(_ image: CGImage, to px: Int) -> CGImage {
    let cs   = CGColorSpaceCreateDeviceRGB()
    let bits = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let ctx = CGContext(
        data: nil, width: px, height: px,
        bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: bits.rawValue
    ) else { fatalError("Resize context failed") }
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: px, height: px))
    guard let out = ctx.makeImage() else { fatalError("resize makeImage failed") }
    return out
}

// MARK: - Entry point

let fm = FileManager.default
let repoRoot   = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent()
let iconsetDir = repoRoot.appendingPathComponent("Resources/AppIcon.iconset")
let icnsPath   = repoRoot.appendingPathComponent("Resources/AppIcon.icns").path

try fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

let source = makeIcon(size: 1024)

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16",       16),
    ("icon_16x16@2x",    32),
    ("icon_32x32",       32),
    ("icon_32x32@2x",    64),
    ("icon_128x128",    128),
    ("icon_128x128@2x", 256),
    ("icon_256x256",    256),
    ("icon_256x256@2x", 512),
    ("icon_512x512",    512),
    ("icon_512x512@2x",1024),
]

for entry in sizes {
    let path = iconsetDir.appendingPathComponent("\(entry.name).png").path
    writePNG(resize(source, to: entry.px), to: path)
    print("  wrote \(entry.name).png")
}

// iconutil converts the .iconset folder to .icns
let result = Process()
result.launchPath = "/usr/bin/iconutil"
result.arguments  = ["-c", "icns", iconsetDir.path, "-o", icnsPath]
result.launch()
result.waitUntilExit()

if result.terminationStatus == 0 {
    // Clean up the temporary iconset folder
    try fm.removeItem(at: iconsetDir)
    print("\n✓ Resources/AppIcon.icns written")
} else {
    print("✗ iconutil failed (status \(result.terminationStatus))")
    exit(1)
}
