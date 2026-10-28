import Foundation
import CoreGraphics
import ImageIO

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil)!
let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
let width = image.width
let height = image.height
var pixels = [UInt8](repeating: 0, count: width * height * 4)
let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
let stride = (width + 7) / 8
let layers: [(String, Int)] = [("silhouette", 256), ("light", 220), ("mid", 160), ("ink", 96)]
for (name, threshold) in layers {
    var mask = [UInt8](repeating: 0, count: stride * height)
    for y in 0..<height {
        for x in 0..<width {
            let offset = (y * width + x) * 4
            let alpha = Int(pixels[offset + 3])
            guard alpha >= 80 else { continue }
            let luminance = min(255, (Int(pixels[offset]) + Int(pixels[offset + 1]) + Int(pixels[offset + 2])) * 255 / (3 * alpha))
            if luminance < threshold {
                mask[y * stride + x / 8] |= UInt8(128 >> (x % 8))
            }
        }
    }
    var data = Data("P4\n\(width) \(height)\n".utf8)
    data.append(contentsOf: mask)
    try data.write(to: outputURL.appendingPathComponent("\(name).pbm"))
}
print("Prepared four tonal masks at \(width) × \(height)")
