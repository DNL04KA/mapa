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

            CountryHeroArt(country: country, status: status, accent: theme.accent)
                .padding(.horizontal, DS.Space.xxl)
                .padding(.vertical, DS.Space.xl)
                .frame(width: proxy.size.width, height: heroHeight + stretch)
                .offset(y: -stretch)
                // Параллакс: содержимое уезжает быстрее обложки.
                .opacity(1 - min(1, max(0, -offset) / 260))
        }
        .frame(height: heroHeight)
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
            if !countryLandmarks.isEmpty {
                landmarks
            }
            if let facts {
                architecture(facts)
            } else if countryLandmarks.isEmpty {
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
                    .font(DS.Font.titleHero)
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
            parts.append("\(Self.areaFormatter.string(from: NSNumber(value: country.areaKm2)) ?? "") км²")
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

    private func tile(value: String, unit: String, caption: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Image(systemName: icon)
                .font(.system(size: DS.Size.iconSm, weight: .semibold))
                .foregroundStyle(tint)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(DS.Font.numeral)
                    .foregroundStyle(DS.Color.ink)
                Text(unit)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkSecondary)
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
                                            .font(.system(size: DS.Size.glyphSm, weight: .semibold))
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
                                .font(.system(size: DS.Size.glyphMd, weight: .bold))
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
                Image(systemName: city.isCapital ? "star.fill" : "mappin")
                    .font(.system(size: DS.Size.glyphMd, weight: .semibold))
                    .foregroundStyle(city.isCapital ? tint : DS.Color.inkTertiary)
            }
        }
        .frame(width: 44, height: 44)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous))
    }

    private var countryLandmarks: [Landmark] { CountryLandmarks.all(for: country.id) }

    /// Что посмотреть в стране — лентой с фотографиями.
    ///
    /// Список строк заменён на снимки намеренно: «Колизей, Помпеи, Венеция»
    /// читается как оглавление, а четыре фотографии — как причина поехать.
    private var landmarks: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionHeader("Что посмотреть")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: DS.Space.sm) {
                    ForEach(Array(countryLandmarks.enumerated()), id: \.element.id) { index, place in
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
                                    .font(DS.Font.nano)
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
                    .background(Circle().fill(.black.opacity(0.35)))
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
