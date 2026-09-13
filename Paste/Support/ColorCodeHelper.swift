//
//  ColorCodeHelper.swift
//  Paste
//
//  Parses single-line CSS color strings and returns NSColor for card styling.
//

import AppKit
import Foundation
import SwiftUI

enum ColorCodeHelper {

    /// Returns NSColor only when the entire content is exactly a six-digit hex color,
    /// matching Paste's rules: a leading `#` marks it as a color; without it, the code
    /// must contain at least one letter A-F so verification codes like 235442 stay text.
    /// Three-digit shorthand, rgb()/hsl(), and hex embedded in other text stay text.
    static func color(from string: String) -> NSColor? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("\n") else { return nil }

        var hex = trimmed
        let hadHash = hex.hasPrefix("#")
        if hadHash { hex.removeFirst() }

        guard hex.count == 6,
              hex.allSatisfy({ $0.isHexDigit }) else { return nil }

        if !hadHash {
            let hasLetter = hex.contains(where: { "abcdefABCDEF".contains($0) })
            guard hasLetter else { return nil }
        }
        return parseHex6(hex)
    }

    private static func parseHex6(_ hex: String) -> NSColor? {
        let chars = [Character](hex)
        guard chars.count == 6,
              let r = byteFromHex2(chars[0], chars[1]),
              let g = byteFromHex2(chars[2], chars[3]),
              let b = byteFromHex2(chars[4], chars[5]) else { return nil }
        return NSColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }

    /// Contrasting color (white or black) for use on the given background.
    static func contrastingTextColor(for backgroundColor: NSColor) -> NSColor {
        let luminance = luminanceOf(backgroundColor)
        return luminance > 0.5 ? .black : .white
    }

    private static func luminanceOf(_ c: NSColor) -> Double {
        let rgb = c.usingColorSpace(.sRGB) ?? c
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)
    }

    private static func parseHex(_ s: String) -> NSColor? {
        var hex = s.dropFirst()
        if hex.hasPrefix("0x") { hex = hex.dropFirst(2) }
        let chars = [Character](hex)
        switch chars.count {
        case 3:
            guard let r = byteFromHex2(chars[0], chars[0]),
                  let g = byteFromHex2(chars[1], chars[1]),
                  let b = byteFromHex2(chars[2], chars[2]) else { return nil }
            return NSColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
        case 4:
            guard let r = byteFromHex2(chars[0], chars[0]),
                  let g = byteFromHex2(chars[1], chars[1]),
                  let b = byteFromHex2(chars[2], chars[2]),
                  let a = byteFromHex2(chars[3], chars[3]) else { return nil }
            return NSColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
        case 6:
            guard let r = byteFromHex2(chars[0], chars[1]),
                  let g = byteFromHex2(chars[2], chars[3]),
                  let b = byteFromHex2(chars[4], chars[5]) else { return nil }
            return NSColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
        case 8:
            guard let r = byteFromHex2(chars[0], chars[1]),
                  let g = byteFromHex2(chars[2], chars[3]),
                  let b = byteFromHex2(chars[4], chars[5]),
                  let a = byteFromHex2(chars[6], chars[7]) else { return nil }
            return NSColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
        default:
            return nil
        }
    }

    private static func byteFromHex2(_ c1: Character, _ c2: Character) -> UInt8? {
        let h = hexDigit(c1), l = hexDigit(c2)
        guard let h = h, let l = l else { return nil }
        return h << 4 | l
    }

    private static func hexDigit(_ c: Character) -> UInt8? {
        switch c {
        case "0"..."9": return UInt8(c.asciiValue! - 48)
        case "a"..."f": return UInt8(c.asciiValue! - 97 + 10)
        case "A"..."F": return UInt8(c.asciiValue! - 65 + 10)
        default: return nil
        }
    }

    private static func parseRgbRgba(_ s: String) -> NSColor? {
        let lower = s.lowercased()
        let inner: String
        if lower.hasPrefix("rgba(") {
            inner = String(s.dropFirst(5).dropLast())
        } else if lower.hasPrefix("rgb(") {
            inner = String(s.dropFirst(4).dropLast())
        } else {
            return nil
        }
        let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 3 || parts.count == 4 else { return nil }
        func parseComponent(_ str: String) -> CGFloat? {
            let t = str.trimmingCharacters(in: .whitespaces)
            if t.hasSuffix("%") {
                guard let v = Double(t.dropLast()) else { return nil }
                return CGFloat(v / 100)
            }
            guard let v = Double(t) else { return nil }
            if v > 1 && v <= 255 { return CGFloat(v / 255) }
            return CGFloat(max(0, min(1, v)))
        }
        guard let r = parseComponent(parts[0]),
              let g = parseComponent(parts[1]),
              let b = parseComponent(parts[2]) else { return nil }
        let a: CGFloat = parts.count == 4 ? (parseComponent(parts[3]) ?? 1) : 1
        return NSColor(red: r, green: g, blue: b, alpha: a)
    }

    private static func parseHslHsla(_ s: String) -> NSColor? {
        let lower = s.lowercased()
        let inner: String
        if lower.hasPrefix("hsla(") {
            inner = String(s.dropFirst(5).dropLast())
        } else if lower.hasPrefix("hsl(") {
            inner = String(s.dropFirst(4).dropLast())
        } else {
            return nil
        }
        let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 3 || parts.count == 4 else { return nil }
        guard let h = Double(parts[0].replacingOccurrences(of: "deg", with: "")),
              let sVal = Double(parts[1].replacingOccurrences(of: "%", with: "")),
              let lVal = Double(parts[2].replacingOccurrences(of: "%", with: "")) else { return nil }
        let s = CGFloat(max(0, min(100, sVal)) / 100)
        let l = CGFloat(max(0, min(100, lVal)) / 100)
        let a: CGFloat = parts.count == 4 ? (CGFloat(Double(parts[3].replacingOccurrences(of: "%", with: "")) ?? 1)) : 1
        return nsColorFromHSL(h: h, s: s, l: l, a: a)
    }

    private static func nsColorFromHSL(h: Double, s: CGFloat, l: CGFloat, a: CGFloat) -> NSColor {
        let hue = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        if s == 0 {
            r = l; g = l; b = l
        } else {
            let q = l < 0.5 ? l * (1 + s) : l + s - l * s
            let p = 2 * l - q
            r = hueToRgb(p: p, q: q, t: hue + 1/3)
            g = hueToRgb(p: p, q: q, t: hue)
            b = hueToRgb(p: p, q: q, t: hue - 1/3)
        }
        return NSColor(red: r, green: g, blue: b, alpha: a)
    }

    private static func hueToRgb(p: CGFloat, q: CGFloat, t: CGFloat) -> CGFloat {
        var t = t
        if t < 0 { t += 1 }
        if t > 1 { t -= 1 }
        if t < 1/6 { return p + (q - p) * 6 * t }
        if t < 1/2 { return q }
        if t < 2/3 { return p + (q - p) * (2/3 - t) * 6 }
        return p
    }
}

