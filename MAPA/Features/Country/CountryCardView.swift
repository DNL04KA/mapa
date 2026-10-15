import SwiftUI

/// Карточка страны.
///
/// Не `.sheet` и не `NavigationStack`: карточка выезжает из самой страны
/// на карте — силуэт, который ты трогал пальцем, вырастает в обложку.
/// Системный переход разорвал бы эту связь.
@MainActor
struct CountryCardView: View {

    @Environment(\.dsMotion) private var motion

    let country: Country
    let theme: MapTheme
    let status: TravelStatus?
    let isHome: Bool
    let cities: [City]
    let onOpenCity: (City) -> Void
    let onTakeRoute: ([CountryRoutePlanner.Stop]) -> Void
    let onSelectStatus: (TravelStatus) -> Void
    let onClose: () -> Void

    @State private var dragOffset: CGFloat = 0

    private var facts: CountryFacts? { CountryFacts.facts(for: country.id) }
    private var routeStops: [CountryRoutePlanner.Stop] {
        CountryRoutePlanner.suggest(for: cities)
    }
    private var heroHeight: CGFloat { 320 }

    private var tint: Color {
        DS.StatusColor.colors(status ?? .visited, flagHue: country.flagHue)[0]
    }

    var body: some View {
        ZStack(alignment: .top) {
            background

            ScrollView {
                VStack(spacing: 0) {
                    hero
                    content
                }
            }
            .scrollIndicators(.hidden)
            .coordinateSpace(name: "card")

            // Прокрученный контент уходит под «остров» — без затемнения
            // он там просто теряется.
            MapTopScrim(height: 132)
                .ignoresSafeArea(edges: .top)

            closeButton
        }
        .ignoresSafeArea()
        .offset(y: dragOffset)
        .gesture(dismissDrag)
    }

    // MARK: - Фон

    private var background: some View {
        ZStack {
            // Не жёсткий чёрный, а роль: на бумажном полотне карточка
            // должна быть бумажной, иначе она выпадает из приложения.
            DS.Color.canvas

            // Цвет страны, разлитый по всему экрану, — карточка продолжает
            // ту заливку, которую ты видел на карте.
            RadialGradient(
                colors: [tint.opacity(theme.isLight ? 0.5 : 0.32), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 620
            )

            NoiseOverlay(opacity: theme.isLight ? 0.03 : 0.05)
        }
        .ignoresSafeArea()
    }

    // MARK: - Обложка

    private var hero: some View {
        GeometryReader { proxy in
            // Классический «резиновый» заголовок: при оттягивании вниз
            // обложка растягивается, а не отрывается от края.
            let offset = proxy.frame(in: .named("card")).minY
            let stretch = max(0, offset)
            let size = CGSize(width: proxy.size.width, height: heroHeight + stretch)

            Group {
                if let cover = heroPhoto {
                    photoHero(cover, size: size)
                } else {
                    // Фотографии нет — остаётся силуэт. Он честнее стока:
                    // это ровно та страна, которую ты трогал пальцем.
                    // Сверху отступ больше: силуэт занимает всю выделенную
                    // высоту, и у вытянутых стран вроде Доминики макушка
                    // уезжала под «остров» и строку состояния.
                    CountryHeroArt(country: country, status: status, accent: theme.accent)
                        .padding(.horizontal, DS.Space.xxl)
                        .padding(.top, DS.Space.xxl + DS.Space.sm)
                        .padding(.bottom, DS.Space.lg)
                        .frame(width: size.width, height: size.height)
                }
            }
            .offset(y: -stretch)
            // Параллакс: содержимое уезжает быстрее обложки.
            .opacity(1 - min(1, max(0, -offset) / 260))
        }
        .frame(height: heroHeight)
    }

    private var heroPhoto: Landmark? { CountryLandmarks.cover(for: country.id) }

    /// Обложка-фотография.
    ///
    /// Силуэт остаётся, но размером с печать в углу: он нужен как связь с
    /// картой, а не как картинка. У Ватикана и Сингапура контур — это
    /// шестиугольник во весь экран, и смотреть на него незачем, когда есть
    /// собор Святого Петра.
    ///
    /// Снимок не обрезается по нижнему краю, а растворяется в фоне карточки:
    /// жёсткая линия обреза делит экран пополам, и заголовок оказывается
    /// под ней отдельной страницей. Размер задаётся прямоугольнику, а
    /// подпись вешается поверх него — иначе фотография раздувает стопку
    /// и подпись уезжает за край экрана.
    private func photoHero(_ cover: Landmark, size: CGSize) -> some View {
        Rectangle()
            .fill(tint.opacity(0.16))
            .frame(width: size.width, height: size.height)
            .overlay { RemoteImage(url: cover.large ?? cover.small) }
            .clipped()
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.74),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .overlay(alignment: .bottomLeading) { heroCaption(cover) }
    }

