import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func usage() -> Never {
    FileHandle.standardError.write(Data("usage: imagediff <a.png> <b.png> [--out heat.png] [--threshold N]\n".utf8))
    exit(2)
}

var args = Array(CommandLine.arguments.dropFirst())
var paths: [String] = []
var outPath: String?
var threshold = 8
while let arg = args.first {
    args.removeFirst()
    switch arg {
    case "--out":
        guard let v = args.first else { usage() }
        args.removeFirst()
        outPath = v
    case "--threshold":
        guard let v = args.first, let n = Int(v) else { usage() }
        args.removeFirst()
        threshold = n
    default:
        paths.append(arg)
    }
}
guard paths.count == 2 else { usage() }

func loadImage(_ path: String) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

func rasterize(_ image: CGImage) -> (width: Int, height: Int, pixels: [UInt8]) {
    let width = image.width
    let height = image.height
    let bytesPerRow = width * 4
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bytesPerRow * height)
    buffer.initialize(repeating: 0, count: bytesPerRow * height)
    defer { buffer.deallocate() }
    guard let context = CGContext(
        data: buffer,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { usage() }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return (width, height, Array(UnsafeBufferPointer(start: buffer, count: bytesPerRow * height)))
}

guard let imageA = loadImage(paths[0]) else {
    FileHandle.standardError.write(Data("imagediff: cannot load \(paths[0])\n".utf8))
    exit(1)
}
guard let imageB = loadImage(paths[1]) else {
    FileHandle.standardError.write(Data("imagediff: cannot load \(paths[1])\n".utf8))
    exit(1)
}

let a = rasterize(imageA)
let b = rasterize(imageB)
let width = min(a.width, b.width)
let height = min(a.height, b.height)

var sumDiff = 0.0
var maxDiff = 0
var differing = 0
let total = width * height
var heat = [UInt8](repeating: 0, count: total * 4)

for y in 0..<height {
    for x in 0..<width {
        let i = (y * width + x) * 4
        let dr = abs(Int(a.pixels[i]) - Int(b.pixels[i]))
        let dg = abs(Int(a.pixels[i + 1]) - Int(b.pixels[i + 1]))
        let db = abs(Int(a.pixels[i + 2]) - Int(b.pixels[i + 2]))
        let d = max(dr, max(dg, db))
        sumDiff += Double(dr + dg + db) / 3.0
        if d > maxDiff { maxDiff = d }
        if d > threshold { differing += 1 }
        let base = Int(Double(a.pixels[i]) * 0.35)
        let red = min(255, d * 2)
        heat[i] = UInt8(min(255, base + red))
        heat[i + 1] = UInt8(base)
        heat[i + 2] = UInt8(base)
        heat[i + 3] = 255
    }
}

if let outPath {
    let heatContext = CGContext(
        data: &heat,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    guard let heatImage = heatContext.makeImage() else { usage() }
    try? FileManager.default.removeItem(atPath: outPath)
    guard let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        FileHandle.standardError.write(Data("imagediff: cannot write \(outPath)\n".utf8))
        exit(1)
    }
    CGImageDestinationAddImage(destination, heatImage, nil)
    CGImageDestinationFinalize(destination)
}

let mean = total > 0 ? sumDiff / Double(total) : 0
let pct = total > 0 ? Double(differing) / Double(total) * 100 : 0
let result: [String: Any] = [
    "a": paths[0],
    "b": paths[1],
    "sizeA": [a.width, a.height],
    "sizeB": [b.width, b.height],
    "comparedPixels": total,
    "meanAbsDiff": (mean * 100).rounded() / 100,
    "pctDifferent": (pct * 100).rounded() / 100,
    "maxDiff": maxDiff,
    "threshold": threshold,
]
let data = try! JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
print(String(data: data, encoding: .utf8)!)
