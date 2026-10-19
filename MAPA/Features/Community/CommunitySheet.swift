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
    let countryName: (String) -> String
    let onOpenAuthor: (PublicAuthor) -> Void
    let onDismiss: () -> Void

    @State private var tab: Tab = .routes
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
                VStack(spacing: DS.Space.xs) {
                    ForEach(Array(routes.enumerated()), id: \.element.id) { index, route in
                        routeRow(route, place: index + 1)
                    }
                }
            }
        }
    }

    private func routeRow(_ route: PublicRoute, place: Int) -> some View {
        HStack(spacing: DS.Space.sm) {
            placeBadge(place)

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
        .padding(DS.Space.sm)
        .dsGlass(radius: DS.Radius.md, shadow: .low)
        .accessibilityElement(children: .combine)
    }

    private func routeSubtitle(_ route: PublicRoute) -> String {
        var parts: [String] = []
        if let id = route.countryID {
            let name = countryName(id)
            if !name.isEmpty { parts.append(name) }
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
            placeBadge(place)

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
        .padding(DS.Space.sm)
        .dsGlass(radius: DS.Radius.md, shadow: .low)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func placeBadge(_ place: Int) -> some View {
        Text("\(place)")
            .font(DS.Font.micro)
            .foregroundStyle(place <= 3 ? DS.Color.inkOnAccent : DS.Color.inkTertiary)
            .frame(width: 26, height: 26)
            .background {
                Circle().fill(place <= 3 ? AnyShapeStyle(accent)
                                         : AnyShapeStyle(DS.Color.surfaceSunken))
            }
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
