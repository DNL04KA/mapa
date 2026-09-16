import UIKit

/// Загрузка и хранение картинок из сети.
///
/// Три уровня, от быстрого к медленному: память → диск → сеть. Диск нужен,
/// потому что в поездке интернета может не быть вовсе, а маршрут посмотреть
/// хочется; память — чтобы прокрутка списка не дёргалась на чтении файлов.
///
/// Один и тот же снимок часто просят сразу несколько карточек. Чтобы не качать
/// его дважды, запросы в работе запоминаются и все ждут один результат.
actor RemoteImageStore {

    static let shared = RemoteImageStore()

    /// NSCache потокобезопасен сам по себе — отсюда `nonisolated`:
    /// иначе быструю проверку «уже загружено?» пришлось бы делать через await,
    /// и карточка моргала бы заглушкой там, где картинка уже готова.
    private nonisolated let memory = MemoryCache()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]
    private let folder: URL

    init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        folder = caches.appendingPathComponent("remote-images", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

    }

    /// Готовая картинка, если она уже в памяти. Нужна, чтобы при появлении
    /// карточки не показывать заглушку там, где показывать нечего ждать.
    nonisolated func cached(_ url: URL) -> UIImage? {
        memory.image(for: url)
    }

    func image(for url: URL) async -> UIImage? {
        if let ready = memory.image(for: url) { return ready }

        if let running = inFlight[url] { return await running.value }

        let task = Task<UIImage?, Never> { [folder] in
            let file = folder.appendingPathComponent(Self.fileName(for: url))
            if let data = try? Data(contentsOf: file), let image = UIImage(data: data) {
                return image
            }
            guard let data = try? await download(url), let image = UIImage(data: data) else {
                return nil
            }
            try? data.write(to: file, options: .atomic)
            return image
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil
        if let image { memory.store(image, for: url) }
        return image
    }

    private func download(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        // Викимедиа просит представляться: анонимные запросы она режет.
        request.setValue("MAPA/0.1 (iOS travel map app)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }

    /// Имя файла на диске. Хэш, а не сам адрес: в адресе есть слэши и кириллица,
    /// а длина имени файла ограничена.
    private nonisolated static func fileName(for url: URL) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in Data(url.absoluteString.utf8) {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16) + "." + (url.pathExtension.isEmpty ? "img" : url.pathExtension)
    }
}


/// Тонкая обёртка над NSCache: он давно потокобезопасен, но не помечен
/// `Sendable`, и без обёртки компилятор не пускает его в актор.
private final class MemoryCache: @unchecked Sendable {
    private let cache = NSCache<NSURL, UIImage>()

    init() { cache.countLimit = 120 }

    func image(for url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }

    func store(_ image: UIImage, for url: URL) { cache.setObject(image, forKey: url as NSURL) }
}
