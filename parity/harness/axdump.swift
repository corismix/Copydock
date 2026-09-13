import Foundation
import ApplicationServices
import AppKit

struct Options {
    var bundleID: String
    var mode = "ax"
    var format = "text"
    var maxDepth = 12
    var maxChildren = 250
    var outPath: String?
}

func usage() -> Never {
    FileHandle.standardError.write(Data("usage: axdump <bundle-id> [--windows] [--format json|text|norm] [--depth N] [--max-children N] [--out PATH]\n".utf8))
    exit(2)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("axdump: \(message)\n".utf8))
    exit(1)
}

var args = Array(CommandLine.arguments.dropFirst())
guard let bundleID = args.first else { usage() }
args.removeFirst()
var opts = Options(bundleID: bundleID)
while let arg = args.first {
    args.removeFirst()
    switch arg {
    case "--windows": opts.mode = "windows"
    case "--format":
        guard let v = args.first else { usage() }
        args.removeFirst()
        opts.format = v
    case "--depth":
        guard let v = args.first, let n = Int(v) else { usage() }
        args.removeFirst()
        opts.maxDepth = n
    case "--max-children":
        guard let v = args.first, let n = Int(v) else { usage() }
        args.removeFirst()
        opts.maxChildren = n
    case "--out":
        guard let v = args.first else { usage() }
        args.removeFirst()
        opts.outPath = v
    case "--help", "-h": usage()
    default: usage()
    }
}

guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: opts.bundleID).first else {
    fail("no running application with bundle id \(opts.bundleID)")
}
let pid = app.processIdentifier

func emit(_ text: String) {
    if let path = opts.outPath {
        do { try text.write(toFile: path, atomically: true, encoding: .utf8) }
        catch { fail("cannot write \(path): \(error)") }
    } else {
        print(text)
    }
}