// MARK: - Card visual identity (Paste-style headers, link/color detection)

import AppKit
import SwiftUI
import Foundation

// MARK: - Card Kind

/// Presentation-level kind of a clipboard item. Links and colors are text items
/// whose content matches a URL or a color code; no model change is required.
enum CardKind {
    case text
    case link
    case color
    case image
    case file

    init(item: ClipboardItemModel) {
        switch item.itemType {
        case .image: self = .image
        case .file:  self = .file
        case .text:
            let raw = (item.plainText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !raw.isEmpty, !raw.contains("\n") {
                if ColorCodeHelper.color(from: raw) != nil { self = .color; return }
                if CardKind.isLikelyLink(raw) { self = .link; return }
            }
            self = .text
        }
    }

    /// Conservative URL detection: explicit scheme or www. prefix, single line, no spaces.
    static func isLikelyLink(_ s: String) -> Bool {
        if s.contains(" ") || s.contains("\t") { return false }
        let lower = s.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return URL(string: s)?.host != nil
        }
        if lower.hasPrefix("www."), let url = URL(string: "https://" + s) {
            return url.host?.contains(".") ?? false
        }
        return false
    }

    /// Short URL for display on link cards (strips scheme and trailing slash).
    static func displayURL(_ s: String) -> String {
        var t = s
        if let r = t.range(of: "://") { t.removeSubrange(t.startIndex..<r.upperBound) }
        if t.hasSuffix("/") { t.removeLast() }
        return t
    }

    var label: String {
        switch self {
        case .text:  return String(localized: "card.kind.text")
        case .link:  return String(localized: "card.kind.link")
        case .color: return String(localized: "card.kind.color")
        case .image: return String(localized: "card.kind.image")
        case .file:  return String(localized: "card.kind.file")
        }
    }

    var iconName: String {
        switch self {
        case .text:  return "doc.text"
        case .link:  return "link"
        case .color: return "paintpalette"
        case .image: return "photo"
        case .file:  return "folder"
        }
    }
}

