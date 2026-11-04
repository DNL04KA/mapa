import Foundation

/// Копия всего нажитого одним файлом.
///
/// Пока нет входа, всё лежит только на этом телефоне: удалил приложение —
/// и пятнадцать лет поездок исчезли вместе с ним. Вход решит это
/// по-настоящему, но ждать его, оставив человека без страховки, нельзя.
/// Файл — честная страховка: он лежит там, где человек сам решит, и его
/// можно открыть и прочитать глазами.
///
/// Во второй версии в копию входят ещё профиль, выбранное оформление и
/// сами фотографии. До этого копия обещала больше, чем содержала: человек
/// сохранял «всё», а возвращались только отметки и маршруты — снимки
/// точек и аватар оставались на старом телефоне.
///
/// Фотографии едут внутри того же файла в base64. Это дороже отдельной
/// папки по месту, но копия остаётся одним файлом, который можно отправить
/// себе в мессенджер и не искать потом половину.
struct Backup: Codable, Equatable {

    /// Номер формата.
    ///
    /// Читается при открытии: копию, записанную версией приложения новее
    /// этой, трогать нельзя — в ней есть то, чего мы не умеем вернуть.
    /// Копия первой версии открывается как была: полей профиля и снимков
    /// в ней просто нет, и они становятся пустыми.
    let version: Int
    let exportedAt: Date
    let log: TravelLog
    let routes: [Route]
    /// Имя, никнейм и аватар. Без профиля восстановленная карта
    /// принадлежит безымянному путешественнику.
    let profile: Profile?
    /// Выбранное полотно и палитра.
    let appearance: Appearance?
    /// Снимки точек маршрута: идентификатор файла → JPEG в base64.
    let routePhotos: [String: String]?
    /// Своё фото на аватаре, если оно есть.
    let avatarPhotos: [String: String]?

    static let currentVersion = 2

    struct Appearance: Codable, Equatable {
        let surfaceID: String
        let paletteID: String
    }

    init(log: TravelLog,
         routes: [Route],
         profile: Profile?,
         appearance: Appearance?,
         routePhotos: [String: String],
         avatarPhotos: [String: String]) {
        self.version = Self.currentVersion
        self.exportedAt = Date()
        self.log = log
        self.routes = routes
        self.profile = profile
        self.appearance = appearance
        self.routePhotos = routePhotos
        self.avatarPhotos = avatarPhotos
    }

    /// Сколько снимков внутри — то, что показываем человеку до того, как
    /// он нажмёт «Сохранить копию».
    var photoCount: Int {
        (routePhotos?.count ?? 0) + (avatarPhotos?.count ?? 0)
    }

    // MARK: - Запись

    /// Собрать копию и записать во временный файл.
    ///
    /// Снимки берутся байтами с диска, а не пересжимаются: копировать надо
    /// ровно то, что есть. Имя файла с датой: человек делает копию не один
    /// раз, и три файла «mapa.json» в «Загрузках» — это не копии, а
    /// головоломка.
    static func write(log: TravelLog,
                      routes: [Route],
                      profile: Profile?,
                      appearance: Appearance?) -> URL? {
        let backup = Backup(
            log: log,
            routes: routes,
            profile: profile,
            appearance: appearance,
            routePhotos: collect(ids: routePhotoIDs(in: routes), from: .routes),
            avatarPhotos: collect(ids: avatarPhotoIDs(of: profile), from: .avatars)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(backup) else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
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

    /// Сколько снимков уедет в копию — без самой копии.
    /// Нужно экрану настроек: обещание «сохранить всё» должно быть
    /// проверяемым до нажатия.
    static func photoCount(routes: [Route], profile: Profile?) -> Int {
        routePhotoIDs(in: routes).count + avatarPhotoIDs(of: profile).count
    }

    // MARK: - Чтение

    /// Прочитать копию. `nil`, если это не наш файл.
    static func read(from url: URL) -> Backup? {
        // Файл выбран в «Файлах» и лежит вне песочницы — без этого
        // разрешения прочитать его нельзя.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Копия первой версии читается тем же разбором: новых полей в ней
        // нет, и они становятся пустыми. Копию будущей версии не трогаем.
        guard let backup = try? SchemaProbe.decode(Backup.self,
                                                   from: data,
                                                   supported: currentVersion,
                                                   using: decoder) else { return nil }
        return backup
    }

    /// Разложить снимки из копии обратно по хранилищам.
    ///
    /// Делается до того, как маршруты попадут на экран: иначе человек
    /// секунду смотрит на свои точки с пустыми рамками и решает, что
    /// фотографии не вернулись.
    @discardableResult
    func restorePhotos() -> Int {
        var restored = 0
        for (id, encoded) in routePhotos ?? [:] {
            guard let data = Data(base64Encoded: encoded) else { continue }
            if PhotoStore.routes.restore(id: id, data: data) { restored += 1 }
        }
        for (id, encoded) in avatarPhotos ?? [:] {
            guard let data = Data(base64Encoded: encoded) else { continue }
            if PhotoStore.avatars.restore(id: id, data: data) { restored += 1 }
        }
        return restored
    }

    // MARK: - Внутри

    private static func routePhotoIDs(in routes: [Route]) -> [String] {
        routes.flatMap { $0.points.compactMap(\.photoID) }
    }

    private static func avatarPhotoIDs(of profile: Profile?) -> [String] {
        if case let .photo(id) = profile?.avatar { return [id] }
        return []
    }

    private static func collect(ids: [String], from store: PhotoStore) -> [String: String] {
        var result: [String: String] = [:]
        for id in ids where result[id] == nil {
            guard let data = store.data(id: id) else { continue }
            result[id] = data.base64EncodedString()
        }
        return result
    }
}
