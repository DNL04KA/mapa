import SwiftUI

/// Страница человека: кто он и какие маршруты собрал.
///
/// Открывается из топа и сама по себе — это и есть «отдельная страница
/// людей». Ничего, кроме того, что человек опубликовал сам: оценки, число
/// отзывов и сохранений считает сервер, приложение их только показывает.
@MainActor
struct PersonSheet: View {

    @Environment(\.dsMotion) private var motion

    let author: PublicAuthor
    let accent: Color
    let countryName: (String) -> String
    let onDismiss: () -> Void

    @State private var routes: CommunityStore.State<PublicRoute> = .loading
    @State private var dragOffset: CGFloat = 0

    @StateObject private var store = CommunityStore()

    var body: some View {
        ZStack(alignment: .bottom) {
            scrim
            VStack(spacing: 0) {
                Spacer(minLength: 96)
                panel
            }
        }
        .ignoresSafeArea()
        .task { routes = await store.routes(by: author) }
    }

    private var scrim: some View {
        Rectangle()
            .fill(DS.Color.scrim)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .transition(.opacity)
            .accessibilityLabel("Закрыть страницу")
            .accessibilityAddTraits(.isButton)
    }

    private var panel: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }.scrollIndicators(.hidden)
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

    private var content: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            Capsule()
                .fill(DS.Color.borderStrong)
                .frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)

            header
            numbers

            if let bio = author.bio, !bio.isEmpty {
                Text(bio)
                    .font(DS.Font.callout)
                    .foregroundStyle(DS.Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            routeList
        }
    }

    private var header: some View {
        HStack(spacing: DS.Space.md) {
            // Аватарка приходит с сервера отдельным файлом; пока её нет,
            // показываем ту же заглушку, что и у себя, а не чужое лицо.
            ZStack {
                Circle().fill(accent.opacity(0.16))
                Text(initials)
                    .font(DS.Font.numeral)
                    .foregroundStyle(accent)
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 2) {
                Text(author.name)
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("@" + author.handle)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkTertiary)
            }

            Spacer(minLength: 0)
        }
    }

    private var initials: String {
        let letters = author.name.split(separator: " ").prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    private var numbers: some View {
        DS.Reflow(spacing: DS.Space.xs) {
            tile(Plural.routes(author.routesCount), "опубликовано")
            tile(author.score.map { String(format: "%.1f", $0) } ?? "—", "оценка")
            tile("\(author.savesCount)", "сохранили")
        }
    }

    private func tile(_ value: String, _ caption: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DS.Font.subhead)
                .foregroundStyle(DS.Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Space.sm)
        .dsGlass(radius: DS.Radius.md, shadow: .low)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var routeList: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            SectionHeader("Маршруты")

            switch routes {
            case .loading:
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, DS.Space.lg)

            case .notConfigured, .failed:
                Text("Не удалось загрузить маршруты")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkTertiary)

            case let .loaded(list):
                ForEach(list) { route in
                    HStack(spacing: DS.Space.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(route.title)
                                .font(DS.Font.body)
                                .foregroundStyle(DS.Color.ink)
                                .lineLimit(1)
                            Text(subtitle(route))
                                .font(DS.Font.micro)
                                .foregroundStyle(DS.Color.inkTertiary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if let rating = route.rating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(String(format: "%.1f", rating))
                                    .font(DS.Font.caption)
                                    .monospacedDigit()
                            }
                            .foregroundStyle(accent)
                        }
                    }
                    .padding(DS.Space.sm)
                    .dsGlass(radius: DS.Radius.md, shadow: .low)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func subtitle(_ route: PublicRoute) -> String {
        var parts: [String] = []
        if let id = route.countryID {
            let name = countryName(id)
            if !name.isEmpty { parts.append(name) }
        }
        parts.append(Plural.reviews(route.reviewsCount))
        return parts.joined(separator: " · ")
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
