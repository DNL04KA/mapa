import SwiftUI

/// Отрисовка мира.
///
/// Три решения определяют здесь всё:
///
/// 1. Пути стран лежат в единичном пространстве и никогда не пересчитываются.
///    На каждом кадре меняется только матрица `Canvas` — одна операция
///    вместо перебора десяти тысяч точек.
///
/// 2. `Animatable` на самой вьюхе. `Canvas` — не анимируемый примитив, и
///    `withAnimation` вокруг смены камеры сам по себе ничего бы не сгладил.
///    Отдавая зум, центр и прогресс заливки в `animatableData`, мы просим
///    SwiftUI интерполировать их покадрово.
///
/// 3. Границы рисуются последними, поверх заливок. Отмеченная страна остаётся
///    страной со своим контуром, а не сливается с соседями в одно пятно.
struct MapCanvas: View, Animatable {

    var camera: MapCamera
    /// 0…1 — насколько разлилась краска по только что отмеченной стране.
    var bloomProgress: CGFloat

    let geometry: WorldGeometry
    let overlay: MapOverlayState
    let stats: RenderStats
    let showsGraticule: Bool
    /// Оформление сцены: вода, суша, границы. Цвета стран тема не трогает —
    /// они приходят от флагов.
    let theme: MapTheme

    var animatableData: MapAnimatableState {
        get {
            MapAnimatableState(
                zoom: camera.zoom,
                centerX: camera.center.x,
                centerY: camera.center.y,
                bloom: bloomProgress
            )
        }
        set {
            camera.zoom = newValue.zoom
            camera.center = CGPoint(x: newValue.centerX, y: newValue.centerY)
            bloomProgress = newValue.bloom
        }
    }

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            let startedAt = CFAbsoluteTimeGetCurrent()

            let side = camera.worldSide(in: size)
            guard side > 0 else { return }

            // Океан на весь экран, а не квадратом: у карты нет краёв,
            // за границей суши просто продолжается вода.
            drawOcean(in: context, size: size)

            // Мир бесконечен по горизонтали, поэтому рисуем столько его копий,
            // сколько попадает на экран. Обычно одну, на обзоре мира — две.
            let base = camera.transform(in: size)
            for offset in camera.visibleWorldOffsets(in: size) {
                var world = context
                world.transform = base.translatedBy(x: offset, y: 0)

                drawOceanPattern(in: world, side: side)
                // Сетку рисуем, только если тема её просит: на белом листе
                // любая линия сверх контура — уже лишняя.
                if showsGraticule && theme.graticuleOpacity > 0 {
                    drawGraticule(in: world, side: side)
                }
                drawLandFill(in: world, side: side)
                drawMarked(in: world, side: side)
                drawBloom(in: world, side: side)
                drawLandBorders(in: world, side: side)
                drawRoute(in: world, side: side)
                drawHighlight(in: world, side: side)
            }

            stats.record((CFAbsoluteTimeGetCurrent() - startedAt) * 1000)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Основа

