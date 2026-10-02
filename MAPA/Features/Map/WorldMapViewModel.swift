import Combine
import SwiftUI
import UIKit

/// Счётчики отрисовки. Обычный класс, а не `ObservableObject`:
/// если бы каждый кадр публиковал изменение, замер сам бы стал причиной просадки.
/// HUD читает эти значения по таймеру.
final class RenderStats {

    private(set) var lastMilliseconds: Double = 0
    private var samples: [Double] = []
    private let capacity = 90

    func record(_ milliseconds: Double) {
        lastMilliseconds = milliseconds
        samples.append(milliseconds)
        if samples.count > capacity {
            samples.removeFirst(samples.count - capacity)
        }
    }

    var averageMilliseconds: Double {
        guard !samples.isEmpty else { return 0 }
        return samples.reduce(0, +) / Double(samples.count)
    }

    var worstMilliseconds: Double { samples.max() ?? 0 }

    func reset() {
        samples.removeAll(keepingCapacity: true)
        lastMilliseconds = 0
    }
}

@MainActor
final class WorldMapViewModel: ObservableObject {

    enum LoadState: Equatable {
        case loading
        case ready
        case failed(String)
    }

    @Published private(set) var state: LoadState = .loading
    @Published private(set) var geometry: WorldGeometry?
    @Published private(set) var cities: [City] = []
    /// Город под открытой панелью города.
    @Published private(set) var selectedCity: City?
    @Published var camera: MapCamera = .world
    @Published private(set) var loadDuration: TimeInterval = 0

    /// Отметки пользователя.
    @Published private(set) var travelLog = TravelLog()
    /// Всё, что показывает панель статистики. Пересчитывается при каждой отметке.
    @Published private(set) var statistics: TravelStatistics = .empty
    /// Всё, что рисуется поверх базовой суши.
    @Published private(set) var overlay = MapOverlayState()
    /// Страна под открытым шитом.
    @Published private(set) var selectedCountry: Country?
    /// Прогресс растекания краски, 0…1.
    @Published var bloomProgress: CGFloat = 0
    /// На сколько поднять карту, чтобы шит не закрыл выбранную страну.
    @Published private(set) var mapShift: CGFloat = 0

    /// Сохранённые маршруты.
    @Published private(set) var routes: [Route] = []
    /// Маршрут, который сейчас открыт. Просмотр и редактирование — одно и то же
    /// состояние: отдельный режим «только смотрю» добавил бы экран и кнопку,
    /// а пользы не дал бы никакой.
    @Published private(set) var editingRoute: Route?

    /// Где ты сейчас.
    @Published private(set) var currentCoordinate: Coordinate?
    @Published private(set) var locationAccess: LocationService.Access = .notDetermined

    let stats = RenderStats()

    private(set) var viewport: CGSize = .zero
    /// Точка последнего тапа — отсюда растекается заливка.
    private var lastTapUnit = CGPoint(x: 0.5, y: 0.5)
    private var bloomTask: Task<Void, Never>?

    private let storage: TravelLogStorage
    private let routeStorage: RouteStorage
    private var routeSaveTask: Task<Void, Never>?
    private let location = LocationService()
    private var cancellables = Set<AnyCancellable>()

    /// Приближаем к твоей стране только один раз за запуск и только если
    /// ты ещё не тронул карту сам — иначе это выглядело бы как угон управления.
    private var didAutoFocus = false
    private var userHasInteracted = false
    /// Записи выстраиваются в цепочку: каждая ждёт предыдущую.
    /// Без этого два быстрых сохранения могли бы завершиться не в том порядке,
    /// и на диск лёг бы устаревший снимок.
    private var saveTask: Task<Void, Never>?

    init(
        storage: TravelLogStorage = FileTravelLogStorage(),
        routeStorage: RouteStorage = FileRouteStorage()
    ) {
        self.storage = storage
        self.routeStorage = routeStorage

        // Вложенный ObservableObject сам по себе не будит подписчиков,
        // поэтому пробрасываем его значения вручную.
        location.$coordinate
            .receive(on: RunLoop.main)
            .sink { [weak self] coordinate in self?.handle(coordinate) }
            .store(in: &cancellables)

        location.$access
            .receive(on: RunLoop.main)
            .sink { [weak self] access in self?.locationAccess = access }
            .store(in: &cancellables)
    }

    // MARK: - Где ты сейчас

