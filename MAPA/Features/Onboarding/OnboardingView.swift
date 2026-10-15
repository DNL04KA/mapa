import SwiftUI

/// Первый запуск.
///
/// До него приложение открывалось серым миром, нулём процентов и шестью
/// значками по краю: что тут делать, человек должен был догадаться сам.
///
/// Два шага и ни одним больше. Первый объясняет, зачем это всё, — одной
/// фразой, а не каруселью из пяти экранов, которую всё равно пролистывают.
/// Второй спрашивает город, где ты живёшь: карта сразу подъезжает туда,
/// а не висит над Атлантикой, и у дома появляется имя, а не «где-то в
/// стране». Оба шага можно пропустить — ничего не сломается.
@MainActor
struct OnboardingView: View {

    @Environment(\.dsMotion) private var motion

    let index: SearchIndex
    let accent: Color
    let countryName: (String) -> String
    /// Выбран город, где человек живёт.
    let onPickHome: (City) -> Void
    let onFinish: () -> Void

    @State private var step: Step = Self.firstStep
    @State private var query = Self.firstQuery
    @FocusState private var fieldFocused: Bool

    private enum Step { case hello, home }

    /// Шаг и запрос из переменных окружения — чтобы снять второй экран
    /// симулятором, которому нечем нажать «Дальше». Только отладка.
    private static var firstStep: Step {
        #if DEBUG
        ProcessInfo.processInfo.environment["MAPA_STEP"] == "home" ? .home : .hello
        #else
        .hello
        #endif
    }

    private static var firstQuery: String {
        #if DEBUG
        ProcessInfo.processInfo.environment["MAPA_QUERY"] ?? ""
        #else
        ""
        #endif
    }

    private static let rowHeight: CGFloat = 54
    private static let maxListHeight: CGFloat = 264

    /// Только города: вопрос задан про город, и страна в ответе на него
    /// не годится — дом нужен с точкой на карте.
    private var cities: [City] {
        index.search(query).compactMap {
            if case let .city(city) = $0 { return city }
            return nil
        }
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(DS.Color.scrim)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            card
                .padding(.horizontal, DS.Space.lg)
        }
        .transition(motion.transition(.opacity))
    }

    private var card: some View {
        VStack(spacing: DS.Space.lg) {
            switch step {
            case .hello: hello
            case .home:  home
            }
        }
        .padding(DS.Space.lg)
        .frame(maxWidth: 420)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(DS.Color.panel.opacity(motion.reduceTransparency ? 1 : 0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .strokeBorder(DS.Color.border, lineWidth: 1)
                }
                .dsShadow(.high)
        }
    }

    // MARK: - Зачем это всё

    private var hello: some View {
        VStack(spacing: DS.Space.md) {
            Image(systemName: "globe.europe.africa.fill")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(accent)
                .padding(.top, DS.Space.xs)

            VStack(spacing: DS.Space.xs) {
                Text("Закрась мир")
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.ink)

                Text("Отмечай страны, где был, собирай маршруты по городам и смотри, сколько мира уже твоё.")
                    .font(DS.Font.callout)
                    .foregroundStyle(DS.Color.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PillButton("Дальше", icon: "arrow.right", kind: .tinted(accent), fullWidth: true) {
                Haptics.shared.tap(.light)
                withAnimation(motion.animation(.smooth)) { step = .home }
                fieldFocused = true
            }

            skip
        }
    }

    // MARK: - Откуда ты

    private var home: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                Text("Где ты живёшь?")
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.ink)

                Text("Карта откроется на твоём городе, а он станет точкой отсчёта для маршрутов.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            field

            if query.count >= 2 {
                if cities.isEmpty {
                    Text("Ничего не нашлось")
                        .font(DS.Font.callout)
                        .foregroundStyle(DS.Color.inkTertiary)
                        .padding(.vertical, DS.Space.xs)
                } else {
                    list
                }
            }

            skip
        }
    }

    private var field: some View {
        HStack(spacing: DS.Space.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: DS.Size.iconSm, weight: .semibold))
                .foregroundStyle(DS.Color.inkTertiary)

            TextField("Город", text: $query)
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.ink)
                .focused($fieldFocused)
                .submitLabel(.done)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { if let first = cities.first { pick(first) } }
        }
        .padding(.horizontal, DS.Space.md)
        .frame(height: DS.Size.controlHeight)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Color.canvas.opacity(0.6))
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .strokeBorder(DS.Color.hairline, lineWidth: 1)
                }
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(cities.enumerated()), id: \.element.id) { offset, city in
                    Button {
                        pick(city)
                    } label: {
                        row(city)
                    }
                    .buttonStyle(.plain)

                    if offset < cities.count - 1 {
                        Divider().overlay(DS.Color.hairline).padding(.leading, 54)
                    }
                }
            }
        }
        // Высота по содержимому, но не выше предела: прокрутка занимает
        // всё отведённое место, и под двумя строками остаётся пустота.
        .frame(height: min(Self.maxListHeight, CGFloat(cities.count) * Self.rowHeight))
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }

    private func row(_ city: City) -> some View {
        HStack(spacing: DS.Space.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous)
                    .fill(accent.opacity(0.14))
                if let cover = CityFacts.cover(for: city.id) {
                    RemoteImage(url: cover.small)
                } else {
                    Image(systemName: "mappin")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
            .frame(width: 30, height: 30)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(city.displayName)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(1)

                Text(countryName(city.countryID))
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.inkTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Space.xs)
        .frame(height: Self.rowHeight)
        .contentShape(Rectangle())
    }

    private var skip: some View {
        Button {
            Haptics.shared.tap(.light)
            onFinish()
        } label: {
            Text(step == .hello ? "Пропустить" : "Потом")
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.inkTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: DS.Size.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pick(_ city: City) {
        Haptics.shared.selection()
        onPickHome(city)
        onFinish()
    }
}
