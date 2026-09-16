import SwiftUI

/// Экран карты мира.
struct WorldMapView: View {

    @StateObject private var model = WorldMapViewModel()
    @Environment(\.dsMotion) private var motion

    @State private var showsDebug = false
    @State private var statsExpanded = false
    @State private var showsThemes = false
    /// Платная тема, которую сейчас примеряют. Живёт только пока открыта панель.
    @State private var previewTheme: MapTheme?
    /// Страна, чья карточка открыта.
    @State private var cardCountry: Country?
    @State private var showsRoutes = false
    @State private var routeExpanded = false
    @Environment(\.scenePhase) private var scenePhase

    let theme: MapTheme
    let onSelectTheme: (MapTheme) -> Void
    /// Витрина дизайн-системы осталась рабочим инструментом
    /// и открывается из панели оформления.
    let onOpenGallery: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                content(in: proxy.size)
                overlays
                statusSheet
                citySheet
                routePanel
                routesSheet
                themeSheet
                countryCard
            }
            .environment(\.mapTheme, activeTheme)
            .onAppear { model.updateViewport(proxy.size) }
            .onChange(of: proxy.size) { model.updateViewport($0) }
            .onChange(of: scenePhase) { phase in
                // Уходим в фон — дожидаемся записи, чтобы отметка не потерялась.
                guard phase != .active else { return }
                Task { await model.flushPendingSaves() }
            }
        }
        .task { await model.load() }
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
            .darkPanel()
            .zIndex(2)
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
            .darkPanel()
            .zIndex(2)
        }
    }

    @ViewBuilder
    private var routesSheet: some View {
        if showsRoutes {
            RoutesSheet(
                routes: model.routes,
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
                onDismiss: { withAnimation(motion.animation(.smooth)) { showsRoutes = false } }
            )
            .darkPanel()
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
                onSelectStatus: { model.setStatusFromCard($0, for: country, reduceMotion: motion.reduceMotion) },
                onClose: { closeCard() }
            )
            .transition(
                motion.transition(
                    .scale(scale: 0.12, anchor: cardAnchor).combined(with: .opacity)
                )
            )
            .darkPanel()
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

    @ViewBuilder
    private var themeSheet: some View {
        if showsThemes {
            ThemePicker(
                current: theme,
                preview: previewTheme,
                onSelect: { onSelectTheme($0) },
                onPreview: { candidate in
                    withAnimation(motion.animation(.smooth)) { previewTheme = candidate }
                },
                onDismiss: { closeThemes() },
                onOpenGallery: {
                    closeThemes()
                    onOpenGallery()
                }
            )
            .darkPanel()
            .zIndex(3)
        }
    }

    /// Тема, которой карта нарисована прямо сейчас: примеряемая имеет
    /// приоритет над выбранной, но нигде не сохраняется.
    private var activeTheme: MapTheme { previewTheme ?? theme }

    private func closeThemes() {
        withAnimation(motion.animation(.smooth)) {
            showsThemes = false
            previewTheme = nil
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
            .darkPanel()
            .zIndex(2)
        }
    }

    // MARK: - Поверх карты

    private var overlays: some View {
        ZStack {
            MapVignette()

            VStack(spacing: 0) {
                MapTopScrim(height: statsExpanded ? 430 : 210)
                Spacer(minLength: 0)
            }
            .ignoresSafeArea(edges: .top)

            VStack(spacing: DS.Space.sm) {
                if model.state == .ready {
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
                    cornerControls
                    Spacer(minLength: 0)
                    zoomControls
                }
            }
            .padding(DS.Space.md)
        }
    }

    /// Служебные кнопки ушли вниз слева: верх экрана теперь занимает статистика.
    private var cornerControls: some View {
        HStack(spacing: DS.Space.xs) {
            MapControlButton(
                icon: model.locationAccess == .denied ? "location.slash" : "location.fill",
                isActive: model.currentCoordinate != nil,
                tint: activeTheme.accent
            ) {
                model.locateMe()
            }
            .accessibilityLabel("Показать, где я")

            MapControlButton(icon: "speedometer", isActive: showsDebug) {
                withAnimation(motion.animation(.smooth)) { showsDebug.toggle() }
            }
            .accessibilityLabel("Панель замеров")

            MapControlButton(icon: "point.topleft.down.curvedto.point.bottomright.up",
                             isActive: model.editingRoute != nil,
                             tint: activeTheme.accent) {
                withAnimation(motion.animation(.smooth)) { showsRoutes = true }
            }
            .accessibilityLabel("Маршруты")

            MapControlButton(icon: "paintpalette") {
                withAnimation(motion.animation(.smooth)) { showsThemes = true }
            }
            .accessibilityLabel("Оформление карты")
        }
    }

    /// Кнопки без подложек: на карте во весь экран любая плашка вырезает
    /// из неё кусок. Читаемость держит тень под самой иконкой.
    private var zoomControls: some View {
        VStack(spacing: DS.Space.xxs) {
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
    func darkPanel() -> some View {
        environment(\.colorScheme, .dark)
    }
}