    /// Спрашиваем разрешение по кнопке, а не на старте: диалог без объяснений
    /// закрывают не читая, и второго шанса система не даёт.
    func locateMe() {
        Haptics.shared.tap(.light)
        location.locate()
    }

    private func handle(_ coordinate: Coordinate?) {
        currentCoordinate = coordinate
        guard let coordinate else { return }
        focusOnCurrentCountryIfNeeded(coordinate)
    }

    private func focusOnCurrentCountryIfNeeded(_ coordinate: Coordinate) {
        guard !didAutoFocus, !userHasInteracted, let geometry, viewport.width > 0 else { return }
        let unit = MapProjection.unitPoint(coordinate)
        guard let country = geometry.country(at: unit, tolerance: 0.01) else { return }

        didAutoFocus = true

        // Не наезжаем вплотную: у крошечной страны `focused` уходит в потолок
        // зума, и человек теряет понимание, куда его перенесло.
        var target = camera.focused(on: country, in: viewport)
        target.zoom = min(target.zoom, max(4.5, MapCamera.minZoom(for: viewport) + 1.5))
        move(to: target.clamped(in: viewport), reduceMotion: false)
    }

    // MARK: - Дом

    var isSelectedCountryHome: Bool {
        guard let country = selectedCountry, let home = travelLog.home else { return false }
        return home.countryID == country.id
    }

    /// Дом ставится ровно туда, куда ты ткнул, а не в центр страны.
    func setHomeAtSelection(reduceMotion: Bool) {
        guard let country = selectedCountry else { return }

        travelLog.setHome(
            HomePlace(countryID: country.id, coordinate: MapProjection.coordinate(from: lastTapUnit))
        )
        rebuildMarked(excluding: nil)
        refreshStatistics()
        persist()
        Haptics.shared.success()
        dismissSelection(reduceMotion: reduceMotion)
    }

    func clearHome(reduceMotion: Bool) {
        guard travelLog.home != nil else { return }
        travelLog.setHome(nil)
        persist()
        Haptics.shared.countryClear()
        dismissSelection(reduceMotion: reduceMotion)
    }

    // MARK: - Загрузка

