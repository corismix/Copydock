import Foundation
import CoreGraphics
import ImageIO

func usage() -> Never {
    FileHandle.standardError.write(Data("usage: pixscan <img.png> --col X [--from Y0 --to Y1] | --row Y [--from X0 --to X1] [--tolerance N]\n".utf8))
    exit(2)
}

var args = Array(CommandLine.arguments.dropFirst())
guard let path = args.first else { usage() }
args.removeFirst()
var col: Int?
var row: Int?
var from = 0
var to = Int.max
var tolerance = 6
while let arg = args.first {
    args.removeFirst()
    switch arg {
    case "--col": guard let v = args.first, let n = Int(v) else { usage() }; args.removeFirst(); col = n
    case "--row": guard let v = args.first, let n = Int(v) else { usage() }; args.removeFirst(); row = n
    case "--from": guard let v = args.first, let n = Int(v) else { usage() }; args.removeFirst(); from = n
    case "--to": guard let v = args.first, let n = Int(v) else { usage() }; args.removeFirst(); to = n
    case "--tolerance": guard let v = args.first, let n = Int(v) else { usage() }; args.removeFirst(); tolerance = n
    default: usage()
    }
}

guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    FileHandle.standardError.write(Data("pixscan: cannot load \(path)\n".utf8))
    exit(1)
}

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
let pixels = buffer

func colorAt(_ x: Int, _ y: Int) -> (Int, Int, Int) {
    let i = (y * width + x) * 4
    return (Int(pixels[i]), Int(pixels[i + 1]), Int(pixels[i + 2]))
}

func close(_ a: (Int, Int, Int), _ b: (Int, Int, Int)) -> Bool {
    abs(a.0 - b.0) <= tolerance && abs(a.1 - b.1) <= tolerance && abs(a.2 - b.2) <= tolerance
}

func hex(_ c: (Int, Int, Int)) -> String {
    String(format: "#%02x%02x%02x", c.0, c.1, c.2)
}

func report() {
    if let col {
        let y0 = max(0, from)
        let y1 = min(height - 1, to)
        var runStart = y0
        var current = colorAt(col, y0)
        var y = y0 + 1
        while y <= y1 {
            let c = colorAt(col, y)
            if !close(c, current) {
                print("y=\(runStart)..\(y - 1) len=\(y - runStart) \(hex(current))")
                runStart = y
                current = c
            }
            y += 1
        }
        print("y=\(runStart)..\(y1) len=\(y1 - runStart + 1) \(hex(current))")
    } else if let row {
        let x0 = max(0, from)
        let x1 = min(width - 1, to)
        var runStart = x0
        var current = colorAt(x0, row)
        var x = x0 + 1
        while x <= x1 {
            let c = colorAt(x, row)
            if !close(c, current) {
                print("x=\(runStart)..\(x - 1) len=\(x - runStart) \(hex(current))")
                runStart = x
                current = c
            }
            x += 1
        }
        print("x=\(runStart)..\(x1) len=\(x1 - runStart + 1) \(hex(current))")
    } else {
        usage()
    }
}

print("size=\(width)x\(height)")
report()