    private func heroCaption(_ cover: Landmark) -> some View {
        HStack(alignment: .bottom, spacing: DS.Space.sm) {
            CountryHeroArt(country: country, status: status, accent: theme.accent)
                .frame(width: 54, height: 38)

            VStack(alignment: .leading, spacing: 1) {
                Text(cover.name)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(1)
                if let credit = cover.credit {
                    Text(credit)
                        .font(.system(size: 9))
                        .foregroundStyle(DS.Color.inkTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Space.screen)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Содержимое

    private var content: some View {
        VStack(alignment: .leading, spacing: DS.Space.xl) {
            title
            statusRow
            if let facts {
                tiles(facts)
            }
            if routeStops.count > 1 {
                CountryRouteSection(
                    stops: routeStops,
                    tint: tint,
                    onTake: { onTakeRoute(routeStops) },
                    onOpenCity: onOpenCity
                )
            }
            if !cities.isEmpty {
                cityList
            }
            // «Что посмотреть» есть почти у каждой страны: это данные.
            // Архитектура и советы — только там, где они написаны руками.
            if !stripLandmarks.isEmpty {
                landmarks
            }
            if let facts {
                architecture(facts)
            } else if stripLandmarks.isEmpty, heroPhoto == nil {
                missingFacts
            }
            community
        }
        .dsScreenPadding()
        .padding(.top, DS.Space.lg)
        .padding(.bottom, DS.Space.huge)
    }

    private var title: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            HStack(alignment: .center, spacing: DS.Space.xs) {
                Text(country.displayName)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)

                if isHome {
                    Image(systemName: "house.fill")
                        .font(.system(size: DS.Size.iconMd, weight: .semibold))
                        .foregroundStyle(tint)
                }
            }

            Text(subtitle)
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let continent = country.continent { parts.append(continent.title) }
        if country.areaKm2 > 0 {
            let area = Self.areaFormatter.string(from: NSNumber(value: country.areaKm2)) ?? ""
            // Единица площади переводится: на английском телефоне в подписи
            // к стране стояло «404 322 км²».
            parts.append(String(format: NSLocalizedString("%@ км²", comment: ""), area))
        }
        parts.append(country.name)
        return parts.joined(separator: " · ")
    }

    private var statusRow: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionHeader("Твоя отметка")
            HStack(spacing: DS.Space.xs) {
                ForEach(TravelStatus.allCases) { option in
                    StatusOptionCard(status: option, isSelected: status == option) {
                        onSelectStatus(option)
                    }
                }
            }
        }
    }

    private func tiles(_ facts: CountryFacts) -> some View {
        HStack(spacing: DS.Space.sm) {
            tile(value: facts.daysText, unit: "дней", caption: "Советуют заложить", icon: "calendar")
            tile(value: facts.budgetText, unit: "в день", caption: "Примерная оценка", icon: "creditcard")
        }
    }

