import SwiftUI

/// Сообщество: лучшие маршруты и люди, которые их собрали.
///
/// Две вкладки, потому что это два разных вопроса. «Маршруты» отвечают
/// «куда поехать», «Люди» — «за кем следить». Порядок в обоих считает
/// сервер по сглаженной оценке: один отзыв на пять звёзд не поднимает
/// маршрут выше того, у которого сорок отзывов и четыре с половиной.
@MainActor
struct CommunitySheet: View {

    @Environment(\.dsMotion) private var motion
    @StateObject private var store = CommunityStore()

    let accent: Color
    /// Страна маршрута: из неё берутся и название, и цвет флага, и
    /// фотография — всё своё, местное, ничего не выдумано.
    let country: (String) -> Country?
    let onOpenAuthor: (PublicAuthor) -> Void
    let onDismiss: () -> Void

    @State private var tab: Tab = Self.firstTab

    /// Вкладка из переменной окружения — чтобы снять «Людей» симулятором,
    /// которому нечем переключить. Только отладка.
    private static var firstTab: Tab {
        #if DEBUG
        ProcessInfo.processInfo.environment["MAPA_TAB"] == "people" ? .people : .routes
        #else
        .routes
        #endif
    }
    @State private var dragOffset: CGFloat = 0

    private enum Tab: String, CaseIterable, Identifiable {
        case routes = "Маршруты"
        case people = "Люди"
        var id: String { rawValue }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            scrim
            VStack(spacing: 0) {
                Spacer(minLength: 96)
                panel
            }
        }
        .ignoresSafeArea()
        .task { await store.load() }
    }

    private var scrim: some View {
        Rectangle()
            .fill(DS.Color.scrim)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .transition(.opacity)
            .accessibilityLabel("Закрыть сообщество")
            .accessibilityAddTraits(.isButton)
    }

    private var panel: some View {
        VStack(spacing: DS.Space.md) {
            Capsule()
                .fill(DS.Color.borderStrong)
                .frame(width: 38, height: 4)

            Text("Сообщество")
                .font(DS.Font.title)
                .foregroundStyle(DS.Color.ink)

            tabs

            ViewThatFits(in: .vertical) {
                list
                ScrollView { list }.scrollIndicators(.hidden)
            }
        }
        .padding(.horizontal, DS.Space.screen)
        .padding(.top, DS.Space.sm)
        .padding(.bottom, DS.Space.xl + DS.Space.lg)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedTopShape(radius: DS.Radius.xl)
                .fill(DS.Color.panel)
                .overlay {
                    UnevenRoundedTopShape(radius: DS.Radius.xl)
                        .stroke(DS.Gradient.glassBorder(0.8), lineWidth: 1)
                }
                .dsShadow(.high)
                .ignoresSafeArea(edges: .bottom)
        }
        .offset(y: dragOffset)
        .gesture(dismissDrag)
        .transition(.move(edge: .bottom))
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { item in
                let isOn = tab == item
                Button {
                    Haptics.shared.selection()
                    withAnimation(motion.animation(.snap)) { tab = item }
                } label: {
                    Text(LocalizedStringKey(item.rawValue))
                        .font(DS.Font.callout)
                        .foregroundStyle(isOn ? DS.Color.inkOnAccent : DS.Color.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 34)
                        .background { if isOn { Capsule().fill(DS.Color.ink) } }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(3)
        .background(Capsule().fill(DS.Color.surfaceSunken.opacity(0.7)))
    }

    @ViewBuilder
    private var list: some View {
        switch tab {
        case .routes: routeList
        case .people: authorList
        }
    }

    @ViewBuilder
    private var routeList: some View {
        switch store.routes {
        case .loading:
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, DS.Space.xl)
        case .notConfigured:
            notConfigured
        case let .failed(reason):
            failure(reason)
        case let .loaded(routes):
            if routes.isEmpty {
                empty("Маршрутов пока нет",
                      "Как только кто-нибудь опубликует свой — он появится здесь.")
            } else {
                VStack(spacing: DS.Space.sm) {
                    // Первый — обложкой во всю ширину. Это и есть топ: он
                    // должен выглядеть как место, куда хочется, а не как
                    // первая строка таблицы.
                    if let best = routes.first {
                        leader(best)
                    }
                    ForEach(Array(routes.dropFirst().enumerated()), id: \.element.id) { index, route in
                        routeRow(route, place: index + 2)
                    }
                }
            }
        }
    }

    private func leader(_ route: PublicRoute) -> some View {
        Rectangle()
            .fill(tint(route).opacity(0.18))
            .frame(height: 150)
            .overlay { cover(route, large: true) }
            .clipped()
            .overlay(alignment: .bottom) {
                // Затемнение выше и плотнее, чем кажется нужным: название
                // ложится на небо и камень, и на светлом снимке белым по
                // белому его не прочесть.
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: DS.Palette.void.opacity(0.55), location: 0.45),
                        .init(color: DS.Palette.void.opacity(0.92), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 112)
            }
            .overlay(alignment: .topLeading) {
                Text("№1 по оценкам")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.inkOnAccent)
                    .padding(.horizontal, DS.Space.xs)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(accent))
                    .padding(DS.Space.sm)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: DS.Space.xs) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(route.title)
                            .font(DS.Font.headline)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(routeSubtitle(route))
                            .font(DS.Font.micro)
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if let rating = route.rating {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text(String(format: "%.1f", rating))
                                .font(DS.Font.subhead)
                                .monospacedDigit()
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Space.xs)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.18)))
                    }
                }
                .padding(DS.Space.sm)
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(DS.Color.hairline, lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
    }

    private func routeRow(_ route: PublicRoute, place: Int) -> some View {
        HStack(spacing: DS.Space.sm) {
            // Фотография страны вместо серого кружка с цифрой: список без
            // картинок читается как список задач, а не как «куда поехать».
            Rectangle()
                .fill(tint(route).opacity(0.18))
                .frame(width: 56, height: 56)
                .overlay { cover(route, large: false) }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous))
                .overlay(alignment: .topLeading) {
                    Text("\(place)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DS.Color.inkOnAccent)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(accent))
                        .padding(3)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(route.title)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(1)

                Text(routeSubtitle(route))
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.inkTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let rating = route.rating {
                ratingBadge(rating)
            }
        }
        .padding(DS.Space.xs)
        .dsGlass(radius: DS.Radius.md, shadow: .low)
        .accessibilityElement(children: .combine)
    }

    /// Цвет флага страны маршрута — им подсвечивается пустая рамка, пока
    /// фотография летит из сети.
    private func tint(_ route: PublicRoute) -> Color {
        guard let hue = route.countryID.flatMap(country)?.flagHue else { return accent }
        return Color(hue: hue, saturation: 0.7, brightness: 0.95)
    }

    @ViewBuilder
    private func cover(_ route: PublicRoute, large: Bool) -> some View {
        if let id = route.countryID, let photo = CountryLandmarks.cover(for: id) {
            RemoteImage(url: large ? (photo.large ?? photo.small) : photo.small)
        }
    }

    private func routeSubtitle(_ route: PublicRoute) -> String {
        var parts: [String] = []
        if let id = route.countryID, let name = country(id)?.displayName {
            parts.append(name)
        }
        parts.append(Plural.reviews(route.reviewsCount))
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var authorList: some View {
        switch store.authors {
        case .loading:
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, DS.Space.xl)
        case .notConfigured:
            notConfigured
        case let .failed(reason):
            failure(reason)
        case let .loaded(authors):
            if authors.isEmpty {
                empty("Людей пока нет",
                      "Здесь будут те, чьи маршруты оценили выше всего.")
            } else {
                VStack(spacing: DS.Space.xs) {
                    ForEach(Array(authors.enumerated()), id: \.element.id) { index, author in
                        Button {
                            onOpenAuthor(author)
                        } label: {
                            authorRow(author, place: index + 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func authorRow(_ author: PublicAuthor, place: Int) -> some View {
        HStack(spacing: DS.Space.sm) {
            // Кружок с буквами в цвете места, а не серый: страница
            // человека начинается с лица, и когда лица нет, его заменяет
            // хотя бы цвет.
            ZStack {
                Circle().fill(medal(place).opacity(0.22))
                Circle().strokeBorder(medal(place).opacity(0.55), lineWidth: 2)
                Text(initials(author.name))
                    .font(DS.Font.subhead)
                    .foregroundStyle(medal(place))
            }
            .frame(width: 48, height: 48)
            .overlay(alignment: .bottomTrailing) {
                Text("\(place)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(DS.Color.inkOnAccent)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(medal(place)))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(author.name)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(1)
                Text("@" + author.handle + " · " + Plural.routes(author.routesCount))
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.inkTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let score = author.score {
                ratingBadge(score)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DS.Color.inkTertiary)
        }
        .padding(DS.Space.xs)
        .dsGlass(radius: DS.Radius.md, shadow: .low)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Золото, серебро, бронза — и акцент для всех остальных. Топ должен
    /// читаться с одного взгляда, а не вычитываться по номерам.
    private func medal(_ place: Int) -> Color {
        switch place {
        case 1: return Color(hex: 0xE8C45F)
        case 2: return Color(hex: 0xBFC7D4)
        case 3: return Color(hex: 0xCE8E5A)
        default: return accent
        }
    }

    private func initials(_ name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    private func ratingBadge(_ value: Double) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(String(format: "%.1f", value))
                .font(DS.Font.caption)
                .monospacedDigit()
        }
        .foregroundStyle(accent)
    }

    /// Сервера нет. Говорим это прямо, а не «ничего не нашлось».
    private var notConfigured: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Image(systemName: "person.2")
                .font(.system(size: DS.Size.iconLg, weight: .light))
                .foregroundStyle(DS.Color.inkTertiary)

            Text("Сообщество ещё не подключено")
                .font(DS.Font.subhead)
                .foregroundStyle(DS.Color.ink)

            Text("Чужие маршруты и страницы людей живут на сервере — приложение к нему пока не подключено. Выдуманных авторов здесь нет и не будет: по их маршрутам нельзя поехать, а по оценкам нельзя выбрать.")
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlass(radius: DS.Radius.md, shadow: .low)
    }

    private func failure(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Text("Не удалось загрузить")
                .font(DS.Font.subhead)
                .foregroundStyle(DS.Color.ink)
            Text(reason)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlass(radius: DS.Radius.md, shadow: .low)
    }

    private func empty(_ title: LocalizedStringKey, _ text: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Text(title)
                .font(DS.Font.subhead)
                .foregroundStyle(DS.Color.ink)
            Text(text)
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlass(radius: DS.Radius.md, shadow: .low)
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { dragOffset = max(0, $0.translation.height) }
            .onEnded { value in
                if value.translation.height > 120 { onDismiss() }
                withAnimation(motion.animation(.snap)) { dragOffset = 0 }
            }
    }
}
