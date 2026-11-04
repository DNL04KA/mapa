import UIKit

/// Снимки, которые добавил сам человек.
///
/// Картинки лежат файлами, а в JSON едет только имя файла. Складывать
/// изображения в сами данные нельзя: пара снимков раздули бы маршрут до
/// мегабайтов, и открытие списка перестало бы быть мгновенным.
///
/// Хранилищ несколько, и у каждого своя папка: снимок точки маршрута и
/// аватарка живут разной жизнью, и удаление маршрута не должно утащить за
/// собой лицо хозяина.
struct PhotoStore {

    /// Фотографии точек маршрута.
    static let routes = PhotoStore(folderName: "route-photos", maxSide: 1400)

    /// Аватарки. Маленькая сторона не случайна: аватар показывается кружком
    /// в 64 пункта, и хранить для него снимок с камеры целиком незачем.
    static let avatars = PhotoStore(folderName: "avatars", maxSide: 512)

    private let folderName: String
    private let maxSide: CGFloat

    private var folder: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let url = base.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func url(for id: String) -> URL {
        folder.appendingPathComponent("\(id).jpg")
    }

    /// Сохраняет снимок и возвращает его идентификатор.
    func save(_ image: UIImage) -> String? {
        let id = UUID().uuidString
        guard let data = downscaled(image).jpegData(compressionQuality: 0.82) else { return nil }
        do {
            try data.write(to: url(for: id), options: .atomic)
            return id
        } catch {
            return nil
        }
    }

    func image(id: String) -> UIImage? {
        UIImage(contentsOfFile: url(for: id).path)
    }

    /// Снимок байтами, как он лежит на диске.
    ///
    /// Копии нужен файл, а не картинка: разобрать JPEG в `UIImage` и
    /// сжать обратно — значит терять качество на каждой копии, хотя
    /// копировать надо ровно то, что есть.
    func data(id: String) -> Data? {
        try? Data(contentsOf: url(for: id))
    }

    /// Положить снимок под тем же именем.
    ///
    /// Имя обязано сохраниться: в маршруте лежит ссылка на него, и
    /// снимок с новым именем стал бы чужим файлом рядом с пустой рамкой.
    @discardableResult
    func restore(id: String, data: Data) -> Bool {
        guard !id.isEmpty, !id.contains("/"), !id.contains("..") else { return false }
        do {
            try data.write(to: url(for: id), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Что вообще лежит в папке.
    ///
    /// Нужно уборке: файл, на который не ссылается ни один маршрут,
    /// не вернётся сам — его некому показать и некому удалить.
    func storedIDs() -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return files.filter { $0.hasSuffix(".jpg") }.map { String($0.dropLast(4)) }
    }

    func delete(id: String) {
        try? FileManager.default.removeItem(at: url(for: id))
    }

    private func downscaled(_ image: UIImage) -> UIImage {
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