    /// `LocalizedStringKey`, а не `String`: `Text` со строковой переменной
    /// перевод не ищет, и на английском телефоне в карточке страны стояло
    /// «дней» и «Советуют заложить» — при том, что перевод лежал рядом.
    private func tile(value: String, unit: LocalizedStringKey,
                      caption: LocalizedStringKey, icon: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Image(systemName: icon)
                .font(.system(size: DS.Size.iconSm, weight: .semibold))
                .foregroundStyle(tint)

            // На крупном шрифте «€90–160» и «в день» в одну строку не
            // помещаются, и цена превращалась в «€90…». Если не влезает —
            // единица уходит под число, а не обрезается.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    tileValue(value)
                    tileUnit(unit)
                }
                VStack(alignment: .leading, spacing: 0) {
                    tileValue(value)
                    tileUnit(unit)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            Text(caption)
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.inkTertiary)
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlass(radius: DS.Radius.md, shadow: .low)
        .accessibilityElement(children: .combine)
    }

    private func tileValue(_ value: String) -> some View {
        Text(value)
            .font(DS.Font.numeral)
            .foregroundStyle(DS.Color.ink)
    }

    private func tileUnit(_ unit: LocalizedStringKey) -> some View {
        Text(unit)
            .font(DS.Font.caption)
            .foregroundStyle(DS.Color.inkSecondary)
    }

    /// Города страны. Отсюда можно провалиться в город — карта подъедет,
    /// карточка закроется, а страна останется выбранной.
    private var cityList: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            // Показываем все, а не первые шесть: у России их шестнадцать,
            // и обрезать список ровно там, где начинается незнакомое, —
            // это прятать то, ради чего человек сюда и зашёл.
            SectionHeader("Города", subtitle: Plural.cities(cities.count))

            VStack(spacing: 0) {
                ForEach(Array(cities.enumerated()), id: \.element.id) { index, city in
                    Button {
                        onOpenCity(city)
                    } label: {
                        HStack(spacing: DS.Space.sm) {
                            cityThumb(city)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: DS.Space.xxs) {
                                    if city.isCapital {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundStyle(tint)
                                    }
                                    Text(city.displayName)
                                        .font(DS.Font.body)
                                        .foregroundStyle(DS.Color.ink)
                                        .lineLimit(1)
                                }

                                // Сразу видно, зачем сюда ехать, — не надо
                                // открывать каждый город по очереди.
                                if let places = CityFacts.summary(for: city.id, limit: 2) {
                                    Text(places)
                                        .font(DS.Font.micro)
                                        .foregroundStyle(DS.Color.inkTertiary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer(minLength: DS.Space.xs)

                            Text(Self.populationFormatter.string(from: NSNumber(value: city.population)) ?? "")
                                .font(DS.Font.micro)
                                .foregroundStyle(DS.Color.inkTertiary)
                                .monospacedDigit()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(DS.Color.inkTertiary)
                        }
                        .frame(height: 60)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .dsReveal(index)
                    .accessibilityLabel(city.isCapital ? "\(city.displayName), столица" : city.displayName)

                    if index < cities.count - 1 {
                        Divider().overlay(DS.Color.hairline)
                    }
                }
            }
            .padding(.horizontal, DS.Space.md)
            .dsGlass(radius: DS.Radius.md, shadow: .low)
        }
    }

    /// Квадратик с фотографией города. Если снимка нет — булавка, как раньше.
    @ViewBuilder
    private func cityThumb(_ city: City) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous)
                .fill(tint.opacity(0.12))

            if let cover = CityFacts.cover(for: city.id) {
                RemoteImage(url: cover.small)
            } else {
                // Всегда булавка: звезда у столицы и так стоит рядом с
                // названием, и в пустом квадратике она читалась как оценка.
                Image(systemName: "mappin")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Color.inkTertiary)
            }
        }
        .frame(width: 44, height: 44)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous))
    }

    private var countryLandmarks: [Landmark] { CountryLandmarks.all(for: country.id) }

    /// Лента «что посмотреть» без того места, что уже стоит на обложке:
    /// одна и та же фотография дважды на экране выглядит ошибкой загрузки.
    private var stripLandmarks: [Landmark] {
        guard let hero = heroPhoto else { return countryLandmarks }
        return countryLandmarks.filter { $0.id != hero.id }
    }

    /// Что посмотреть в стране — лентой с фотографиями.
    ///
    /// Список строк заменён на снимки намеренно: «Колизей, Помпеи, Венеция»
    /// читается как оглавление, а четыре фотографии — как причина поехать.
    private var landmarks: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionHeader("Что посмотреть")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: DS.Space.sm) {
                    ForEach(Array(stripLandmarks.enumerated()), id: \.element.id) { index, place in
                        VStack(alignment: .leading, spacing: 5) {
                            ZStack {
                                Rectangle().fill(tint.opacity(0.14))
                                RemoteImage(url: place.small)
                            }
                            .frame(width: 168, height: 112)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                    .strokeBorder(DS.Color.hairline, lineWidth: 1)
                            }

                            Text(place.name)
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Color.ink)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            if let credit = place.credit {
                                Text(credit)
                                    .font(.system(size: 9))
                                    .foregroundStyle(DS.Color.inkTertiary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(width: 168, alignment: .leading)
                        .dsReveal(index)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, DS.Space.screen)
            }
            .padding(.horizontal, -DS.Space.screen)
        }
    }

    private func architecture(_ facts: CountryFacts) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionHeader("Архитектура")
            Text(facts.architecture)
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Честная заглушка вместо правдоподобной выдумки.
    private var missingFacts: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Image(systemName: "text.badge.plus")
                .font(.system(size: DS.Size.iconLg, weight: .light))
                .foregroundStyle(DS.Color.inkTertiary)

            Text("Описания пока нет")
                .font(DS.Font.headline)
                .foregroundStyle(DS.Color.ink)

            Text("Мы не выдумываем достопримечательности. Про эту страну расскажут те, кто там был, — когда появятся маршруты сообщества.")
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlass(radius: DS.Radius.md, shadow: .low)
    }

    private var community: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionHeader("Фото сообщества")

            HStack(spacing: DS.Space.xs) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .fill(.white.opacity(0.05))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: DS.Size.iconMd, weight: .light))
                                .foregroundStyle(DS.Color.inkTertiary)
                        }
                }
            }

            Text("Появятся вместе с маршрутами")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.inkTertiary)
        }
    }

    // MARK: - Управление

    private var closeButton: some View {
        HStack {
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: DS.Size.iconSm, weight: .bold))
                    .foregroundStyle(DS.Color.ink)
                    .frame(width: DS.Size.hitTarget, height: DS.Size.hitTarget)
                    // Стекло, а не серый кружок: кнопка лежит на фотографии,
                    // и плотная плашка выглядит на ней заплаткой.
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay { Circle().strokeBorder(DS.Color.hairline, lineWidth: 1) }
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.top, 56)
        .accessibilityLabel("Закрыть карточку")
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { dragOffset = max(0, $0.translation.height) }
            .onEnded { value in
                if value.translation.height > 120 || value.predictedEndTranslation.height > 300 {
                    onClose()
                }
                withAnimation(motion.animation(.snap)) { dragOffset = 0 }
            }
    }

    private static let populationFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter
    }()

    private static let areaFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}
