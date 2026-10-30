import Foundation
import CoreGraphics

struct Shape: Decodable {
    let path: String
    let fill: Bool
    let stroke: Bool
    let width: CGFloat
    let strokeAlpha: CGFloat
}
struct Icon: Decodable { let name: String; let size: CGFloat; let shapes: [Shape] }
let source = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let icons = try JSONDecoder().decode([Icon].self, from: Data(contentsOf: source))
func parse(_ value: String) -> CGPath {
    let regex = try! NSRegularExpression(pattern: "[A-Za-z]|[-+]?(?:[0-9]*\\.)?[0-9]+")
    let tokens = regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).map { String(value[Range($0.range, in: value)!]) }
    let path = CGMutablePath()
    var index = 0
    var command = ""
    var current = CGPoint.zero
    var start = CGPoint.zero
    var previousControl: CGPoint?
    func number() -> CGFloat { defer { index += 1 }; return CGFloat(Double(tokens[index])!) }
    func point(relative: Bool) -> CGPoint {
        let x = number(), y = number()
        return CGPoint(x: x + (relative ? current.x : 0), y: y + (relative ? current.y : 0))
    }
    while index < tokens.count {
        if tokens[index].first!.isLetter { command = tokens[index]; index += 1 }
        let relative = command == command.lowercased()
        switch command.uppercased() {
        case "M":
            current = point(relative: relative); path.move(to: current); start = current
            command = relative ? "l" : "L"
            previousControl = nil
        case "L": current = point(relative: relative); path.addLine(to: current); previousControl = nil
        case "H": current.x = number() + (relative ? current.x : 0); path.addLine(to: current); previousControl = nil
        case "V": current.y = number() + (relative ? current.y : 0); path.addLine(to: current); previousControl = nil
        case "C":
            let a = point(relative: relative), b = point(relative: relative), end = point(relative: relative)
            path.addCurve(to: end, control1: a, control2: b); current = end; previousControl = b
        case "S":
            let a = previousControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
            let b = point(relative: relative), end = point(relative: relative)
            path.addCurve(to: end, control1: a, control2: b); current = end; previousControl = b
        case "Z": path.closeSubpath(); current = start; previousControl = nil; command = ""
        default: fatalError("Unsupported path command: \(command)")
        }
    }
    return path
}
for icon in icons {
    let folder = destination.appendingPathComponent("\(icon.name).imageset", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    var box = CGRect(x: 0, y: 0, width: 24, height: 24)
    let pdf = CGContext(folder.appendingPathComponent("\(icon.name).pdf") as CFURL, mediaBox: &box, nil)!
    pdf.beginPDFPage(nil); pdf.translateBy(x: 0, y: 24); pdf.scaleBy(x: 24 / icon.size, y: -24 / icon.size)
    pdf.setLineCap(.round); pdf.setLineJoin(.round)
    for shape in icon.shapes {
        let path = parse(shape.path)
        if shape.fill {
            pdf.setFillColor(CGColor(gray: 0, alpha: 1)); pdf.addPath(path); pdf.fillPath()
        }
        if shape.stroke {
            pdf.setStrokeColor(CGColor(gray: 0, alpha: shape.strokeAlpha)); pdf.setLineWidth(shape.width)
            pdf.addPath(path); pdf.strokePath()
        }
    }
    pdf.endPDFPage(); pdf.closePDF()
    let contents: [String: Any] = ["images": [["filename": "\(icon.name).pdf", "idiom": "universal"]],
        "info": ["author": "xcode", "version": 1],
        "properties": ["preserves-vector-representation": true, "template-rendering-intent": "template"]]
    try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("Contents.json"))
    print("Exported \(icon.name): 24 × 24 pt vector template")
}
