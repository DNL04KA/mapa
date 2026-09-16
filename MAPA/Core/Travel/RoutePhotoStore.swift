import UIKit

/// Фотографии точек маршрута.
///
/// Картинки лежат файлами рядом с маршрутами, а в JSON едет только имя файла.
/// Складывать изображения в сам маршрут нельзя: пара снимков раздули бы его
/// до мегабайтов, и открытие списка перестало бы быть мгновенным.
enum RoutePhotoStore {

    private static let folderName = "route-photos"

    private static var folder: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let url = base.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func url(for id: String) -> URL {
        folder.appendingPathComponent("\(id).jpg")
    }

    /// Сохраняет снимок и возвращает его идентификатор.
    ///
    /// Картинка ужимается до 1400 точек по длинной стороне: на экране точки
    /// маршрута она занимает 72 пункта, а снимок с камеры весит десяток
    /// мегабайт — хранить его целиком незачем.
    static func save(_ image: UIImage) -> String? {
        let id = UUID().uuidString
        guard let data = downscaled(image).jpegData(compressionQuality: 0.82) else { return nil }
        do {
            try data.write(to: url(for: id), options: .atomic)
            return id
        } catch {
            return nil
        }
    }

    static func image(id: String) -> UIImage? {
        UIImage(contentsOfFile: url(for: id).path)
    }

    static func delete(id: String) {
        try? FileManager.default.removeItem(at: url(for: id))
    }

    private static func downscaled(_ image: UIImage, maxSide: CGFloat = 1400) -> UIImage {
        let side = max(image.size.width, image.size.height)
        guard side > maxSide else { return image }

        let scale = maxSide / side
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