    func load() async {
        guard geometry == nil else { return }
        state = .loading
        do {
            let result = try await WorldGeometryLoader.loadFromBundle()
            geometry = result.geometry
            loadDuration = result.duration

            // Отметки не критичны для запуска: если файл побился, лучше показать
            // пустую карту, чем экран ошибки вместо всего приложения.
            // Города не критичны для карты: если файл не читается,
            // приложение работает без них.
            cities = (try? CityLoader.loadFromBundle()) ?? []
            travelLog = (try? await storage.load()) ?? TravelLog()
            routes = (try? await routeStorage.load()) ?? []

            rebuildMarked(excluding: nil)
            refreshStatistics()
            state = .ready
            focusOnMyWorldIfNeeded()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func updateViewport(_ size: CGSize) {
        guard size != viewport, size.width > 0, size.height > 0 else { return }
        viewport = size
        camera = camera.clamped(in: size)
        // Размер экрана и данные приходят в неизвестном порядке, а кадрировать
        // можно только зная оба. Пробуем на каждом из двух событий.
        focusOnMyWorldIfNeeded()
    }

    /// Первый кадр — по твоим странам, а не по всему Меркатору.
    ///
    /// Иначе половину экрана занимают пустой океан и Антарктида, которую
    /// никто никогда не отметит, а вся твоя жизнь ютится в углу Европы.
    /// Геолокация делает похожее, но только с разрешением, а его дают редко.
    private func focusOnMyWorldIfNeeded() {
        guard !didAutoFocus, !userHasInteracted, let geometry, viewport.width > 0 else { return }

        // Только прожитое: «хочу» люди ставят по всему глобусу, и рамка
        // по мечтам получается размером с мир — то есть никакая.
        var ids = Set(travelLog.statuses.filter { $0.value != .wishlist }.keys)
        if let home = travelLog.home { ids.insert(home.countryID) }
        if ids.isEmpty { ids = Set(travelLog.statuses.keys) }
        guard !ids.isEmpty, let box = geometry.bounds(of: ids) else { return }

        didAutoFocus = true

        // Не наезжаем вплотную: у одной маленькой страны рамка вырождается
        // в точку, и человек не понимает, на что он смотрит.
        var target = camera.fitting(box, in: viewport, padding: 0.2)
        target.zoom = min(target.zoom, 5.5)
        camera = target.clamped(in: viewport)
    }

    // MARK: - Жесты

    func pan(by translation: CGSize) {
        userHasInteracted = true
        camera = camera.panned(by: translation, in: viewport)
    }

    /// Инерция. Формула проекции — из «Designing Fluid Interfaces» (WWDC18):
    /// куда доедет объект, если тормозить с тем же коэффициентом, что и UIScrollView.
    func endPan(velocity: CGPoint, reduceMotion: Bool) {
        guard !reduceMotion else { return }

        let decelerationRate: CGFloat = 0.998
        let factor = decelerationRate / (1 - decelerationRate) / 1000

        let projected = CGSize(width: velocity.x * factor, height: velocity.y * factor)
        guard abs(projected.width) > 1 || abs(projected.height) > 1 else { return }

        let target = camera.panned(by: projected, in: viewport)
        guard target != camera else { return }

        // Кривая близка к экспоненциальному затуханию: резкий старт, длинный выкат.
        withAnimation(.timingCurve(0.19, 1, 0.22, 1, duration: 0.85)) {
            camera = target
        }
    }

    func pinch(scale: CGFloat, anchor: CGPoint) {
        userHasInteracted = true
        camera = camera.zoomed(by: scale, anchor: anchor, in: viewport)
    }

    func doubleTap(at point: CGPoint, reduceMotion: Bool) {
        // Двойной тап на максимуме возвращает к обзору всего мира —
        // так из любого зума есть выход одним жестом.
        let atMaximum = camera.zoom >= MapCamera.maxZoom - 0.01
        let target = atMaximum
            ? MapCamera.world.clamped(in: viewport)
            : camera.zoomed(by: 2.2, anchor: point, in: viewport)

        move(to: target, reduceMotion: reduceMotion)
    }

    // MARK: - Кнопки

    func zoomIn(reduceMotion: Bool) { step(factor: 1.8, reduceMotion: reduceMotion) }
    func zoomOut(reduceMotion: Bool) { step(factor: 1 / 1.8, reduceMotion: reduceMotion) }

    func resetToWorld(reduceMotion: Bool) {
        move(to: MapCamera.world.clamped(in: viewport), reduceMotion: reduceMotion)
    }

    func focus(on country: Country, reduceMotion: Bool) {
        move(to: camera.focused(on: country, in: viewport), reduceMotion: reduceMotion)
    }

    private func step(factor: CGFloat, reduceMotion: Bool) {
        userHasInteracted = true
        let anchor = CGPoint(x: viewport.width / 2, y: viewport.height / 2)
        move(to: camera.zoomed(by: factor, anchor: anchor, in: viewport), reduceMotion: reduceMotion)
    }

    private func move(to target: MapCamera, reduceMotion: Bool) {
        if reduceMotion {
            camera = target
        } else {
            withAnimation(DS.Motion.Preset.flow.animation) {
                camera = target
            }
        }
    }

    // MARK: - Выбор страны

    /// Запас на промах, в точках экрана. Без него в Монако, Люксембург
    /// или Сингапур пальцем не попасть в принципе.
    private static let tapTolerance: CGFloat = 20

    /// Оценка высоты шита. Точности до пикселя тут не нужно:
    /// сдвиг чуть больше необходимого никому не мешает.
    private static let sheetHeight: CGFloat = 330

    func tap(at screenPoint: CGPoint, reduceMotion: Bool) {
        userHasInteracted = true
        guard let geometry else { return }

        // Города проверяем первыми: они лежат поверх стран, и если человек
        // целился в точку с подписью, странно открывать ему страну.
        // Страна при этом остаётся выбранной — иначе её города пропали бы
        // вместе с ней прямо в момент нажатия.
        if let city = city(near: screenPoint) {
            // Когда маршрут открыт, тап по городу означает «добавить»,
            // а не «расскажи про него». Иначе на каждую точку уходило бы
            // три касания вместо одного.
            if editingRoute != nil {
                add(city, reduceMotion: reduceMotion)
                return
            }
            Haptics.shared.selection()
            withAnimation(reduceMotion ? DS.Motion.Preset.smooth.reducedAnimation : DS.Motion.Preset.smooth.animation) {
                selectedCity = city
            }
            return
        }

        let unit = camera.unitPoint(screen: screenPoint, in: viewport)
        let side = camera.worldSide(in: viewport)
        let tolerance = side > 0 ? Self.tapTolerance / side : 0

        guard let country = geometry.country(at: unit, tolerance: tolerance) else {
            // Тап по океану закрывает выбор — это самый естественный способ отменить.
            dismissSelection(reduceMotion: reduceMotion)
            return
        }

        lastTapUnit = unit
        Haptics.shared.selection()

        withAnimation(reduceMotion ? DS.Motion.Preset.smooth.reducedAnimation : DS.Motion.Preset.smooth.animation) {
            selectedCountry = country
            overlay.highlight = country.path
            mapShift = shiftNeeded(for: country)
        }
    }

    func apply(_ status: TravelStatus, reduceMotion: Bool) {
        guard let country = selectedCountry else { return }

        // Повторный выбор того же статуса снимает отметку —
        // отдельная кнопка для этого есть, но так быстрее.
        if travelLog.status(for: country.id) == status {
            clearStatus(reduceMotion: reduceMotion)
            return
        }

        setStatus(status, for: country, origin: lastTapUnit, reduceMotion: reduceMotion)
        dismissSelection(reduceMotion: reduceMotion)
    }

    /// Отметка из карточки страны: тапа по карте не было, поэтому краска
    /// растекается из середины страны, а выбор не сбрасывается — карточка
    /// остаётся открытой.
    func setStatusFromCard(_ status: TravelStatus, for country: Country, reduceMotion: Bool) {
        if travelLog.status(for: country.id) == status {
            travelLog.set(nil, for: country.id)
            refreshStatistics()
            persist()
            rebuildMarked(excluding: nil)
            overlay.bloom = nil
            bloomProgress = 0
            Haptics.shared.countryClear()
            return
        }
        setStatus(status, for: country, origin: country.anchor, reduceMotion: reduceMotion)
    }

    private func setStatus(_ status: TravelStatus, for country: Country, origin: CGPoint, reduceMotion: Bool) {
        travelLog.set(status, for: country.id)
        refreshStatistics()
        persist()
        Haptics.shared.countryFill()

        // Пока краска растекается, страна не должна быть ещё и залита
        // обычным слоем статуса — иначе анимации не видно.
        rebuildMarked(excluding: country.id)

        bloomTask?.cancel()
        bloomProgress = 0
        overlay.bloom = MapOverlayState.Bloom(
            countryID: country.id,
            path: country.path,
            bounds: country.bounds,
            origin: origin,
            status: status,
            tint: DS.StatusColor.tint(for: country.id),
            flagHue: country.flagHue
        )

        let duration: Double = reduceMotion ? 0.16 : 0.8
        withAnimation(reduceMotion ? DS.Motion.Preset.bounce.reducedAnimation : DS.Motion.Preset.bounce.animation) {
            bloomProgress = 1
        }

        // iOS 16 не умеет сообщать об окончании анимации, поэтому ждём вручную.
        // К этому моменту круг заведомо накрыл страну, и подмена незаметна.
        bloomTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            self.overlay.bloom = nil
            self.bloomProgress = 0
            self.rebuildMarked(excluding: nil)
        }
    }

    func clearStatus(reduceMotion: Bool) {
        guard let country = selectedCountry,
              let previous = travelLog.status(for: country.id)
        else {
            dismissSelection(reduceMotion: reduceMotion)
            return
        }

        bloomTask?.cancel()
        travelLog.set(nil, for: country.id)
        refreshStatistics()
        persist()
        Haptics.shared.countryClear()

        // Снятие — та же волна, пущенная назад. Краска стягивается к точке,
        // из которой её налили, а не исчезает рывком.
        rebuildMarked(excluding: nil)
        overlay.bloom = MapOverlayState.Bloom(
            countryID: country.id,
            path: country.path,
            bounds: country.bounds,
            origin: lastTapUnit,
            status: previous,
            tint: DS.StatusColor.tint(for: country.id),
            flagHue: country.flagHue
        )
        bloomProgress = 1

        let duration: Double = reduceMotion ? 0.16 : 0.45
        withAnimation(reduceMotion ? DS.Motion.Preset.smooth.reducedAnimation : .easeIn(duration: duration)) {
            bloomProgress = 0
        }

        bloomTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.overlay.bloom = nil
        }

        dismissSelection(reduceMotion: reduceMotion)
    }

