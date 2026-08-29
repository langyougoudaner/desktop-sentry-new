import Foundation

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: BuildICNS.swift <AppIcon.iconset> <AppIcon.icns>")
}

let iconset = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let entries: [(type: String, file: String)] = [
    ("ic10", "icon_512x512@2x.png"),
    ("ic09", "icon_512x512.png"),
    ("ic08", "icon_256x256.png"),
    ("ic07", "icon_128x128.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("icp5", "icon_32x32.png"),
    ("icp4", "icon_16x16.png")
]

func bigEndianUInt32(_ value: Int) -> Data {
    var encoded = UInt32(value).bigEndian
    return Data(bytes: &encoded, count: MemoryLayout<UInt32>.size)
}

var body = Data()
for entry in entries {
    let png = try Data(contentsOf: iconset.appendingPathComponent(entry.file))
    guard let type = entry.type.data(using: .ascii), type.count == 4 else {
        fatalError("Invalid ICNS entry type")
    }
    body.append(type)
    body.append(bigEndianUInt32(8 + png.count))
    body.append(png)
}

var icns = Data("icns".utf8)
icns.append(bigEndianUInt32(8 + body.count))
icns.append(body)
try icns.write(to: output, options: .atomic)
print(output.path)
