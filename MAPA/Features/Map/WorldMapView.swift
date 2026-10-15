import SwiftUI

/// Экран карты мира.
struct WorldMapView: View {

    @StateObject private var model = WorldMapViewModel()
    @StateObject private var account = AccountStore()
    @Environment(\.dsMotion) private var motion

    @State private var showsDebug = false
    /// Первый запуск показывается один раз и больше не возвращается.
    @AppStorage("onboarding.done") private var onboardingDone = false
    @State private var statsExpanded = false
    @State private var showsThemes = false
    @State private var showsAccount = false
    @State private var showsSearch = false
    /// Платное полотно или палитра, которые сейчас примеряют.
    /// Живёт только пока открыта панель.
    @State private var previewChoice: ThemePreview?
    /// Страна, чья карточка открыта.
    @State private var cardCountry: Country?
    @State private var showsRoutes = false
    @State private var showsExport = false
    @State private var routeExpanded = false
    @Environment(\.scenePhase) private var scenePhase

    let surface: MapSurface
    let palette: MapPalette
    let onSelectSurface: (MapSurface) -> Void
    let onSelectPalette: (MapPalette) -> Void
    /// Витрина дизайн-системы осталась рабочим инструментом
    /// и открывается из панели оформления.
    let onOpenGallery: () -> Void

    var body: some View {
        ZStack {
            mapLayer
            overlays
            sheets
            countryCard
            onboarding
        }
        .environment(\.mapTheme, activeTheme)
        .onChange(of: scenePhase) { phase in
            // Уходим в фон — дожидаемся записи, чтобы отметка не потерялась.
            guard phase != .active else { return }
            Task { await model.flushPendingSaves() }
        }
        .task {
            await model.load()
            #if DEBUG
            openScreenFromEnvironment()
            #endif
        }
    }

    #if DEBUG
    /// Открыть панель по переменной окружения.
    ///
    /// У симулятора в командной строке нет пальцев: нажать «Маршруты» и
    /// снять, как это выглядит, нельзя. Запуск с `MAPA_SCREEN=routes`
    /// открывает нужную панель сразу. Данные при этом настоящие —
    /// это только замена нажатию, и в сборку для магазина не попадает.
    private func openScreenFromEnvironment() {
        switch ProcessInfo.processInfo.environment["MAPA_SCREEN"] {
        case "routes": showsRoutes = true
        case "account": showsAccount = true
        case "theme": showsThemes = true
        case "search": showsSearch = true
        case "export": showsExport = true
        case let id? where id.hasPrefix("card-"):
            guard let country = model.geometry?.country(id: String(id.dropFirst(5))) else { return }
            model.select(country, reduceMotion: true)
            cardCountry = country
        default: break
        }
    }
    #endif

    /// Карта — во весь экран, включая вырез и полосу внизу.
    ///
    /// Своя `GeometryReader` с `ignoresSafeArea` нужна не ради вида: камера и
    /// попадание пальцем считаются от `viewport`, и если бы карта рисовалась
    /// во весь экран, а размер приходил из безопасной зоны, тап уезжал бы от
    /// того места, куда человек ткнул. Поэтому рисуем и меряем одним и тем же
    /// прямоугольником. Панели и кнопки живут отдельным слоем — им безопасная
    /// зона как раз нужна.
    private var mapLayer: some View {
        GeometryReader { proxy in
            content(in: proxy.size)
                .onAppear { model.updateViewport(proxy.size) }
                .onChange(of: proxy.size) { model.updateViewport($0) }
        }
        .ignoresSafeArea()
    }