    func dismissSelection(reduceMotion: Bool) {
        guard selectedCountry != nil || selectedCity != nil || mapShift != 0 else { return }
        withAnimation(reduceMotion ? DS.Motion.Preset.smooth.reducedAnimation : DS.Motion.Preset.smooth.animation) {
            selectedCountry = nil
            selectedCity = nil
            overlay.highlight = nil
            mapShift = 0
        }
    }

    /// Города выбранной страны — только они и видны на карте.
    var citiesOfSelectedCountry: [City] {
        guard let id = selectedCountry?.id else { return [] }
        return cities.filter { $0.countryID == id }
    }

    func cities(of country: Country) -> [City] {
        cities.filter { $0.countryID == country.id }.sorted { $0.importance > $1.importance }
    }

    /// Ближайший к точке город в пределах пальца.
    private func city(near screenPoint: CGPoint) -> City? {
        guard viewport.width > 0 else { return nil }
        let offsets = camera.visibleWorldOffsets(in: viewport)
        let reach: CGFloat = 22

        var best: City?
        var bestDistance = CGFloat.greatestFiniteMagnitude

        for city in citiesOfSelectedCountry {
            for offset in offsets {
                let shifted = CGPoint(x: city.unitPoint.x + offset, y: city.unitPoint.y)
                let point = camera.screenPoint(unit: shifted, in: viewport)
                let distance = hypot(point.x - screenPoint.x, point.y - screenPoint.y)
                if distance < bestDistance {
                    bestDistance = distance
                    best = city
                }
            }
        }

        return bestDistance <= reach ? best : nil
    }

