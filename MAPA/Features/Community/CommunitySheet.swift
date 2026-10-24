import SwiftUI

/// Сообщество: лучшие маршруты.
///
/// Одна лента, а не две вкладки. Топ людей отсюда убран намеренно:
/// человек приходит сюда с вопросом «куда поехать», а не «за кем
/// следить», и список чужих имён на этот вопрос не отвечает. К автору
/// по-прежнему можно зайти — из его маршрута или по никнейму.
///
/// Порядок считает сервер по сглаженной оценке: один отзыв на пять
/// звёзд не поднимает маршрут выше того, у которого сорок отзывов и
/// четыре с половиной.
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

    @State private var handle = ""
    @State private var lookup: CommunityStore.Lookup?
    @State private var isSearching = false
    @FocusState private var handleFocused: Bool
    @State private var dragOffset: CGFloat = 0

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

            VStack(spacing: 2) {
                Text("Лучшие маршруты")
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.ink)
                Text("По оценкам тех, кто уже съездил")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkTertiary)
            }

            handleField

            ViewThatFits(in: .vertical) {
                routeList
                ScrollView { routeList }.scrollIndicators(.hidden)
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

    /// Поиск по никнейму: «зайти к человеку» — это ввести @имя, а не
    /// листать топ в надежде, что он там есть.
    private var handleField: some View {
        VStack(spacing: DS.Space.xxs) {
            // Собачка вплотную к полю: с разрядкой «@ nikita» выглядело
            // двумя словами, а никнейм — одно.
            HStack(spacing: 0) {
                Text(verbatim: "@")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.inkTertiary)

                TextField("никнейм", text: $handle)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.ink)
                    .focused($handleFocused)
                    .submitLabel(.go)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit { search() }
                    .onChange(of: handle) { _ in lookup = nil }

                if isSearching {
                    ProgressView()
                } else if !handle.isEmpty {
                    Button {
                        handle = ""
                        lookup = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: DS.Size.iconSm))
                            .foregroundStyle(DS.Color.inkTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Очистить")
                }
            }
            .padding(.horizontal, DS.Space.md)
            .frame(height: DS.Size.controlHeight)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Color.surfaceSunken.opacity(0.7))
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .strokeBorder(DS.Color.hairline, lineWidth: 1)
                    }
            }

            switch lookup {
            case let .found(author):
                Button { onOpenAuthor(author) } label: {
                    authorRow(author, place: 0)
                }
                .buttonStyle(.plain)

            case .notFound:
                Text("Никого с таким никнеймом")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

            case let .unavailable(reason):
                Text(reason)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

            case nil:
                EmptyView()
            }
        }
    }

    /// Открыть человека по никнейму из строки маршрута.
    private func open(handle: String) {
        Haptics.shared.tap(.light)
        Task {
            if case let .found(author) = await store.find(handle: handle) {
                await MainActor.run { onOpenAuthor(author) }
            }
        }
    }

    private func search() {
        let query = handle
        guard query.trimmingCharacters(in: .whitespaces).count >= 3 else {
            lookup = .notFound
            return
        }
        isSearching = true
        Task {
            let result = await store.find(handle: query)
            await MainActor.run {
                isSearching = false
                withAnimation(motion.animation(.snap)) { lookup = result }
            }
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
                        HStack(spacing: DS.Space.xxs) {
                            Text(routeSubtitle(route))
                                .font(DS.Font.micro)
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(1)

                            if let handle = route.authorHandle {
                                Button { open(handle: handle) } label: {
                                    DS.handle(handle, tint: .white)
                                        .font(DS.Font.micro)
                                        .lineLimit(1)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(.white.opacity(0.22)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    if let rating = route.rating {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.system(size: DS.Size.glyph, weight: .semibold))
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
                        .font(.system(size: DS.Size.glyphSm, weight: .bold))
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

                // Никнейм автора — в той же строке, что страна и отзывы.
                // Третьей строкой он делал карточку выше и перетягивал на
                // себя взгляд, хотя в списке лучших главное — маршрут.
                // Разрядка в 3 точки, а не отступ дизайн-системы: точка
                // между строками должна стоять так же, как точка внутри
                // «Япония · 28 отзывов», иначе она отрывается от строки.
                HStack(spacing: 3) {
                    Text(routeSubtitle(route))
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.inkTertiary)
                        .lineLimit(1)
                        .layoutPriority(1)

                    if let handle = route.authorHandle {
                        Text(verbatim: "·")
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.inkTertiary)

                        Button { open(handle: handle) } label: {
                            DS.handle(handle, tint: accent)
                                .font(DS.Font.micro)
                                .lineLimit(1)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
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
                    .font(.system(size: DS.Size.glyphSm, weight: .bold))
                    .foregroundStyle(DS.Color.inkOnAccent)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(medal(place)))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(author.name)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(1)
                (DS.handle(author.handle, tint: DS.Color.inkTertiary)
                    + Text(verbatim: " · " + Plural.routes(author.routesCount))
                        .foregroundColor(DS.Color.inkTertiary))
                    .font(DS.Font.micro)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let score = author.score {
                ratingBadge(score)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: DS.Size.glyph, weight: .bold))
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
        case 1: return DS.Color.gold
        case 2: return DS.Color.silver
        case 3: return DS.Color.bronze
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
                .font(.system(size: DS.Size.glyphSm, weight: .semibold))
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
