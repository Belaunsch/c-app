//
//  generate-app-icon.swift
//  Erzeugt die drei 1024×1024-PNGs für CApp/Assets.xcassets/AppIcon.appiconset.
//
//  Aufruf:
//      swift tools/generate-app-icon.swift CApp/Assets.xcassets/AppIcon.appiconset
//
//  Bewusst **kein** Build-Step. Das Icon ändert sich praktisch nie; es einmal
//  zu erzeugen und die PNGs einzuchecken ist ehrlicher als ein Skript, das bei
//  jedem Build läuft, damit sich niemand fragen muss, woher die Datei kommt.
//  Dieser Generator liegt hier, damit die Herkunft nachvollziehbar bleibt.
//
//  Motiv: das Schriftzeichen 学 („lernen") auf einfarbigem Grund. Eigenständig,
//  auf 40 Punkten noch erkennbar, und ohne fremde Assets — ein Schriftzeichen
//  ist kein geschütztes Werk. Die abgerundeten Ecken setzt iOS selbst, die
//  Bilder sind deshalb quadratisch und randlos.
//

import AppKit
import CoreGraphics
import Foundation

struct IconVariant {
    let name: String
    let background: NSColor
    let foreground: NSColor
}

let variants = [
    // Hell: gedecktes Zinnoberrot, das in der chinesischen Schriftkultur
    // naheliegt, ohne grell zu sein.
    IconVariant(
        name: "AppIcon-Light.png",
        background: NSColor(srgbRed: 0.72, green: 0.19, blue: 0.16, alpha: 1),
        foreground: NSColor(srgbRed: 0.99, green: 0.97, blue: 0.94, alpha: 1)
    ),
    // Dunkel: derselbe Farbton, deutlich abgedunkelt, damit das Zeichen auf
    // einem dunklen Homescreen nicht leuchtet.
    IconVariant(
        name: "AppIcon-Dark.png",
        background: NSColor(srgbRed: 0.16, green: 0.06, blue: 0.05, alpha: 1),
        foreground: NSColor(srgbRed: 0.94, green: 0.72, blue: 0.66, alpha: 1)
    ),
    // Getönt: iOS färbt selbst ein und erwartet Graustufen. Der Kontrast
    // zwischen Grund und Zeichen ist hier die einzige Information.
    IconVariant(
        name: "AppIcon-Tinted.png",
        background: NSColor(white: 0.18, alpha: 1),
        foreground: NSColor(white: 0.95, alpha: 1)
    ),
]

let size = 1024.0
let glyph = "学"

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write(Data("Zielordner fehlt\n".utf8))
    exit(1)
}
let directory = URL(fileURLWithPath: CommandLine.arguments[1])

for variant in variants {
    // Ein `NSBitmapImageRep` mit ausdrücklichen Pixelmaßen, **nicht**
    // `NSImage.lockFocus()`: Letzteres rendert im Backing-Maßstab des Macs
    // und liefert auf einem Retina-Display 2048×2048 für ein als 1024×1024
    // deklariertes Slot. Gemessen, nicht vermutet.
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else {
        FileHandle.standardError.write(Data("Bitmap fehlgeschlagen: \(variant.name)\n".utf8))
        exit(1)
    }
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    variant.background.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    // Eine Schrift, die auf jedem Mac vorhanden ist und Hanzi kann.
    let font = NSFont(name: "STHeiti Medium", size: size * 0.62)
        ?? NSFont(name: "Hiragino Sans GB W6", size: size * 0.62)
        ?? NSFont.systemFont(ofSize: size * 0.62)

    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: variant.foreground,
    ]
    let text = NSAttributedString(string: glyph, attributes: attributes)
    let bounds = text.size()
    // Optisch zentriert statt metrisch: Hanzi sitzen in ihrer Zelle meist
    // etwas hoch, und auf einem Icon fällt das auf.
    text.draw(at: NSPoint(
        x: (size - bounds.width) / 2,
        y: (size - bounds.height) / 2 - size * 0.02
    ))

    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("Rendern fehlgeschlagen: \(variant.name)\n".utf8))
        exit(1)
    }

    let target = directory.appendingPathComponent(variant.name)
    try png.write(to: target)
    print("geschrieben: \(target.lastPathComponent) (\(png.count) Bytes)")
}