    /// Дом из города — с настоящим названием, а не «где-то в стране».
    func setHome(at city: City, reduceMotion: Bool) {
        travelLog.setHome(
            HomePlace(countryID: city.countryID, coordinate: city.coordinate, cityName: city.nameRU)
        )
        rebuildMarked(excluding: nil)
        refreshStatistics()
        persist()
        Haptics.shared.success()
        dismissSelection(reduceMotion: reduceMotion)
    }

    /// Провалиться из страны в город: подводим камеру и открываем панель.
    /// Карта при этом не перескакивает — она доезжает, и контекст не теряется.
    func focus(on city: City, reduceMotion: Bool) {
        var target = camera
        target.zoom = max(camera.zoom, 5.5)
        target.center = city.unitPoint
        move(to: target.clamped(in: viewport), reduceMotion: reduceMotion)

        withAnimation(reduceMotion ? DS.Motion.Preset.smooth.reducedAnimation : DS.Motion.Preset.smooth.animation) {
            selectedCity = city
        }
    }

    func dismissCity(reduceMotion: Bool) {
        guard selectedCity != nil else { return }
        withAnimation(reduceMotion ? DS.Motion.Preset.smooth.reducedAnimation : DS.Motion.Preset.smooth.animation) {
            selectedCity = nil
        }
    }

    var isSelectedCityHome: Bool {
        guard let city = selectedCity, let home = travelLog.home else { return false }
        return home.cityName == city.nameRU && home.countryID == city.countryID
    }

    /// Статус выбранной страны — шит подсвечивает им активную карточку.
    var selectedStatus: TravelStatus? {
        selectedCountry.flatMap { travelLog.status(for: $0.id) }
    }

    // MARK: - Маршруты

    func startRoute(reduceMotion: Bool) {
        Haptics.shared.tap(.light)
        withAnimation(reduceMotion ? DS.Motion.Preset.smooth.reducedAnimation : DS.Motion.Preset.smooth.animation) {
            selectedCountry = nil
            selectedCity = nil
            overlay.highlight = nil
            mapShift = 0
            editingRoute = Route()
        }
        rebuildRouteLine()
    }

    func openRoute(_ route: Route, reduceMotion: Bool) {
        withAnimation(reduceMotion ? DS.Motion.Preset.smooth.reducedAnimation : DS.Motion.Preset.smooth.animation) {
            editingRoute = route
        }
        rebuildRouteLine()
    }