// MARK: - Header Colors

enum CardStyle {

    /// Vivid header colors seen on Paste's cards, keyed by source app.
    private static let appColors: [String: NSColor] = [
        "com.apple.MobileSMS":        rgb(0x34C759), // Messages — green
        "com.apple.finder":           rgb(0x0A84FF), // Finder — blue
        "com.apple.Music":            rgb(0xFC3C44), // Music — pink red
        "com.apple.Notes":            rgb(0xE5A50A), // Notes — yellow
        "com.apple.Safari":           rgb(0x0A84FF), // Safari — blue
        "com.apple.mail":             rgb(0x0A84FF), // Mail — blue
        "com.apple.Photos":           rgb(0xFF3B30), // Photos — red
        "com.apple.iCal":             rgb(0xFF9500), // Calendar — orange
        "com.apple.Terminal":         rgb(0x48484A), // Terminal — graphite
        "com.apple.dt.Xcode":         rgb(0x0A84FF), // Xcode — blue
        "com.google.Chrome":          rgb(0x4285F4), // Chrome — blue
        "com.microsoft.VSCode":       rgb(0x0A84FF), // VS Code — blue
        "com.tinyspeck.slackmacgap":  rgb(0x611F69), // Slack — aubergine
        "com.apple.iWork.Pages":      rgb(0xFF9500), // Pages — orange
        "com.apple.iWork.Numbers":    rgb(0x34C759), // Numbers — green
        "com.apple.iWork.Keynote":    rgb(0x0A84FF), // Keynote — blue
        "com.apple.freeform":         rgb(0xE5A50A), // Freeform — yellow
        "com.apple.TextEdit":         rgb(0xE5A50A), // TextEdit — yellow
        "com.hnc.Discord":            rgb(0x5865F2), // Discord — blurple
        "com.spotify.client":         rgb(0x1DB954), // Spotify — green
        "com.figma.Desktop":          rgb(0xA259FF), // Figma — purple
        "com.readdle.smartemail-Mac": rgb(0x0A84FF), // Spark — blue
    ]

    /// Vivid fallback palette (order mirrors Paste's marketing cards).
    private static let fallbackPalette: [NSColor] = [
        rgb(0xFF9500), // orange
        rgb(0x34C759), // green
        rgb(0x0A84FF), // blue
        rgb(0xFF3B30), // red
        rgb(0xAF52DE), // purple
        rgb(0xFF2D92), // pink
        rgb(0x5AC8FA), // teal
        rgb(0xE5A50A), // yellow
    ]

    /// Header tint for a card. Known apps get their brand-ish color; everything else
    /// gets a stable palette color hashed from the bundle id so the same app always
    /// looks the same; unknown sources fall back to the item kind.
    static func headerColor(for item: ClipboardItemModel, kind: CardKind) -> NSColor {
        if let bundleId = item.appBundleId {
            if let known = appColors[bundleId] { return known }
            var hash: UInt64 = 5381
            for byte in bundleId.utf8 { hash = ((hash << 5) &+ hash) &+ UInt64(byte) }
            return fallbackPalette[Int(hash % UInt64(fallbackPalette.count))]
        }
        switch kind {
        case .text:  return rgb(0xFF9500)
        case .link:  return rgb(0x34C759)
        case .color: return rgb(0xAF52DE)
        case .image: return rgb(0xFF3B30)
        case .file:  return rgb(0x0A84FF)
        }
    }

    static func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: alpha)
    }
}

// MARK: - Pinboard Colors

extension AppSettings {
    /// Paste-style pinboard colors shown as dots in the toolbar and menus.
    static let pinboardPalette: [String] = [
        "#FF3B30", "#FF9500", "#34C759", "#0A84FF", "#AF52DE",
        "#FF2D92", "#5AC8FA", "#E5A50A", "#48484A", "#A2845E",
    ]

    static func pinboardColorHex(at index: Int) -> String {
        let key = "pinboardColor_\(index)"
        if let stored = UserDefaults.standard.string(forKey: key),
           ColorCodeHelper.color(from: stored) != nil {
            return stored
        }
        return pinboardPalette[index % pinboardPalette.count]
    }

    static func pinboardColor(at index: Int) -> Color {
        let ns = ColorCodeHelper.color(from: pinboardColorHex(at: index)) ?? .systemRed
        return Color(nsColor: ns)
    }

    static func setPinboardColor(_ hex: String, at index: Int) {
        UserDefaults.standard.set(hex, forKey: "pinboardColor_\(index)")
        savePinboardsToKVS()
    }
}
