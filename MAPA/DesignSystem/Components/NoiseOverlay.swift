import SwiftUI
import UIKit

/// Едва заметное зерно поверх градиентов.
///
/// Без него большие плавные заливки на OLED дают «полосы» (color banding) —
/// картинка выглядит дёшево. Шум ломает полосы и добавляет фактуру.
/// Текстура генерируется один раз и тайлится, поэтому стоит копейки.
public struct NoiseOverlay: View {

    private let opacity: Double

    public init(opacity: Double = 0.04) {
        self.opacity = opacity
    }

    public var body: some View {
        Image(uiImage: NoiseTexture.shared)
            .resizable(resizingMode: .tile)
            .opacity(opacity)
            .blendMode(.overlay)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private enum NoiseTexture {
    /// 96×96 хватает: на глаз повтор не читается.
    static let shared: UIImage = make(size: 96)

    static func make(size: Int) -> UIImage {
        let bytesPerPixel = 4
        let byteCount = size * size * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: byteCount)

        var seed: UInt64 = 0x9E3779B97F4A7C15
        for index in stride(from: 0, to: byteCount, by: bytesPerPixel) {
            // Быстрый детерминированный генератор — текстура одинакова при каждом запуске.
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let value = UInt8((seed >> 33) & 0xFF)
            pixels[index]     = value
            pixels[index + 1] = value
            pixels[index + 2] = value
            pixels[index + 3] = 255
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * bytesPerPixel,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = context.makeImage() else {
            return UIImage()
        }
        return UIImage(cgImage: cgImage)
    }
}