    /// Взять набросок по стране себе.
    ///
    /// Сразу сохраняем, а не оставляем «черновиком до закрытия»: человек уже
    /// сказал «беру», и потерять это из-за случайного свайпа он не должен.
    func takeSuggestedRoute(_ stops: [CountryRoutePlanner.Stop], for country: Country, reduceMotion: Bool) {
        guard stops.count > 1 else { return }
        let route = CountryRoutePlanner.route(
            title: country.nameRU,
            countryID: country.id,
            countryName: country.nameRU,
            stops: stops
        )
        routes.insert(route, at: 0)
        persistRoutes()
        Haptics.shared.success()
        openRoute(route, reduceMotion: reduceMotion)
    }

    func add(_ city: City, reduceMotion: Bool) {
        guard var route = editingRoute else { return }
        // Повторный тап по уже добавленному городу убирает его — так проще
        // исправить промах, чем искать точку в списке.
        if let index = route.points.firstIndex(where: { $0.cityID == city.id }) {
            route.points.remove(at: index)
            Haptics.shared.countryClear()
        } else {
            route.points.append(
                RoutePoint(city: city, countryName: geometry?.country(id: city.countryID)?.nameRU)
            )
            Haptics.shared.countryFill()
        }
        withAnimation(reduceMotion ? DS.Motion.Preset.bounce.reducedAnimation : DS.Motion.Preset.bounce.animation) {
            editingRoute = route
            rebuildRouteLine()
        }
    }

    func removePoint(_ point: RoutePoint) {
        guard var route = editingRoute else { return }
        route.points.removeAll { $0.id == point.id }
        Haptics.shared.tap(.soft)
        editingRoute = route
        rebuildRouteLine()
    }

    func movePoint(from source: Int, to destination: Int) {
        guard var route = editingRoute,
              route.points.indices.contains(source),
              destination >= 0, destination < route.points.count,
              source != destination
        else { return }
        let point = route.points.remove(at: source)
        route.points.insert(point, at: destination)
        Haptics.shared.selection()
        editingRoute = route
        rebuildRouteLine()
    }

    func update(_ point: RoutePoint) {
        guard var route = editingRoute,
              let index = route.points.firstIndex(where: { $0.id == point.id })
        else { return }
        route.points[index] = point
        editingRoute = route
        rebuildRouteLine()
    }

    /// Закрыть маршрут. Пустой и одиночный не сохраняем: маршрут из одной точки —
    /// это не маршрут, а случайно открытый редактор.
    func closeRoute(reduceMotion: Bool) {
        defer {
            withAnimation(reduceMotion ? DS.Motion.Preset.smooth.reducedAnimation : DS.Motion.Preset.smooth.animation) {
                editingRoute = nil
                overlay.routeLine = []
            }
        }
        guard let route = editingRoute else { return }

        if route.points.count < 2 {
            routes.removeAll { $0.id == route.id }
        } else if let index = routes.firstIndex(where: { $0.id == route.id }) {
            routes[index] = route
        } else {
            routes.insert(route, at: 0)
        }
        persistRoutes()
    }

    func deleteRoute(_ route: Route) {
        routes.removeAll { $0.id == route.id }
        if editingRoute?.id == route.id { editingRoute = nil }
        Haptics.shared.warning()
        persistRoutes()
    }

    // MARK: - Прохождение

    /// Отметить точку пройденной или снять отметку.
    ///
    /// Заодно красим страну: если ты доехал до города, страна посещена —
    /// требовать второго действия на карте было бы бюрократией.
    func togglePassed(_ point: RoutePoint, reduceMotion: Bool) {
        guard var route = editingRoute,
              let index = route.points.firstIndex(where: { $0.id == point.id })
        else { return }

        route.points[index].isVisited.toggle()
        let didPass = route.points[index].isVisited
        editingRoute = route
        rebuildRouteLine()
        syncOpenRoute()

        guard didPass,
              let countryID = point.countryID,
              travelLog.status(for: countryID) == nil,
              let country = geometry?.country(id: countryID)
        else {
            Haptics.shared.tap(didPass ? .medium : .soft)
            return
        }

        setStatus(.visited, for: country, origin: point.unitPoint, reduceMotion: reduceMotion)
    }

    /// Приложить или убрать фотографию точки.
    ///
    /// Старый файл удаляем сразу: иначе замена снимка оставляла бы мусор,
    /// который никто никогда не найдёт и не почистит.
    func setPhoto(_ image: UIImage?, for point: RoutePoint) {
        guard var route = editingRoute,
              let index = route.points.firstIndex(where: { $0.id == point.id })
        else { return }

        if let old = route.points[index].photoID {
            PhotoStore.routes.delete(id: old)
        }

        route.points[index].photoID = image.flatMap(PhotoStore.routes.save)
        editingRoute = route
        syncOpenRoute()
        Haptics.shared.tap(.light)
    }

