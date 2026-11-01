// Composes the Open Graph images (1200×630 PNG) from the site's own render layers and fonts.
// macOS only (AppKit + Core Image), no third-party code.
//
//   swift tools/og-image.swift            # from the repo root; writes assets/img/og-image-{tr,en}.png
//
// The slime is the app's HeroSlime (app/Yumus/Screens/MainView.swift): a lilac radial gradient with
// peach and yellow swirls, cut by slime_mask and lit by the shadow/glitter/dark/bubbles/light layers.

import AppKit
import CoreImage
import CoreText

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1
               ? CommandLine.arguments[1]
               : FileManager.default.currentDirectoryPath)
let layers = root.appendingPathComponent("assets/img/layers")
let fonts = root.appendingPathComponent("assets/fonts")
let outDir = root.appendingPathComponent("assets/img")

let canvas = CGSize(width: 1200, height: 630)

struct Copy {
    let file: String
    let headline: String
    let line1: String
    let line2: String
    let pill: String
}

/// Texts come from src/site.json, so a rename only touches that file.
let copies: [Copy] = {
    let data = try! Data(contentsOf: root.appendingPathComponent("src/site.json"))
    let site = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
    let strings = site["strings"] as! [String: [String: String]]
    return ["tr", "en"].map { lang in
        let text = strings[lang]!
        return Copy(file: "og-image-\(lang).png", headline: text["app"]!, line1: text["og_line1"]!,
                    line2: text["og_line2"]!, pill: text["coming_soon"]!)
    }
}()

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func registerFont(_ name: String) {
    var error: Unmanaged<CFError>?
    if !CTFontManagerRegisterFontsForURL(fonts.appendingPathComponent(name) as CFURL, .process, &error) {
        fatalError("could not register \(name)")
    }
}

/// A variable font instance at a given `wght`.
func font(_ family: String, size: CGFloat, weight: CGFloat) -> NSFont {
    let wghtAxis = 0x7767_6874 // 'wght'
    let descriptor = NSFontDescriptor(fontAttributes: [
        .family: family,
        NSFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wghtAxis: weight],
    ])
    guard let font = NSFont(descriptor: descriptor, size: size) else { fatalError("missing font \(family)") }
    return font
}

func cgImage(_ name: String) -> CGImage {
    let url = layers.appendingPathComponent(name)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("missing \(name)") }
    return image
}

/// The HeroSlime body (gradient + swirls) cut out by slime_mask, as a CGImage of `size`.
func slimeBody(size: CGSize) -> CGImage {
    let scale = size.width / 302
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    // Flip to top-left origin so the app's coordinates apply as written.
    ctx.translateBy(x: 0, y: size.height)
    ctx.scaleBy(x: 1, y: -1)
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [color(0xD7C8FF).cgColor, color(0xA98AE8).cgColor, color(0x4A2F96).cgColor] as CFArray,
                              locations: [0, 0.5, 1])!
    let center = CGPoint(x: size.width * 0.45, y: size.height * 0.38)
    ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center,
                           endRadius: 220 * scale, options: [.drawsAfterEndLocation])
    NSGraphicsContext.restoreGraphicsState()

    var body = CIImage(bitmapImageRep: rep)!
    let swirls: [(CGPoint, CGPoint, CGPoint, CGPoint, NSColor, CGFloat)] = [
        (CGPoint(x: 60, y: 112), CGPoint(x: 103, y: 60), CGPoint(x: 173, y: 164), CGPoint(x: 243, y: 86), color(0xFF9F72, 0.8), 21),
        (CGPoint(x: 86, y: 146), CGPoint(x: 129, y: 120), CGPoint(x: 164, y: 159), CGPoint(x: 216, y: 129), color(0xF6D03C, 0.65), 10),
    ]
    for (start, c1, c2, end, stroke, width) in swirls {
        let strokeRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: strokeRep)
        let sctx = NSGraphicsContext.current!.cgContext
        sctx.translateBy(x: 0, y: size.height)
        sctx.scaleBy(x: scale, y: -scale)
        sctx.setStrokeColor(stroke.cgColor)
        sctx.setLineWidth(width)
        sctx.setLineCap(.round)
        sctx.move(to: start)
        sctx.addCurve(to: end, control1: c1, control2: c2)
        sctx.strokePath()
        NSGraphicsContext.restoreGraphicsState()
        let blurred = CIImage(bitmapImageRep: strokeRep)!
            .clampedToExtent()
            .applyingGaussianBlur(sigma: 5 * scale)
            .cropped(to: body.extent)
        body = blurred.composited(over: body)
    }

    let mask = CIImage(cgImage: cgImage("slime_mask.webp"))
    let maskScaled = mask.transformed(by: CGAffineTransform(scaleX: size.width / mask.extent.width,
                                                             y: size.height / mask.extent.height))
    let cut = body.applyingFilter("CIBlendWithAlphaMask", parameters: [
        kCIInputBackgroundImageKey: CIImage.empty(),
        kCIInputMaskImageKey: maskScaled,
    ])
    let context = CIContext()
    return context.createCGImage(cut, from: CGRect(origin: .zero, size: size))!
}

registerFont("Fredoka.ttf")
registerFont("Nunito.ttf")

for copy in copies {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas.width), pixelsHigh: Int(canvas.height),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Milk background with a lavender disc behind the slime.
    color(0xF7F2EC).setFill()
    NSRect(origin: .zero, size: canvas).fill()
    color(0xEBE2FF).setFill()
    NSBezierPath(ovalIn: NSRect(x: 600, y: -70, width: 700, height: 700)).fill()

    // Slime (AppKit origin is bottom-left).
    let slimeRect = CGRect(x: 610, y: 120, width: 560, height: 400)
    ctx.draw(cgImage("slime_shadow.webp"), in: slimeRect)
    ctx.draw(slimeBody(size: CGSize(width: slimeRect.width * 2, height: slimeRect.height * 2)), in: slimeRect)
    for layer in ["slime_glitter.webp", "slime_dark.webp", "slime_bubbles.webp", "slime_light.webp"] {
        ctx.draw(cgImage(layer), in: slimeRect)
    }

    let ink = color(0x33262E)
    let inkSecondary = color(0x6B5B66)
    NSAttributedString(string: copy.headline, attributes: [
        .font: font("Fredoka", size: 132, weight: 600), .foregroundColor: ink, .kern: -1,
    ]).draw(at: NSPoint(x: 80, y: 330))
    let body: [NSAttributedString.Key: Any] = [.font: font("Nunito", size: 31, weight: 700), .foregroundColor: inkSecondary]
    NSAttributedString(string: copy.line1, attributes: body).draw(at: NSPoint(x: 84, y: 272))
    NSAttributedString(string: copy.line2, attributes: body).draw(at: NSPoint(x: 84, y: 228))

    // "Coming soon" pill in the action colour.
    let pillText = NSAttributedString(string: copy.pill, attributes: [
        .font: font("Nunito", size: 28, weight: 800), .foregroundColor: NSColor.white,
    ])
    let textSize = pillText.size()
    let pill = NSRect(x: 80, y: 104, width: textSize.width + 64, height: 72)
    color(0x6F4BD8).setFill()
    NSBezierPath(roundedRect: pill, xRadius: 36, yRadius: 36).fill()
    pillText.draw(at: NSPoint(x: pill.minX + 32, y: pill.midY - textSize.height / 2))

    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: outDir.appendingPathComponent(copy.file))
    print("wrote assets/img/\(copy.file)")
}
