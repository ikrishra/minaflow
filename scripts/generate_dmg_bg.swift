import Cocoa

let width: CGFloat = 600
let height: CGFloat = 380
let scale: CGFloat = 2.0 // @2x Retina

let image = NSImage(size: NSSize(width: width * scale, height: height * scale))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    exit(1)
}

// Scale for retina
ctx.scaleBy(x: scale, y: scale)

// Background: subtle sleek modern gradient (subtle dark slate/zinc)
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bgColors = [
    NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.12, alpha: 1.0).cgColor,
    NSColor(calibratedRed: 0.07, green: 0.07, blue: 0.08, alpha: 1.0).cgColor
] as CFArray

if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 0), options: [])
}

// Draw Title / Instruction at top
let titleText = "Drag MinaFlow to your Applications folder" as NSString
let titleFont = NSFont.systemFont(ofSize: 15, weight: .semibold)
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: NSColor(calibratedWhite: 0.90, alpha: 1.0)
]
let titleSize = titleText.size(withAttributes: titleAttrs)
let titleRect = CGRect(
    x: (width - titleSize.width) / 2.0,
    y: height - 68,
    width: titleSize.width,
    height: titleSize.height
)
titleText.draw(in: titleRect, withAttributes: titleAttrs)

// Draw Subtitle
let subtitleText = "Then right-click MinaFlow in Applications & select Open" as NSString
let subtitleFont = NSFont.systemFont(ofSize: 12, weight: .regular)
let subtitleAttrs: [NSAttributedString.Key: Any] = [
    .font: subtitleFont,
    .foregroundColor: NSColor(calibratedWhite: 0.55, alpha: 1.0)
]
let subtitleSize = subtitleText.size(withAttributes: subtitleAttrs)
let subtitleRect = CGRect(
    x: (width - subtitleSize.width) / 2.0,
    y: height - 90,
    width: subtitleSize.width,
    height: subtitleSize.height
)
subtitleText.draw(in: subtitleRect, withAttributes: subtitleAttrs)

// Draw Sleek Directional Arrow between (x: 230, y: 190) and (x: 370, y: 190)
// Icon 1 is at x: 160, y: 190. Icon 2 is at x: 440, y: 190.
// In Mac DMG coordinates, (0,0) is top-left in create-dmg, but Cocoa CGContext has (0,0) at bottom-left!
// create-dmg window height = 380.
// If create-dmg icon y = 190 (from top), that's y = 380 - 190 = 190 from bottom!
let arrowY: CGFloat = 190
let startX: CGFloat = 240
let endX: CGFloat = 360

ctx.saveGState()
ctx.setStrokeColor(NSColor(calibratedRed: 1.0, green: 0.40, blue: 0.05, alpha: 0.85).cgColor)
ctx.setLineWidth(3.0)
ctx.setLineCap(.round)

// Main arrow shaft
ctx.move(to: CGPoint(x: startX, y: arrowY))
ctx.addLine(to: CGPoint(x: endX, y: arrowY))
ctx.strokePath()

// Arrow head
ctx.beginPath()
ctx.move(to: CGPoint(x: endX - 12, y: arrowY + 9))
ctx.addLine(to: CGPoint(x: endX, y: arrowY))
ctx.addLine(to: CGPoint(x: endX - 12, y: arrowY - 9))
ctx.strokePath()

ctx.restoreGState()

image.unlockFocus()

// Save image representation
if let tiffData = image.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiffData),
   let pngData = bitmap.representation(using: .png, properties: [:]) {
    try? pngData.write(to: URL(fileURLWithPath: "Resources/dmg-background.png"))
    print("Successfully generated Resources/dmg-background.png")
}