    // MARK: - Оценки и отзывы

    /// Поставить или изменить свою оценку открытого маршрута.
    ///
    /// Свой отзыв всегда один: повторный вызов правит его, а не плодит копии.
    func rateOpenRoute(_ rating: Int, text: String) {
        guard var route = editingRoute else { return }

        let review = RouteReview(
            id: route.myReview?.id ?? UUID(),
            authorName: "Ты",
            rating: rating,
            text: text,
            createdAt: Date(),
            isMine: true
        )

        route.reviews.removeAll { $0.isMine }
        route.reviews.insert(review, at: 0)
        editingRoute = route
        syncOpenRoute()
        Haptics.shared.success()
    }

    func removeMyReview() {
        guard var route = editingRoute, route.myReview != nil else { return }
        route.reviews.removeAll { $0.isMine }
        editingRoute = route
        syncOpenRoute()
        Haptics.shared.countryClear()
    }

    /// Сохранить открытый маршрут, не закрывая его.
    ///
    /// Отзыв — не черновик: его пишут один раз и ждут, что он останется,
    /// даже если приложение закроют, не нажав «Готово».
    private func syncOpenRoute() {
        guard let route = editingRoute, route.points.count >= 2 else { return }
        if let index = routes.firstIndex(where: { $0.id == route.id }) {
            routes[index] = route
        } else {
            routes.insert(route, at: 0)
        }
        persistRoutes()
    }

    /// Линия маршрута для холста. Пересобирается при смене точек,
    /// а не на каждом кадре.
    private func rebuildRouteLine() {
        overlay.routeLine = editingRoute?.points.map {
            RouteStop(point: $0.unitPoint, isVisited: $0.isVisited)
        } ?? []
    }

    private func persistRoutes() {
        let snapshot = routes
        let previous = routeSaveTask
        routeSaveTask = Task { [routeStorage] in
            await previous?.value
            try? await routeStorage.save(snapshot)
        }
    }

    // MARK: - Служебное

    private func refreshStatistics() {
        statistics = TravelStatistics.make(log: travelLog, geometry: geometry)
    }

    private func persist() {
        let snapshot = travelLog
        let previous = saveTask
        saveTask = Task { [storage] in
            await previous?.value
            try? await storage.save(snapshot)
        }
    }

    /// Дождаться, пока всё записано. Вызывается при уходе приложения в фон.
    func flushPendingSaves() async {
        await saveTask?.value
        await routeSaveTask?.value
    }

    /// Порядок отрисовки: «хочу» внизу, «живу» сверху.
    /// Дом — самое важное на карте, он не должен оказаться под соседом.
    private static func layer(_ status: TravelStatus) -> Int {
        switch status {
        case .wishlist: return 0
        case .visited:  return 1
        case .living:   return 2
        }
    }

    private func rebuildMarked(excluding excludedID: String?) {
        guard let geometry else {
            overlay.marked = []
            return
        }

        overlay.marked = travelLog.statuses
            .compactMap { countryID, status -> MarkedCountry? in
                guard countryID != excludedID, let country = geometry.country(id: countryID) else { return nil }
                return MarkedCountry(
                    id: country.id,
                    path: country.path,
                    bounds: country.bounds,
                    status: status,
                    tint: DS.StatusColor.tint(for: country.id),
                    flagHue: country.flagHue
                )
            }
            // Порядок словаря непредсказуем, а нам нужен устойчивый кадр:
            // сначала слой статуса, внутри слоя — по идентификатору.
            .sorted { left, right in
                let leftLayer = Self.layer(left.status)
                let rightLayer = Self.layer(right.status)
                return leftLayer == rightLayer ? left.id < right.id : leftLayer < rightLayer
            }
    }

    /// Насколько поднять карту, чтобы выбранная страна не оказалась за шитом.
    private func shiftNeeded(for country: Country) -> CGFloat {
        guard viewport.height > 0 else { return 0 }
        let point = camera.screenPoint(unit: country.anchor, in: viewport)
        let limit = viewport.height - Self.sheetHeight - DS.Space.lg
        guard point.y > limit else { return 0 }
        return limit - point.y
    }
}