    // MARK: - Состояния

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        switch model.state {
        case .loading:
            MapLoadingView()

        case .failed(let message):
            MapErrorView(message: message) {
                Task { await model.load() }
            }

        case .ready:
            if let geometry = model.geometry {
                ZStack {
                    MapCanvas(
                        camera: model.camera,
                        bloomProgress: model.bloomProgress,
                        geometry: geometry,
                        overlay: model.overlay,
                        stats: model.stats,
                        showsGraticule: true,
                        theme: activeTheme
                    )

                    MapGestureLayer(
                        onPan: { model.pan(by: $0) },
                        onPanEnded: { model.endPan(velocity: $0, reduceMotion: motion.reduceMotion) },
                        onPinch: { model.pinch(scale: $0, anchor: $1) },
                        onPinchEnded: {},
                        onTap: { model.tap(at: $0, reduceMotion: motion.reduceMotion) },
                        onDoubleTap: { model.doubleTap(at: $0, reduceMotion: motion.reduceMotion) }
                    )

                    if activeTheme.grain > 0 {
                        // Зерно бумаги или плёнки — поверх карты, но под метками.
                        NoiseOverlay(opacity: activeTheme.grain)
                    }

                    // Карта нарисована в `Canvas`, и для VoiceOver это одна
                    // картинка: ткнуть в Италию на ощупь невозможно. Пусть
                    // она хотя бы честно скажет, что это карта, и отправит
                    // туда, где страну можно открыть без прицеливания.
                    Color.clear
                        .allowsHitTesting(false)
                        .accessibilityElement()
                        .accessibilityLabel("Карта мира")
                        .accessibilityHint("Чтобы открыть страну или город, воспользуйся поиском")

                    CityMarkersLayer(
                        camera: model.camera,
                        cities: model.citiesOfSelectedCountry,
                        viewport: size,
                        accent: activeTheme.accent,
                        selectedCityID: model.selectedCity?.id,
                        homeCityName: model.travelLog.home?.cityName
                    )

                    MapMarkersLayer(
                        camera: model.camera,
                        home: model.travelLog.home,
                        current: model.currentCoordinate,
                        viewport: size,
                        accent: activeTheme.accent
                    )
                }
                // Двигаем карту вместе со слоем жестов, иначе координаты тапа
                // разъехались бы с тем, что видно на экране.
                .offset(y: model.mapShift)
                .transition(motion.transition(.opacity))
            }
        }
    }

    @ViewBuilder
    private var citySheet: some View {
        if let city = model.selectedCity, cardCountry == nil {
            CitySheet(
                city: city,
                countryName: model.geometry?.country(id: city.countryID)?.nameRU,
                home: model.travelLog.home,
                isHome: model.isSelectedCityHome,
                accent: activeTheme.accent,
                onSetHome: { model.setHome(at: city, reduceMotion: motion.reduceMotion) },
                onDismiss: { model.dismissCity(reduceMotion: motion.reduceMotion) }
            )
            .themedPanel(activeTheme)
            .zIndex(2)
        }
    }

    // MARK: - Экспорт

    @ViewBuilder
    private var exportSheet: some View {
        if showsExport, let geometry = model.geometry {
            ExportSheet(
                theme: activeTheme,
                geometry: geometry,
                overlay: model.overlay,
                statistics: model.statistics,
                route: model.editingRoute,
                homeCity: model.travelLog.home?.cityName,
                markedBounds: geometry.bounds(of: model.travelLog.statuses.keys),
                onDismiss: { withAnimation(motion.animation(.smooth)) { showsExport = false } }
            )
            .themedPanel(activeTheme)
            .zIndex(3)
        }
    }

    // MARK: - Маршруты

    @ViewBuilder
    private var routePanel: some View {
        if let route = model.editingRoute {
            RoutePanel(
                route: route,
                accent: activeTheme.accent,
                isExpanded: $routeExpanded,
                onRemovePoint: { model.removePoint($0) },
                onMovePoint: { model.movePoint(from: $0, to: $1) },
                onTogglePassed: { model.togglePassed($0, reduceMotion: motion.reduceMotion) },
                onSetPhoto: { model.setPhoto($1, for: $0) },
                onChangeDays: { point, days in
                    var updated = point
                    updated.days = max(1, min(60, days))
                    model.update(updated)
                },
                onRate: { model.rateOpenRoute($0, text: $1) },
                onRemoveReview: { model.removeMyReview() },
                onDone: {
                    routeExpanded = false
                    model.closeRoute(reduceMotion: motion.reduceMotion)
                }
            )
            .themedPanel(activeTheme)
            .zIndex(2)
        }
    }

    @ViewBuilder
    private var routesSheet: some View {
        if showsRoutes {
            RoutesSheet(
                routes: model.routes,
                suggestions: model.suggestedCountryRoutes,
                accent: activeTheme.accent,
                onOpen: { route in
                    withAnimation(motion.animation(.smooth)) { showsRoutes = false }
                    routeExpanded = true
                    model.openRoute(route, reduceMotion: motion.reduceMotion)
                },
                onCreate: {
                    withAnimation(motion.animation(.smooth)) { showsRoutes = false }
                    routeExpanded = false
                    model.startRoute(reduceMotion: motion.reduceMotion)
                },
                onDelete: { model.deleteRoute($0) },
                onTakeSuggestion: { suggestion in
                    withAnimation(motion.animation(.smooth)) { showsRoutes = false }
                    model.takeSuggestedRoute(suggestion.stops, for: suggestion.country,
                                             reduceMotion: motion.reduceMotion)
                    routeExpanded = true
                },
                onDismiss: { withAnimation(motion.animation(.smooth)) { showsRoutes = false } }
            )
            .themedPanel(activeTheme)
            .zIndex(3)
        }
    }

    // MARK: - Карточка страны

    /// Точка, из которой вырастает карточка, в долях экрана.
    ///
    /// `matchedGeometryEffect` здесь не помог: обложка живёт внутри `ScrollView`
    /// с `GeometryReader`, и эффект до неё не доходит — карточка просто
    /// проявлялась. Масштабирование от якоря страны надёжнее и читается так же:
    /// карточка разворачивается ровно из того места, куда ты ткнул.
    private var cardAnchor: UnitPoint {
        guard let country = cardCountry else { return .center }
        let viewport = model.viewport
        guard viewport.width > 0, viewport.height > 0 else { return .center }

        let point = model.camera.screenPoint(unit: country.anchor, in: viewport)
        return UnitPoint(
            x: min(max(point.x / viewport.width, 0), 1),
            y: min(max((point.y + model.mapShift) / viewport.height, 0), 1)
        )
    }

    @ViewBuilder
    private var countryCard: some View {
        if let country = cardCountry {
            CountryCardView(
                country: country,
                theme: activeTheme,
                status: model.travelLog.status(for: country.id),
                isHome: model.travelLog.home?.countryID == country.id,
                cities: model.cities(of: country),
                onOpenCity: { city in
                    closeCardKeepingSelection()
                    model.focus(on: city, reduceMotion: motion.reduceMotion)
                },
                onTakeRoute: { stops in
                    closeCardKeepingSelection()
                    model.takeSuggestedRoute(stops, for: country, reduceMotion: motion.reduceMotion)
                    routeExpanded = true
                },
                onSelectStatus: { model.setStatusFromCard($0, for: country, reduceMotion: motion.reduceMotion) },
                onClose: { closeCard() }
            )
            .transition(
                motion.transition(
                    .scale(scale: 0.12, anchor: cardAnchor).combined(with: .opacity)
                )
            )
            .themedPanel(activeTheme)
            .zIndex(4)
        }
    }

    private func openCard(for country: Country) {
        Haptics.shared.tap(.light)
        withAnimation(motion.animation(.flow)) {
            cardCountry = country
        }
    }

    /// Закрыть карточку, но не сбрасывать выбранную страну — иначе её города
    /// исчезли бы ровно в тот момент, когда мы в один из них проваливаемся.
    private func closeCardKeepingSelection() {
        withAnimation(motion.animation(.flow)) {
            cardCountry = nil
        }
    }

    private func closeCard() {
        Haptics.shared.tap(.light)
        withAnimation(motion.animation(.flow)) {
            cardCountry = nil
        }
        model.dismissSelection(reduceMotion: motion.reduceMotion)
    }

    /// Все выезжающие панели одной стопкой.
    ///
    /// Собраны в группу не ради порядка: `ZStack` принимает не больше
    /// десяти дочерних вью, и одиннадцатая ломает сборку сообщением
    /// «лишний аргумент», по которому причину не угадать.
    @ViewBuilder
    private var sheets: some View {
        statusSheet
        citySheet
        routePanel
        routesSheet
        exportSheet
        themeSheet
        accountSheet
        searchSheet
    }

    /// Первый запуск: зачем это всё и откуда ты.
    @ViewBuilder
    private var onboarding: some View {
        if !onboardingDone, model.state == .ready, let geometry = model.geometry {
            OnboardingView(
                index: SearchIndex(countries: geometry.countries, cities: model.cities),
                accent: activeTheme.accent,
                countryName: { geometry.country(id: $0)?.displayName ?? "" },
                onPickHome: { city in
                    model.setHome(at: city, reduceMotion: motion.reduceMotion)
                    // Камера едет на страну, а не на сам город: дом надо
                    // увидеть на карте, а не упереться в него носом.
                    if let country = geometry.country(id: city.countryID) {
                        model.focus(on: country, reduceMotion: motion.reduceMotion)
                    }
                },
                onFinish: {
                    withAnimation(motion.animation(.smooth)) { onboardingDone = true }
                }
            )
            .zIndex(6)
        }
    }

    /// Поиск страны или города.
    @ViewBuilder
    private var searchSheet: some View {
        if showsSearch, let geometry = model.geometry {
            SearchSheet(
                index: SearchIndex(countries: geometry.countries, cities: model.cities),
                accent: activeTheme.accent,
                countryName: { geometry.country(id: $0)?.displayName ?? "" },
                onPick: { result in
                    closeSearch()
                    switch result {
                    case let .country(country):
                        model.select(country, reduceMotion: motion.reduceMotion)
                    case let .city(city):
                        model.focus(on: city, reduceMotion: motion.reduceMotion)
                    }
                },
                onDismiss: { closeSearch() }
            )
            .themedPanel(activeTheme)
            .zIndex(5)
        }
    }

    private func closeSearch() {
        withAnimation(motion.animation(.smooth)) { showsSearch = false }
    }

    @ViewBuilder
    private var accountSheet: some View {
        if showsAccount {
            AccountSheet(
                account: account,
                accent: activeTheme.accent,
                onDismiss: {
                    withAnimation(motion.animation(.smooth)) { showsAccount = false }
                }
            )
            .themedPanel(activeTheme)
            .zIndex(3)
        }
    }

    @ViewBuilder
    private var themeSheet: some View {
        if showsThemes {
            ThemePicker(
                surface: surface,
                palette: palette,
                preview: previewChoice,
                onSelectSurface: { onSelectSurface($0) },
                onSelectPalette: { onSelectPalette($0) },
                onPreview: { candidate in
                    withAnimation(motion.animation(.smooth)) { previewChoice = candidate }
                },
                onDismiss: { closeThemes() },
                onOpenGallery: {
                    closeThemes()
                    onOpenGallery()
                }
            )
            .themedPanel(activeTheme)
            .zIndex(3)
        }
    }

    /// Оформление, которым карта нарисована прямо сейчас.
    ///
    /// Примеряемое подменяет ровно свою половину: выбирая цвета, ты видишь их
    /// на своём полотне, а примеряя полотно — со своими цветами. Нигде не
    /// сохраняется и снимается при закрытии панели.
    private var activeTheme: MapTheme {
        switch previewChoice {
        case let .surface(candidate): return MapTheme(surface: candidate, palette: palette)
        case let .palette(candidate): return MapTheme(surface: surface, palette: candidate)
        case nil: return MapTheme(surface: surface, palette: palette)
        }
    }

    private func closeThemes() {
        withAnimation(motion.animation(.smooth)) {
            showsThemes = false
            previewChoice = nil
        }
    }

    // MARK: - Выбор статуса

    @ViewBuilder
    private var statusSheet: some View {
        if let country = model.selectedCountry, cardCountry == nil,
           model.selectedCity == nil, model.editingRoute == nil {
            CountryStatusSheet(
                country: country,
                currentStatus: model.selectedStatus,
                isHome: model.isSelectedCountryHome,
                onSelect: { model.apply($0, reduceMotion: motion.reduceMotion) },
                onClear: { model.clearStatus(reduceMotion: motion.reduceMotion) },
                onToggleHome: {
                    if model.isSelectedCountryHome {
                        model.clearHome(reduceMotion: motion.reduceMotion)
                    } else {
                        model.setHomeAtSelection(reduceMotion: motion.reduceMotion)
                    }
                },
                onOpenCard: { openCard(for: country) },
                onDismiss: { model.dismissSelection(reduceMotion: motion.reduceMotion) }
            )
            .themedPanel(activeTheme)
            .zIndex(2)
        }
    }

    // MARK: - Поверх карты

    private var overlays: some View {
        ZStack {
            MapVignette()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                MapTopScrim(height: 210)
                Spacer(minLength: 0)
            }
            .ignoresSafeArea(edges: .top)

            VStack(spacing: DS.Space.sm) {
                // Поиск открывается ровно там, где лежит панель мира, и
                // «МИР ОТКРЫТ НА 2.5%» читалось сквозь поле ввода.
                if model.state == .ready, !showsSearch {
                    WorldStatsPanel(
                        statistics: model.statistics,
                        theme: activeTheme,
                        isExpanded: $statsExpanded
                    )
                        .transition(motion.transition(.move(edge: .top).combined(with: .opacity)))
                }

                if showsDebug {
                    HStack {
                        MapDebugOverlay(
                            stats: model.stats,
                            geometry: model.geometry,
                            camera: model.camera,
                            loadDuration: model.loadDuration
                        )
                        Spacer(minLength: 0)
                    }
                    .transition(motion.transition(.move(edge: .leading).combined(with: .opacity)))
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom) {
                    Spacer(minLength: 0)
                    zoomControls
                }

                // Только начатый и недойденный маршрут. Раньше карточка висела
                // всегда и молча — непонятно было, что это и почему оно тут,
                // тем более что маршруты и так открываются кнопкой ниже.
                // Теперь у неё одна работа: вернуть туда, где ты остановился.
                if model.state == .ready, let route = model.routes.first(where: \.isInProgress) {
                    nextRouteCard(route)
                        .transition(motion.transition(.move(edge: .bottom).combined(with: .opacity)))
                }

                mapTabBar
            }
            .padding(DS.Space.md)
        }
    }

    /// Нижняя панель.
    ///
    /// Раньше это были шесть одинаковых серых иконок без подложки и подписей
    /// поверх бледной карты: понять, где маршруты, а где оформление, было
    /// нельзя. Подложка возвращает читаемость, подписи — смысл.
    private var mapTabBar: some View {
        HStack(spacing: 0) {
            tabItem(icon: "person.crop.circle",
                    title: "Профиль",
                    isActive: showsAccount) {
                withAnimation(motion.animation(.smooth)) { showsAccount = true }
            }

            tabItem(icon: "point.topleft.down.curvedto.point.bottomright.up",
                    title: "Маршруты",
                    isActive: model.editingRoute != nil) {
                withAnimation(motion.animation(.smooth)) { showsRoutes = true }
            }

            tabItem(icon: "square.and.arrow.up",
                    title: "Поделиться",
                    isActive: false,
                    isEnabled: !model.statistics.isEmpty) {
                withAnimation(motion.animation(.smooth)) { showsExport = true }
            }

            tabItem(icon: "paintpalette", title: "Оформление", isActive: false) {
                withAnimation(motion.animation(.smooth)) { showsThemes = true }
            }
        }
        .padding(.horizontal, DS.Space.xxs)
        .padding(.vertical, 6)
        .background {
            Capsule(style: .continuous)
                .fill(barFill)
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(activeTheme.mapInk.opacity(0.10), lineWidth: 1)
                }
                .dsShadow(.medium)
        }
    }

    private var barFill: AnyShapeStyle {
        if motion.reduceTransparency {
            return AnyShapeStyle(activeTheme.isLight ? Color.white : DS.Palette.abyss)
        }
        return AnyShapeStyle(activeTheme.isLight
                             ? Color.white.opacity(0.88)
                             : DS.Palette.abyss.opacity(0.82))
    }

    private func tabItem(
        icon: String,
        title: LocalizedStringKey,
        isActive: Bool,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.shared.tap(.light)
            action()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                Text(title)
                    // Растёт вместе с настройкой телефона, но не до конца:
                    // панель лежит поверх карты, и выше трети экрана ей
                    // забираться незачем.
                    .font(DS.FontStyle(10, .medium, .default, .caption2, cap: 1.2))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    // Зазор между подписями: на крупном шрифте «Поделиться»
                    // и «Оформление» слипались в одно слово.
                    .padding(.horizontal, 3)
            }
            .foregroundStyle(isActive ? activeTheme.accent : activeTheme.mapInk.opacity(0.68))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 42)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(Text(title))
    }

    /// Ближайший маршрут прямо на карте.
    ///
    /// Фотографии — самое ценное, что есть в приложении, и до этой правки они
    /// лежали на два касания вглубь. Теперь первый экран сразу показывает,
    /// куда ты собрался.
    private func nextRouteCard(_ route: Route) -> some View {
        Button {
            Haptics.shared.tap(.light)
            model.openRoute(route, reduceMotion: motion.reduceMotion)
            routeExpanded = false
        } label: {
            HStack(spacing: DS.Space.sm) {
                ZStack {
                    Rectangle().fill(activeTheme.accent.opacity(0.12))
                    RemoteImage(url: CityFacts.cover(for: route.points[0].cityID)?.small)
                }
                .frame(width: 48, height: 48)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    // Подпись обязательна: без неё карточка не объясняет,
                    // зачем она на экране.
                    Text("ПРОДОЛЖИТЬ")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(activeTheme.accent)

                    Text(route.displayTitle)
                        .font(DS.Font.subhead)
                        .foregroundStyle(activeTheme.mapInk)
                        .lineLimit(1)

                    Text(routeSummary(route))
                        .font(DS.Font.micro)
                        .foregroundStyle(activeTheme.mapInk.opacity(0.6))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(activeTheme.mapInk.opacity(0.4))
            }
            .padding(DS.Space.xs)
            .padding(.trailing, DS.Space.xs)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(barFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .strokeBorder(activeTheme.mapInk.opacity(0.10), lineWidth: 1)
                    }
                    .dsShadow(.medium)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Продолжить маршрут \(route.displayTitle). \(routeSummary(route))")
    }

    private func routeSummary(_ route: Route) -> String {
        let days = Plural.days(route.totalDays)
        return String(format: NSLocalizedString("%@ из %@ пройдено · %@", comment: ""),
                      "\(route.visitedCount)", "\(route.points.count)", days)
    }

    /// Кнопки без подложек: на карте во весь экран любая плашка вырезает
    /// из неё кусок. Читаемость держит тень под самой иконкой.
    ///
    /// Два смысловых блока с заметным зазором между ними: сверху «найти» и
    /// «где я» — это переход к месту, снизу зум и «весь мир» — это масштаб.
    /// Пока они шли одним столбиком через четыре точки, колонка читалась
    /// как шесть случайных значков.
    private var zoomControls: some View {
        VStack(spacing: DS.Space.md) {
            VStack(spacing: 0) {
                // Поиск — первым: без него до половины приложения не дойти,
                // и это чаще нужно, чем зум.
                MapControlButton(icon: "magnifyingglass", isActive: showsSearch,
                                 tint: activeTheme.accent) {
                    withAnimation(motion.animation(.smooth)) { showsSearch = true }
                }
                .accessibilityLabel("Найти страну или город")

                // «Где я» — управление картой, а не раздел приложения: его
                // место рядом с поиском, а не в нижней панели между профилем
                // и маршрутами.
                MapControlButton(
                    icon: model.locationAccess == .denied ? "location.slash" : "location.fill",
                    isActive: model.currentCoordinate != nil,
                    tint: activeTheme.accent
                ) {
                    model.locateMe()
                }
                .accessibilityLabel("Показать, где я")
            }

            VStack(spacing: 0) {
                MapControlButton(icon: "plus") {
                    model.zoomIn(reduceMotion: motion.reduceMotion)
                }
                .accessibilityLabel("Приблизить")

                MapControlButton(icon: "minus") {
                    model.zoomOut(reduceMotion: motion.reduceMotion)
                }
                .accessibilityLabel("Отдалить")

                MapControlButton(icon: "globe.europe.africa") {
                    model.resetToWorld(reduceMotion: motion.reduceMotion)
                }
                .accessibilityLabel("Показать весь мир")
            }

            #if DEBUG
            // Панель замеров — инструмент разработки, и в сборке для
            // магазина её нет: пользователю спидометр в ряду с зумом
            // ничего не объясняет.
            MapControlButton(icon: "speedometer", isActive: showsDebug) {
                withAnimation(motion.animation(.smooth)) { showsDebug.toggle() }
            }
            .accessibilityLabel("Панель замеров")
            #endif
        }
    }
}

