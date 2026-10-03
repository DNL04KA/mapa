import AVFoundation
import SwiftUI
import UIKit

/// Сборка видео из нарисованных кадров.
///
/// Кадры не копятся в памяти, а запрашиваются по одному и сразу уходят в файл:
/// сто кадров размером 1080×1920 — это гигабайт с лишним, и телефон такого
/// не простит. Поэтому здесь не «массив картинок», а замыкание, которое
/// рисует кадр по номеру.
enum VideoExporter {

    enum Failure: LocalizedError {
        case writerUnavailable
        case frameFailed(Int)

        var errorDescription: String? {
            switch self {
            case .writerUnavailable: return String(localized: "Не удалось начать запись видео")
            case .frameFailed:       return String(localized: "Не удалось нарисовать кадр")
            }
        }
    }

    /// Рисует и записывает видео, возвращая файл во временной папке.
    ///
    /// - Parameters:
    ///   - size: размер в пикселях. Обе стороны чётные — H.264 иначе не умеет.
    ///   - frameCount: сколько кадров нарисовать.
    ///   - fps: кадров в секунду.
    ///   - makeFrame: рисует кадр по номеру.
    ///   - onProgress: доля готового, 0…1.
    @MainActor
    static func render(
        size: CGSize,
        frameCount: Int,
        fps: Int = 30,
        makeFrame: @MainActor (Int) -> UIImage?,
        onProgress: @MainActor (Double) -> Void = { _ in }
    ) async throws -> URL {

        let width = Int(size.width) & ~1
        let height = Int(size.height) & ~1

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mapa-\(UUID().uuidString).mp4")

        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else {
            throw Failure.writerUnavailable
        }

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                // Поток под соцсети: там всё равно пережмут, и гнаться
                // за качеством бессмысленно — важнее малый файл.
                AVVideoAverageBitRateKey: 6_000_000,
                AVVideoMaxKeyFrameIntervalKey: fps,
            ],
        ])
        // Мы не снимаем с камеры, а рисуем: писать можно так быстро,
        // как получается, а не в темпе реального времени.
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )

        guard writer.canAdd(input) else { throw Failure.writerUnavailable }
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        defer { input.markAsFinished() }

        for index in 0..<frameCount {
            guard let image = makeFrame(index) else { throw Failure.frameFailed(index) }

            // Ждём, пока вход освободится. Без ожидания append молча
            // возвращает false, и видео обрывается на середине.
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }

            guard let pool = adaptor.pixelBufferPool,
                  let buffer = pixelBuffer(from: image, pool: pool, width: width, height: height)
            else { throw Failure.frameFailed(index) }

            let time = CMTime(value: CMTimeValue(index), timescale: CMTimeScale(fps))
            adaptor.append(buffer, withPresentationTime: time)

            onProgress(Double(index + 1) / Double(frameCount))
            // Отдаём кадр циклу: иначе полоска прогресса стоит на месте,
            // и человеку кажется, что приложение зависло.
            await Task.yield()
        }

        input.markAsFinished()
        await writer.finishWriting()

        guard writer.status == .completed else {
            throw writer.error ?? Failure.writerUnavailable
        }
        return url
    }

    /// Картинка → буфер кадра.
    private static func pixelBuffer(
        from image: UIImage,
        pool: CVPixelBufferPool,
        width: Int,
        height: Int
    ) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
              let buffer, let cgImage = image.cgImage
        else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}