    /// Вода заливает весь экран. Раньше мир висел квадратом в пустоте —
    /// красиво, но сверху и снизу оставалась дыра, и карта переставала быть
    /// картой. Полярные шапки за пределами проекции — это тоже океан.
    private func drawOcean(in context: GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                theme.ocean,
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )
    }

    /// Материал воды: штриховка пером, миллиметровка или звёзды.
    ///
    /// Рисуется до суши, поэтому виден только на воде — как на настоящей карте,
    /// где штриховкой заполняли именно океан.
    private func drawOceanPattern(in context: GraphicsContext, side: CGFloat) {
        switch theme.oceanPattern {
        case .plain:
            return

        case .hatching:
            // Шаг постоянный на экране, а не в долях мира: иначе на приближении
            // штриховка разъезжается в редкие полосы.
            let step = max(13 / side, 0.004)
            var path = Path()
            var x = -1.0
            while x <= 1.0 {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + 1, y: 1))
                x += step
            }
            context.stroke(path, with: .color(theme.pattern), lineWidth: 0.7 / side)

        case .grid:
            let step = max(11 / side, 0.004)
            var path = Path()
            var value = 0.0
            while value <= 1.0 {
                path.move(to: CGPoint(x: value, y: 0))
                path.addLine(to: CGPoint(x: value, y: 1))
                path.move(to: CGPoint(x: 0, y: value))
                path.addLine(to: CGPoint(x: 1, y: value))
                value += step
            }
            context.stroke(path, with: .color(theme.pattern), lineWidth: 0.5 / side)

        case .stars:
            // Выше четырёхкратного приближения звёзды превращаются
            // в редкие крупные пятна — гасим их.
            scatterDots(in: context, side: side, sizeScale: 1, fadeAboveZoom: true)

        case .waves:
            context.stroke(
                sinePath(step: max(15 / side, 0.010), amplitude: 0.30, frequency: 26, drift: 0.9),
                with: .color(theme.pattern),
                lineWidth: 0.7 / side
            )

        case .dunes:
            context.stroke(
                sinePath(step: max(24 / side, 0.016), amplitude: 0.85, frequency: 8, drift: 0.5),
                with: .color(theme.pattern),
                lineWidth: 1.1 / side
            )

        case .contours:
            // Соседние линии заметно разъезжаются по фазе — так плоские
            // синусоиды начинают читаться как вложенные изолинии.
            context.stroke(
                sinePath(step: max(19 / side, 0.013), amplitude: 0.7, frequency: 13, drift: 2.1),
                with: .color(theme.pattern),
                lineWidth: 0.8 / side
            )

        case .ribbons:
            // Сияние — не линия, а завеса. Каждую ленту ведём тремя обводками:
            // широкой и почти прозрачной, средней и тонким ярким ядром.
            // Так у полосы появляются мягкие края, как у настоящего сияния.
            for index in 0..<4 {
                var ribbon = Path()
                let base = 0.14 + Double(index) * 0.21
                let samples = 48
                for step in 0...samples {
                    let x = CGFloat(step) / CGFloat(samples)
                    let wave = sin(Double(x) * 3.2 + Double(index) * 1.7) * 0.055
                    let y = CGFloat(base) + CGFloat(wave) + x * 0.08
                    if step == 0 { ribbon.move(to: CGPoint(x: x, y: y)) } else { ribbon.addLine(to: CGPoint(x: x, y: y)) }
                }

                for layer in 0..<3 {
                    let width = CGFloat([46, 22, 7][layer]) / side
                    let opacity = [0.30, 0.55, 1.0][layer]
                    context.stroke(
                        ribbon,
                        with: .color(theme.pattern.opacity(opacity)),
                        style: StrokeStyle(lineWidth: width, lineCap: .round)
                    )
                }
            }

        case .crosshatch:
            let step = max(11 / side, 0.005)
            var path = Path()
            var offset = -1.0
            while offset <= 1.0 {
                path.move(to: CGPoint(x: offset, y: 0))
                path.addLine(to: CGPoint(x: offset + 1, y: 1))
                path.move(to: CGPoint(x: offset, y: 1))
                path.addLine(to: CGPoint(x: offset + 1, y: 0))
                offset += step
            }
            context.stroke(path, with: .color(theme.pattern), lineWidth: 0.55 / side)

        case .scanlines:
            let step = max(4 / side, 0.0025)
            var path = Path()
            var y = 0.0
            while y <= 1.0 {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: 1, y: y))
                y += step
            }
            context.stroke(path, with: .color(theme.pattern), lineWidth: 1.2 / side)

        case .weave:
            let step = max(20 / side, 0.012)
            var path = Path()
            var offset = -1.0
            while offset <= 1.0 {
                path.move(to: CGPoint(x: offset, y: 0))
                path.addLine(to: CGPoint(x: offset + 1, y: 1))
                path.move(to: CGPoint(x: offset, y: 1))
                path.addLine(to: CGPoint(x: offset + 1, y: 0))
                offset += step
            }
            context.stroke(path, with: .color(theme.pattern), lineWidth: 1.6 / side)

        case .rain:
            // Два прохода со сдвигом: одной россыпи на дождь не хватает,
            // получаются редкие одинокие чёрточки.
            let length = 13 / side
            var path = Path()
            for drop in Self.scatter {
                for pass in 0..<2 {
                    let x = drop.x + CGFloat(pass) * 0.031
                    let y = drop.y + CGFloat(pass) * 0.017
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x - length * 0.4, y: y + length))
                }
            }
            context.stroke(path, with: .color(theme.pattern), lineWidth: 0.9 / side)

        case .frost:
            let length = 7 / side
            var path = Path()
            for shard in Self.scatter {
                let dx = cos(shard.angle) * length
                let dy = sin(shard.angle) * length
                path.move(to: CGPoint(x: shard.x - dx / 2, y: shard.y - dy / 2))
                path.addLine(to: CGPoint(x: shard.x + dx / 2, y: shard.y + dy / 2))
            }
            context.stroke(path, with: .color(theme.pattern), lineWidth: 0.7 / side)

        case .speckle:
            scatterDots(in: context, side: side, sizeScale: 2.2, fadeAboveZoom: false)

        case .embers:
            scatterDots(in: context, side: side, sizeScale: 1.6, fadeAboveZoom: false)

        case .bubbles:
            for bubble in Self.scatter {
                let radius = bubble.size * 3.4 / side
                let rect = CGRect(
                    x: bubble.x - radius, y: bubble.y - radius,
                    width: radius * 2, height: radius * 2
                )
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(theme.pattern.opacity(bubble.brightness)),
                    lineWidth: 0.7 / side
                )
            }
        }
    }

    /// Волнистые горизонтальные линии. `drift` разводит соседние линии по фазе:
    /// при нуле получается ровная рябь, при большом значении — изолинии.
    private func sinePath(step: CGFloat, amplitude: CGFloat, frequency: Double, drift: Double) -> Path {
        var path = Path()
        let samples = 44
        var y: CGFloat = -step
        var index = 0

        while y <= 1 + step {
            for sample in 0...samples {
                let x = CGFloat(sample) / CGFloat(samples)
                let wave = sin(Double(x) * frequency + Double(index) * drift)
                let point = CGPoint(x: x, y: y + step * amplitude * CGFloat(wave))
                if sample == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            y += step
            index += 1
        }
        return path
    }

    /// Россыпь точек: звёзды, лепестки, угли.
    private func scatterDots(in context: GraphicsContext, side: CGFloat, sizeScale: CGFloat, fadeAboveZoom: Bool) {
        // Выше четырёхкратного приближения точки превращаются в крупные пятна.
        let fade = fadeAboveZoom ? max(0, min(1, (4.5 - camera.zoom) / 2)) : 1
        guard fade > 0.01 else { return }

        for dot in Self.scatter {
            let radius = dot.size * sizeScale / side
            let rect = CGRect(x: dot.x - radius, y: dot.y - radius, width: radius * 2, height: radius * 2)
            context.fill(
                Path(ellipseIn: rect),
                with: .color(theme.pattern.opacity(dot.brightness * fade))
            )
        }
    }

    /// Россыпь считаем один раз и на всё приложение: положение не должно
    /// меняться от кадра к кадру, иначе узор начнёт мерцать целиком.
    private static let scatter: [(x: CGFloat, y: CGFloat, size: CGFloat, brightness: Double, angle: Double)] = {
        var seed: UInt64 = 0x2545F4914F6CDD1D
        func next() -> Double {
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            return Double(seed % 100_000) / 100_000
        }
        return (0..<560).map { _ in
            (x: CGFloat(next()),
             y: CGFloat(next()),
             size: CGFloat(0.4 + next() * 1.1),
             brightness: 0.25 + next() * 0.75,
             angle: next() * .pi * 2)
        }
    }()

    /// Сетка меридианов и параллелей.    /// Сетка меридианов и параллелей. В Меркаторе параллели ложатся
    /// неравномерно, поэтому каждую считаем через проекцию, а не делением отрезка.
    private func drawGraticule(in context: GraphicsContext, side: CGFloat) {
        var grid = Path()

        for longitude in stride(from: -150.0, through: 150.0, by: 30.0) {
            let x = MapProjection.unitPoint(longitude: longitude, latitude: 0).x
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: 1))
        }

        for latitude in stride(from: -60.0, through: 60.0, by: 30.0) {
            let y = MapProjection.unitPoint(longitude: 0, latitude: latitude).y
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: 1, y: y))
        }

        context.stroke(grid, with: .color(theme.graticule), lineWidth: 0.7 / side)

        // Экватор чуть заметнее остальных — точка отсчёта должна читаться.
        var equator = Path()
        let equatorY = MapProjection.unitPoint(longitude: 0, latitude: 0).y
        equator.move(to: CGPoint(x: 0, y: equatorY))
        equator.addLine(to: CGPoint(x: 1, y: equatorY))
        context.stroke(equator, with: .color(theme.graticule.opacity(0.9)), lineWidth: 0.8 / side)
    }

    private func drawLandFill(in context: GraphicsContext, side: CGFloat) {
        // Тень под сушей рисуется до заливки: край материка получает толщину,
        // и карта перестаёт быть плоской наклейкой.
        if theme.landShadow > 0 {
            var shadowed = context
            shadowed.addFilter(
                .shadow(
                    color: .black.opacity(theme.landShadow),
                    radius: 7 / side,
                    x: 0,
                    y: 2.5 / side
                )
            )
            shadowed.fill(geometry.landPath, with: .color(theme.landTop))
        }

        context.fill(
            geometry.landPath,
            with: .linearGradient(
                theme.land,
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: 1)
            )
        )
    }

    /// Толщину делим на масштаб: на экране линия всегда остаётся волосяной,
    /// как бы глубоко мы ни зумились.
    private func drawLandBorders(in context: GraphicsContext, side: CGFloat) {
        context.stroke(
            geometry.landPath,
            with: .color(theme.border),
            style: StrokeStyle(
                lineWidth: theme.borderWidth / side,
                lineJoin: .round,
                dash: (theme.borderDash ?? []).map { $0 / side }
            )
        )
    }

    // MARK: - Отметки

    /// Отмеченные страны с неоновым свечением.
    ///
    /// Свечение — не тень, а размытая копия самих стран, положенная под них.
    /// Тень умеет только один цвет на слой, поэтому вокруг зелёной Италии
    /// светил бы общий цвет статуса — и это читалось бы как грязь. Размытие
    /// сохраняет цвет каждой страны, а стоит ровно два прохода на всю карту.
    private func drawMarked(in context: GraphicsContext, side: CGFloat) {
        guard !overlay.marked.isEmpty else { return }

        // На светлой карте неона нет: свечение работает только по тёмному.
        if !theme.isLight {
            neon(radius: 26 / side, opacity: 0.55 * theme.markedGlow, in: context)
            neon(radius: 9 / side, opacity: 0.75 * theme.markedGlow, in: context)
        }

        for country in overlay.marked {
            paint(
                country.path,
                countryID: country.id,
                box: country.bounds,
                status: country.status,
                tint: country.tint,
                flagHue: country.flagHue,
                in: context
            )
        }

        for country in overlay.marked {
            context.stroke(
                country.path,
                with: .color(
                    theme.isLight
                        ? Color.white.opacity(0.85)
                        : DS.StatusColor.outline(country.status, tint: country.tint, flagHue: country.flagHue)
                            .opacity(country.status == .wishlist ? 0.5 : 0.9)
                ),
                lineWidth: 1.1 / side
            )
        }
    }

    private func neon(radius: CGFloat, opacity: Double, in context: GraphicsContext) {
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: radius))
            layer.opacity = opacity
            for country in overlay.marked {
                layer.fill(
                    country.path,
                    with: statusShading(
                        country.status,
                        countryID: country.id,
                        tint: country.tint,
                        flagHue: country.flagHue,
                        in: country.bounds
                    )
                )
            }
        }
    }

    /// Заливка не полностью непрозрачна: сквозь цвет просвечивает суша,
    /// поэтому страна остаётся землёй, а не наклейкой.
    private func paint(
        _ path: Path,
        countryID: String,
        box: CGRect,
        status: TravelStatus,
        tint: Double,
        flagHue: Double?,
        in context: GraphicsContext
    ) {
        let shading = statusShading(status, countryID: countryID, tint: tint, flagHue: flagHue, in: box)

        var fill = context
        // Насколько тише «хочу», решает сама палитра: у глубоких наборов
        // мечта при 0.74 спорила бы с прожитым, а у флагов наоборот пропала бы.
        fill.opacity = status == .wishlist ? theme.palette.wishOpacity : 0.90
        fill.fill(path, with: shading)

        guard !theme.isLight, !theme.flatFill else { return }
        var inner = context
        inner.blendMode = .plusLighter
        inner.opacity = status == .wishlist ? 0.07 : 0.15
        inner.fill(path, with: shading)
    }

    /// Заливка растекается из точки тапа — тот же жест, что и в хаптике.
    private func drawBloom(in context: GraphicsContext, side: CGFloat) {
        guard let bloom = overlay.bloom, bloomProgress > 0 else { return }

        let corners = [
            CGPoint(x: bloom.bounds.minX, y: bloom.bounds.minY),
            CGPoint(x: bloom.bounds.maxX, y: bloom.bounds.minY),
            CGPoint(x: bloom.bounds.minX, y: bloom.bounds.maxY),
            CGPoint(x: bloom.bounds.maxX, y: bloom.bounds.maxY)
        ]
        let fullRadius = corners.reduce(CGFloat(0)) { partial, corner in
            max(partial, hypot(corner.x - bloom.origin.x, corner.y - bloom.origin.y))
        }

        let radius = fullRadius * bloomProgress
        guard radius > 0 else { return }

        let circle = Path(
            ellipseIn: CGRect(
                x: bloom.origin.x - radius,
                y: bloom.origin.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        )

        context.drawLayer { layer in
            layer.clip(to: bloom.path)
            paint(
                circle,
                countryID: bloom.countryID,
                box: bloom.bounds,
                status: bloom.status,
                tint: bloom.tint,
                flagHue: bloom.flagHue,
                in: layer
            )

            // Светлая кромка на фронте волны — гаснет к концу заливки.
            layer.stroke(
                circle,
                with: .color(
                    DS.StatusColor.outline(bloom.status, tint: bloom.tint, flagHue: bloom.flagHue)
                        .opacity(0.75 * (1 - bloomProgress))
                ),
                lineWidth: 2.5 / side
            )
        }
    }

    /// Линия маршрута.
    ///
    /// Две обводки: широкая в цвет фона и тонкая в акцент. Так линия читается
    /// и над водой, и над цветной страной — без подложки она терялась бы
    /// ровно там, где маршрут интереснее всего.
    private func drawRoute(in context: GraphicsContext, side: CGFloat) {
        guard overlay.routeLine.count > 1 else { return }

        var path = Path()
        path.move(to: overlay.routeLine[0].point)
        for stop in overlay.routeLine.dropFirst() {
            path.addLine(to: stop.point)
        }

        context.stroke(
            path,
            with: .color((theme.isLight ? Color.white : DS.Palette.void).opacity(0.75)),
            style: StrokeStyle(lineWidth: 5.5 / side, lineCap: .round, lineJoin: .round)
        )
        context.stroke(
            path,
            with: .color(theme.accent),
            style: StrokeStyle(lineWidth: 2.2 / side, lineCap: .round, lineJoin: .round)
        )

        // Остановки. Без них линия читается как перелёт, а не как маршрут:
        // непонятно, где именно ты останавливаешься.
        // Пройденные закрашены, будущие полые — прогресс виден прямо на карте.
        let background = theme.isLight ? Color.white : DS.Palette.void
        for stop in overlay.routeLine {
            let radius = (stop.isVisited ? 4.6 : 3.8) / side
            let circle = Path(
                ellipseIn: CGRect(
                    x: stop.point.x - radius, y: stop.point.y - radius,
                    width: radius * 2, height: radius * 2
                )
            )
            context.fill(circle, with: .color(stop.isVisited ? theme.accent : background))
            context.stroke(circle, with: .color(theme.accent), lineWidth: 2.2 / side)
        }
    }

    /// Страна под открытым шитом. Пока выбираешь статус — видно, что именно
    /// ты отмечаешь, даже если это остров в пару пикселей.
    private func drawHighlight(in context: GraphicsContext, side: CGFloat) {
        guard let path = overlay.highlight else { return }

        context.drawLayer { layer in
            layer.addFilter(.shadow(color: theme.accent.opacity(0.85), radius: 14 / side))
            layer.stroke(path, with: .color(theme.mapInk.opacity(0.9)), lineWidth: 2 / side)
        }
    }

    /// Градиент статуса по габаритам конкретной страны: свет всегда падает
    /// на неё сверху, а не растягивается через весь мир.
    private func statusShading(
        _ status: TravelStatus,
        countryID: String,
        tint: Double,
        flagHue: Double?,
        in box: CGRect
    ) -> GraphicsContext.Shading {
        // Подобранная палитра плоская по определению: смысл в том, что тона
        // подобраны друг к другу, и градиент внутри страны тут только мешает.
        // Набор — плоский по определению: смысл в том, что тона подобраны
        // друг к другу, и градиент внутри страны тут только мешает.
        if case .set = theme.palette.mode {
            if status == .living {
                return .color(theme.palette.home)
            }
            // Пустой набор — это «Акцент»: цвет берётся у самого полотна.
            return .color(theme.palette.color(for: countryID) ?? theme.accent)
        }

        let colors = DS.StatusColor.colors(status, tint: tint, flagHue: flagHue, onLight: theme.isLight)

        // Плоская заливка — не «градиент из двух одинаковых цветов»,
        // а именно один цвет: так рендер не делает лишнюю работу.
        guard !theme.flatFill else { return .color(colors[0]) }

        return .linearGradient(
            SwiftUI.Gradient(colors: colors),
            startPoint: CGPoint(x: box.minX, y: box.minY),
            endPoint: CGPoint(x: box.maxX, y: box.maxY)
        )
    }
}