// MARK: - Кнопка управления

struct MapControlButton: View {

    @Environment(\.mapTheme) private var theme

    let icon: String
    var isActive: Bool = false
    var tint: Color = DS.Color.accentSoft
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.shared.tap(.light)
            action()
        } label: {
            Image(systemName: icon)
                // На бумаге значки мельче и тише: крупные жирные символы
                // над светлой картой выглядят как наклейки.
                .font(.system(size: theme.isLight ? 18 : DS.Size.iconMd,
                              weight: theme.isLight ? .medium : .semibold))
                .foregroundStyle(isActive ? tint : theme.mapInk.opacity(theme.isLight ? 0.72 : 1))
                .dsMapText()
                .frame(width: DS.Size.hitTarget, height: DS.Size.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Виньетка

/// Затемнение по краям экрана. Собирает взгляд к центру и прячет стык
/// между картой и фоном приложения.
struct MapVignette: View {

    @Environment(\.mapTheme) private var theme

    var body: some View {
        RadialGradient(
            stops: [
                .init(color: .clear, location: 0.55),
                .init(
                    color: theme.isLight
                        ? Color.white.opacity(0.35)
                        : DS.Palette.void.opacity(0.45),
                    location: 1.0
                )
            ],
            center: .center,
            startRadius: 0,
            endRadius: 560
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Загрузка и ошибка

struct MapLoadingView: View {

    @Environment(\.dsMotion) private var motion
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: DS.Space.md) {
            Image(systemName: "globe.europe.africa")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(DS.Gradient.accent)
                .opacity(isPulsing ? 1 : 0.35)
                .scaleEffect(isPulsing ? 1 : 0.94)

            Text("Собираем мир")
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.inkSecondary)
        }
        .onAppear {
            guard motion.allowsAmbientMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Загружаем карту мира")
    }
}

struct MapErrorView: View {

    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: DS.Space.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(DS.Color.danger)

            Text("Карта не открылась")
                .font(DS.Font.headline)
                .foregroundStyle(DS.Color.ink)

            Text(message)
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.inkSecondary)
                .multilineTextAlignment(.center)

            PillButton("Попробовать снова", icon: "arrow.clockwise", kind: .secondary, action: retry)
        }
        .dsScreenPadding()
    }
}

// MARK: - Панели

/// Панели остаются тёмными на любой теме: стеклянные плашки и их текст
/// нарисованы под тёмный фон, и переворачивать их ради белой карты значило бы
/// переделывать половину интерфейса. Схему навязываем поддереву — цветовая
/// схема приложения при этом остаётся светлой, ради читаемого статус-бара.
extension View {
    /// Панель в схеме выбранного полотна.
    ///
    /// Раньше здесь было жёсткое «всегда тёмная»: на бумажной карте панели
    /// оставались чёрными, и выглядело это так, будто половину приложения
    /// забыли покрасить. Теперь схема идёт от полотна, а роли цветов
    /// переключаются сами — на местах не меняется ничего.
    func themedPanel(_ theme: MapTheme) -> some View {
        environment(\.colorScheme, theme.isLight ? .light : .dark)
    }
}
