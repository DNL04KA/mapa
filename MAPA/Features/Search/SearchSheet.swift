import SwiftUI

/// Поиск страны или города.
///
/// Поле наверху, а не внизу: клавиатура занимает низ экрана, и список
/// результатов должен расти от поля вниз, а не прятаться под неё.
@MainActor
struct SearchSheet: View {

    @Environment(\.dsMotion) private var motion

    let index: SearchIndex
    let accent: Color
    /// Название страны по коду — для подписи под городом.
    let countryName: (String) -> String
    let onPick: (SearchResult) -> Void
    let onDismiss: () -> Void

    @State private var query = ""
    @FocusState private var fieldFocused: Bool

    private var results: [SearchResult] { index.search(query) }

    private static let rowHeight: CGFloat = 54
    private static let maxListHeight: CGFloat = 378

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(DS.Color.scrim)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)
                .transition(.opacity)
                .accessibilityLabel("Закрыть поиск")
                .accessibilityAddTraits(.isButton)

            panel
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear { fieldFocused = true }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            field

            if query.count >= 2 {
                if results.isEmpty {
                    empty
                } else {
                    list
                }
            }
        }
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Color.panel.opacity(motion.reduceTransparency ? 1 : 0.95))
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .strokeBorder(DS.Color.border, lineWidth: 1)
                }
                .dsShadow(.high)
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.top, DS.Space.xs)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var field: some View {
        HStack(spacing: DS.Space.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: DS.Size.iconSm, weight: .semibold))
                .foregroundStyle(DS.Color.inkTertiary)

            TextField("Страна или город", text: $query)
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.ink)
                .focused($fieldFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit {
                    if let first = results.first { onPick(first) }
                }

            if !query.isEmpty {
                Button {
                    query = ""
                    fieldFocused = true
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
    }

    private var empty: some View {
        Text("Ничего не нашлось")
            .font(DS.Font.callout)
            .foregroundStyle(DS.Color.inkTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Space.md)
            .padding(.bottom, DS.Space.md)
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    Button {
                        Haptics.shared.selection()
                        onPick(result)
                    } label: {
                        row(result)
                    }
                    .buttonStyle(.plain)

                    if index < results.count - 1 {
                        Divider().overlay(DS.Color.hairline)
                            .padding(.leading, 54)
                    }
                }
            }
        }
        // Высота по содержимому, но не выше предела: `maxHeight` у
        // прокрутки занимает всё отведённое место, и под пятью строками
        // оставалась ладонь пустоты.
        .frame(height: min(Self.maxListHeight, CGFloat(results.count) * Self.rowHeight))
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }

    @ViewBuilder
    private func row(_ result: SearchResult) -> some View {
        HStack(spacing: DS.Space.sm) {
            icon(result)

            VStack(alignment: .leading, spacing: 1) {
                Text(result.title)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(1)

                Text(subtitle(result))
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.inkTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Space.md)
        .frame(height: Self.rowHeight)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func icon(_ result: SearchResult) -> some View {
        switch result {
        case .country:
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous)
                    .fill(accent.opacity(0.14))
                Image(systemName: "globe.europe.africa.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(accent)
            }
            .frame(width: 30, height: 30)

        case let .city(city):
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous)
                    .fill(accent.opacity(0.14))
                // У города с фотографией она и стоит: так в длинном списке
                // сразу видно, где есть на что смотреть.
                if let cover = CityFacts.cover(for: city.id) {
                    RemoteImage(url: cover.small)
                } else {
                    Image(systemName: city.isCapital ? "star.fill" : "mappin")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
            .frame(width: 30, height: 30)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous))
        }
    }

    private func subtitle(_ result: SearchResult) -> String {
        switch result {
        case let .country(country):
            return country.continent?.title ?? ""
        case let .city(city):
            let country = countryName(city.countryID)
            return city.isCapital
                ? [country, String(localized: "столица")].filter { !$0.isEmpty }.joined(separator: " · ")
                : country
        }
    }

}
