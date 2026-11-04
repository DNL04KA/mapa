import UIKit
import XCTest
@testable import MAPA

/// Копия и возвращение из неё.
///
/// Это единственная сегодня страховка от потери телефона, и проверять её
/// надо не руками: ошибка здесь обнаружится ровно в тот момент, когда
/// человек попробует восстановиться, то есть когда всё уже потеряно.
///
/// Главное, что проверяем, — копия содержит то, что обещает. До второй
/// версии она обещала «всё», а возвращала отметки и маршруты: снимки
/// точек и аватар оставались на старом телефоне.
@MainActor
final class BackupRestoreTests: XCTestCase {

    private var madeIDs: [(PhotoStore, String)] = []
    private var files: [URL] = []

    override func tearDown() {
        for (store, id) in madeIDs { store.delete(id: id) }
        for url in files { try? FileManager.default.removeItem(at: url) }
        madeIDs = []
        files = []
        super.tearDown()
    }

    /// Снимок известного цвета — чтобы потом сравнить не только размер.
    private func makePhoto(in store: PhotoStore, color: UIColor) throws -> String {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 24, height: 24))
        }
        let id = try XCTUnwrap(store.save(image))
        madeIDs.append((store, id))
        return id
    }

    private func route(with photoID: String) -> Route {
        var point = RoutePoint(cityID: "JPN-Tokyo", name: "Токио", countryID: "JPN",
                               countryName: "Япония",
                               coordinate: Coordinate(longitude: 139.7, latitude: 35.7),
                               days: 3)
        point.photoID = photoID
        return Route(title: "Япония", points: [point])
    }

    // MARK: - Полный круг

    func testКопияВозвращаетОтметкиМаршрутыПрофильОформлениеИСнимки() throws {
        var log = TravelLog()
        log.set(.visited, for: "ITA")
        log.setHome(HomePlace(countryID: "POL",
                              coordinate: Coordinate(longitude: 21.0, latitude: 52.2),
                              cityName: "Варшава"))

        let routePhoto = try makePhoto(in: .routes, color: .systemBlue)
        let avatarPhoto = try makePhoto(in: .avatars, color: .systemGreen)
        let before = try XCTUnwrap(PhotoStore.routes.data(id: routePhoto))

        var profile = Profile.local()
        profile.name = "Никита"
        profile.avatar = .photo(avatarPhoto)

        let appearance = Backup.Appearance(surfaceID: MapSurface.paper.id,
                                           paletteID: MapPalette.ink.id)

        let url = try XCTUnwrap(Backup.write(log: log,
                                             routes: [route(with: routePhoto)],
                                             profile: profile,
                                             appearance: appearance))
        files.append(url)

        // Чистая установка: снимков на диске больше нет, как на новом
        // телефоне. Всё, что есть у человека, — файл копии.
        PhotoStore.routes.delete(id: routePhoto)
        PhotoStore.avatars.delete(id: avatarPhoto)
        XCTAssertNil(PhotoStore.routes.data(id: routePhoto))

        let restored = try XCTUnwrap(Backup.read(from: url))
        XCTAssertEqual(restored.version, 2)
        XCTAssertEqual(restored.log.status(for: "ITA"), .visited)
        XCTAssertEqual(restored.log.home?.cityName, "Варшава")
        XCTAssertEqual(restored.routes.map(\.title), ["Япония"])
        XCTAssertEqual(restored.profile?.name, "Никита")
        XCTAssertEqual(restored.profile?.avatar, .photo(avatarPhoto))
        XCTAssertEqual(restored.appearance, appearance)
        XCTAssertEqual(restored.photoCount, 2)

        XCTAssertEqual(restored.restorePhotos(), 2)

        // Снимок вернулся под тем же именем — иначе ссылка в маршруте
        // указывала бы в пустоту, — и теми же байтами.
        let after = try XCTUnwrap(PhotoStore.routes.data(id: routePhoto))
        XCTAssertEqual(after, before, "снимок пересжали по дороге")
        XCTAssertNotNil(PhotoStore.avatars.image(id: avatarPhoto))
        XCTAssertEqual(restored.routes[0].points[0].photoID, routePhoto)
    }

    func testСколькоСнимковВКопииВидноДоЕёСоздания() throws {
        let routePhoto = try makePhoto(in: .routes, color: .systemRed)
        let avatarPhoto = try makePhoto(in: .avatars, color: .systemYellow)
        var profile = Profile.local()
        profile.avatar = .photo(avatarPhoto)

        XCTAssertEqual(Backup.photoCount(routes: [route(with: routePhoto)], profile: profile), 2)
        XCTAssertEqual(Backup.photoCount(routes: [], profile: nil), 0)
    }

    // MARK: - Старый формат

    func testКопияПервойВерсииЧитаетсяЦеликом() throws {
        // Настоящий файл, какой записывала первая версия: ни профиля, ни
        // оформления, ни снимков в нём нет вовсе.
        let old = """
        {
          "version" : 1,
          "exportedAt" : "2026-03-01T10:00:00Z",
          "log" : {
            "statuses" : { "ITA" : "visited", "JPN" : "wishlist" },
            "home" : {
              "countryID" : "POL",
              "cityName" : "Варшава",
              "longitude" : 21,
              "latitude" : 52.2
            }
          },
          "routes" : [
            {
              "id" : "6B29FC40-CA47-1067-B31D-00DD010662DA",
              "title" : "Италия",
              "createdAt" : "2026-02-01T10:00:00Z",
              "reviews" : [],
              "points" : [
                {
                  "id" : "6B29FC40-CA47-1067-B31D-00DD010662DB",
                  "name" : "Рим",
                  "longitude" : 12.5,
                  "latitude" : 41.9,
                  "days" : 3,
                  "budget" : 0,
                  "note" : ""
                }
              ]
            }
          ]
        }
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mapa-v1-\(UUID().uuidString).json")
        try Data(old.utf8).write(to: url)
        files.append(url)

        let backup = try XCTUnwrap(Backup.read(from: url), "копия первой версии должна открываться")
        XCTAssertEqual(backup.version, 1)
        XCTAssertEqual(backup.log.status(for: "ITA"), .visited)
        XCTAssertEqual(backup.log.status(for: "JPN"), .wishlist)
        XCTAssertEqual(backup.log.home?.cityName, "Варшава")
        XCTAssertEqual(backup.routes.map(\.title), ["Италия"])
        XCTAssertEqual(backup.routes[0].points.map(\.name), ["Рим"])

        // Чего в старом файле не было — пусто, а не придумано.
        XCTAssertNil(backup.profile)
        XCTAssertNil(backup.appearance)
        XCTAssertEqual(backup.photoCount, 0)
        XCTAssertEqual(backup.restorePhotos(), 0)
        XCTAssertNil(backup.routes[0].startDate)
    }

    func testКопияБудущейВерсииНеОткрывается() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mapa-v99-\(UUID().uuidString).json")
        try Data(#"{"version":99,"exportedAt":"2026-03-01T10:00:00Z","log":{"statuses":{}},"routes":[]}"#.utf8)
            .write(to: url)
        files.append(url)

        XCTAssertNil(Backup.read(from: url),
                     "в копии новой версии есть то, чего мы не умеем вернуть")
    }

    func testЧужойФайлНеПринимается() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-mapa-\(UUID().uuidString).json")
        try Data(#"{"hello":"world"}"#.utf8).write(to: url)
        files.append(url)

        XCTAssertNil(Backup.read(from: url))
    }
}