if opts.mode == "windows" {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
    let mine = list.filter { ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid }
    if opts.format == "json" {
        let rows: [[String: Any]] = mine.map { w in
            let bounds = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
            return [
                "id": (w[kCGWindowNumber as String] as? NSNumber)?.intValue ?? -1,
                "layer": (w[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -1,
                "alpha": (w[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 0,
                "name": w[kCGWindowName as String] as? String ?? "",
                "bounds": [
                    "x": (bounds["X"] as? NSNumber)?.doubleValue ?? 0,
                    "y": (bounds["Y"] as? NSNumber)?.doubleValue ?? 0,
                    "w": (bounds["Width"] as? NSNumber)?.doubleValue ?? 0,
                    "h": (bounds["Height"] as? NSNumber)?.doubleValue ?? 0,
                ],
            ]
        }
        let data = try! JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
        emit(String(data: data, encoding: .utf8)!)
    } else {
        var lines: [String] = []
        for w in mine {
            let bounds = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
            let name = w[kCGWindowName as String] as? String ?? ""
            let id = (w[kCGWindowNumber as String] as? NSNumber)?.intValue ?? -1
            let layer = (w[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -1
            let x = (bounds["X"] as? NSNumber)?.doubleValue ?? 0
            let y = (bounds["Y"] as? NSNumber)?.doubleValue ?? 0
            let wd = (bounds["Width"] as? NSNumber)?.doubleValue ?? 0
            let ht = (bounds["Height"] as? NSNumber)?.doubleValue ?? 0
            lines.append("id=\(id) layer=\(layer) name=\"\(name)\" bounds=\(Int(x)),\(Int(y)),\(Int(wd)),\(Int(ht))")
        }
        emit(lines.joined(separator: "\n"))
    }
    exit(0)
}

let appElement = AXUIElementCreateApplication(pid)

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
}

func stringAttribute(_ element: AXUIElement, _ name: String, limit: Int = 240) -> String? {
    guard let raw = attribute(element, name) else { return nil }
    guard let string = raw as? String else { return nil }
    if string.count > limit { return String(string.prefix(limit)) + "…" }
    return string
}

func boolAttribute(_ element: AXUIElement, _ name: String) -> Bool? {
    (attribute(element, name) as? NSNumber)?.boolValue
}

func frame(of element: AXUIElement) -> [Double]? {
    var origin = CGPoint.zero
    var size = CGSize.zero
    guard let posRaw = attribute(element, kAXPositionAttribute as String), CFGetTypeID(posRaw) == AXValueGetTypeID() else { return nil }
    guard let sizeRaw = attribute(element, kAXSizeAttribute as String), CFGetTypeID(sizeRaw) == AXValueGetTypeID() else { return nil }
    guard AXValueGetValue(posRaw as! AXValue, .cgPoint, &origin) else { return nil }
    guard AXValueGetValue(sizeRaw as! AXValue, .cgSize, &size) else { return nil }
    let values = [Double(origin.x), Double(origin.y), Double(size.width), Double(size.height)]
    return values.map { ($0 * 10).rounded() / 10 }
}

func children(of element: AXUIElement) -> [AXUIElement] {
    guard let raw = attribute(element, kAXChildrenAttribute as String) else { return [] }
    return (raw as? [AXUIElement]) ?? []
}

func actions(of element: AXUIElement) -> [String] {
    var names: CFArray?
    guard AXUIElementCopyActionNames(element, &names) == .success, let list = names as? [String] else { return [] }
    return list.sorted()
}

func node(for element: AXUIElement, depth: Int) -> [String: Any] {
    var out: [String: Any] = [:]
    out["role"] = stringAttribute(element, kAXRoleAttribute as String) ?? "?"
    if let sub = stringAttribute(element, kAXSubroleAttribute as String) { out["subrole"] = sub }
    if let title = stringAttribute(element, kAXTitleAttribute as String) { out["title"] = title }
    if let desc = stringAttribute(element, kAXDescriptionAttribute as String) { out["desc"] = desc }
    if let help = stringAttribute(element, kAXHelpAttribute as String) { out["help"] = help }
    if let ident = stringAttribute(element, kAXIdentifierAttribute as String) { out["identifier"] = ident }
    if let value = stringAttribute(element, kAXValueAttribute as String) { out["value"] = value }
    if let enabled = boolAttribute(element, kAXEnabledAttribute as String) { out["enabled"] = enabled }
    if let frame = frame(of: element) { out["frame"] = frame }
    let acts = actions(of: element)
    if !acts.isEmpty { out["actions"] = acts }
    if depth < opts.maxDepth {
        let kids = children(of: element)
        if !kids.isEmpty {
            out["children"] = kids.prefix(opts.maxChildren).map { node(for: $0, depth: depth + 1) }
        }
    }
    return out
}

func pad(_ depth: Int) -> String { String(repeating: "  ", count: depth) }

func textLine(_ el: AXUIElement, depth: Int, norm: Bool) -> String {
    let role = stringAttribute(el, kAXRoleAttribute as String) ?? "?"
    let sub = stringAttribute(el, kAXSubroleAttribute as String).map { "/\($0)" } ?? ""
    var parts = ["\(pad(depth))\(role)\(sub)"]
    if let title = stringAttribute(el, kAXTitleAttribute as String) { parts.append("title=\"\(title)\"") }
    if let desc = stringAttribute(el, kAXDescriptionAttribute as String) { parts.append("desc=\"\(desc)\"") }
    if let ident = stringAttribute(el, kAXIdentifierAttribute as String) { parts.append("id=\(ident)") }
    if let value = stringAttribute(el, kAXValueAttribute as String) { parts.append("value=\"\(value)\"") }
    if let frame = frame(of: el) {
        if norm {
            parts.append("size=\(Int(frame[2]))x\(Int(frame[3]))")
        } else {
            parts.append("frame=\(Int(frame[0])),\(Int(frame[1])),\(Int(frame[2])),\(Int(frame[3]))")
        }
    }
    if !norm {
        if let enabled = boolAttribute(el, kAXEnabledAttribute as String) { parts.append("enabled=\(enabled)") }
        let acts = actions(of: el)
        if !acts.isEmpty { parts.append("actions=[\(acts.joined(separator: ","))]") }
    }
    return parts.joined(separator: " ")
}

func textTree(_ el: AXUIElement, depth: Int, norm: Bool, into lines: inout [String]) {
    lines.append(textLine(el, depth: depth, norm: norm))
    guard depth < opts.maxDepth else { return }
    for kid in children(of: el).prefix(opts.maxChildren) {
        textTree(kid, depth: depth + 1, norm: norm, into: &lines)
    }
}

switch opts.format {
case "json":
    let root = node(for: appElement, depth: 0)
    let data = try! JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    emit(String(data: data, encoding: .utf8)!)
case "text", "norm":
    var lines: [String] = []
    textTree(appElement, depth: 0, norm: opts.format == "norm", into: &lines)
    emit(lines.joined(separator: "\n"))
default:
    usage()
}
