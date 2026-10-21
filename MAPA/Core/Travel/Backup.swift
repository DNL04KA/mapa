import Foundation

/// Копия карты одним файлом.
///
/// Пока нет входа, всё нажитое лежит только на этом телефоне: удалил
/// приложение — и пятнадцать лет поездок исчезли вместе с ним. Вход
/// решит это по-настоящему, но ждать его, оставив человека без
/// страховки, нельзя. Файл — честная страховка: он лежит там, где
/// человек сам решит, и его можно открыть и прочитать глазами.
struct Backup: Codable, Equatable {

    /// Номер формата. Пригодится, когда файл начнут открывать версией
    /// приложения старше той, что его записала.
    let version: Int
    let exportedAt: Date
    let log: TravelLog
    let routes: [Route]

    static let currentVersion = 1

    init(log: TravelLog, routes: [Route]) {
        self.version = Self.currentVersion
        self.exportedAt = Date()
        self.log = log
        self.routes = routes
    }

    /// Записать копию во временный файл и вернуть его адрес.
    ///
    /// Имя с датой: человек делает копию не один раз, и три файла
    /// «mapa.json» в папке «Загрузки» — это не копии, а головоломка.
    static func write(log: TravelLog, routes: [Route]) -> URL? {
        let backup = Backup(log: log, routes: routes)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(backup) else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let name = "mapa-\(formatter.string(from: backup.exportedAt)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// Прочитать копию. `nil`, если это не наш файл.
    static func read(from url: URL) -> Backup? {
        // Файл выбран в «Файлах» и лежит вне песочницы — без этого
        // разрешения прочитать его нельзя.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(Backup.self, from: data),
              backup.version <= currentVersion else { return nil }
        return backup
    }
}
