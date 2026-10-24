import SwiftUI

/// Отметить страны списком.
///
/// Карта — хороший способ смотреть на отметки и плохой способ их ставить:
/// Нидерланды на весь мир размером в ноготь, а Сингапура там почти нет.
/// Человек, который был в двадцати странах, бросал заполнение на пятой, и
/// всё остальное в приложении — процент, маршруты, карточка для соцсетей —
/// оставалось пустым.
///
/// Поэтому здесь список: континент, страны по алфавиту, поиск сверху.
/// Отметка — в одно касание по строке, «хочу» — отдельной кнопкой справа.
/// «Живу» сюда не попало намеренно: страна проживания одна, её ставит дом,
/// и третья кнопка в каждой строке мешала бы остальным двумстам.
@MainActor
struct MarksSheet: View {

    @Environment(\.dsMotion) private var motion

    let countries: [Country]
    let log: TravelLog
    let accent: Color
    let onMark: (TravelStatus?, Country) -> Void
    let onDismiss: () -> Void

    @State private var query = Self.firstQuery
    @State private var dragOffset: CGFloat = 0
    @FocusState private var fieldFocused: Bool

    /// Запрос из переменной окружения — чтобы снять экран симулятором,
    /// которому нечем печатать. Только отладка.
    private static var firstQuery: String {
        #if DEBUG
        ProcessInfo.processInfo.environment["MAPA_MARKS"] ?? ""
        #else
        ""
        #endif
    }

    /// Где человек был — вместе со страной, где он живёт.
    private var visitedCount: Int {
        log.countryIDs(with: .visited).count + log.countryIDs(with: .living).count
    }

    private var sections: [CountryPicker.Section] {
        CountryPicker.sections(countries, query: query)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            scrim
            VStack(spacing: 0) {
                Spacer(minLength: 48)
                panel
            }
        }
        .ignoresSafeArea()
    }

    private var scrim: some View {
        Rectangle()
            .fill(DS.Color.scrim)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .transition(.opacity)
            .accessibilityLabel("Закрыть список стран")
            .accessibilityAddTraits(.isButton)
    }

    private var panel: some View {
        VStack(spacing: DS.Space.sm) {
            Capsule()
                .fill(DS.Color.borderStrong)
                .frame(width: 38, height: 4)

            header
            field
            legend
            list
            doneButton
        }
        .padding(.horizontal, DS.Space.screen)
        .padding(.top, DS.Space.sm)
        .padding(.bottom, DS.Space.lg)
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

    private var header: some View {
        VStack(spacing: 2) {
            Text("Где ты был")
                .font(DS.Font.title)
                .foregroundStyle(DS.Color.ink)

            // Считаем только «был»: заголовок спрашивает именно про это,
            // и число под ним должно отвечать на тот же вопрос, а не на
            // «сколько стран ты вообще тронул».
            Text(Plural.countries(visitedCount))
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.inkTertiary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private var field: some View {
        HStack(spacing: DS.Space.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: DS.Size.iconSm, weight: .semibold))
                .foregroundStyle(DS.Color.inkTertiary)

            TextField("Найти страну", text: $query)
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.ink)
                .focused($fieldFocused)
                .submitLabel(.done)
                .autocorrectionDisabled()

            if !query.isEmpty {
                Button {
                    query = ""
                    fieldFocused = false
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
    }

    /// Одна строка объяснения вместо догадок: что делает кружок справа.
    private var legend: some View {
        HStack(spacing: DS.Space.xxs) {
            Image(systemName: "checkmark")
                .font(.system(size: DS.Size.glyphSm, weight: .bold))
                .foregroundStyle(DS.StatusColor.glow(.visited))
            Text("был")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.inkTertiary)

            Text(verbatim: "·")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.inkTertiary)

            Image(systemName: "sparkles")
                .font(.system(size: DS.Size.glyphSm, weight: .semibold))
                .foregroundStyle(DS.StatusColor.glow(.wishlist))
            Text("хочу")
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.inkTertiary)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var list: some View {
        if sections.isEmpty {
            // Пусто — это ответ, а не поломка: такой страны у нас нет.
            Text("Такой страны не нашлось")
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.inkTertiary)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DS.Space.xs, pinnedViews: [.sectionHeaders]) {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.countries) { country in
                                row(country)
                            }
                        } header: {
                            sectionHeader(section)
                        }
                    }
                }
                .padding(.bottom, DS.Space.sm)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .frame(maxHeight: 460)
        }
    }

    private func sectionHeader(_ section: CountryPicker.Section) -> some View {
        HStack {
            Text(section.continent.title)
                .dsOverline()
            Spacer(minLength: DS.Space.xs)
            let marked = CountryPicker.marked(section, in: log)
            if marked > 0 {
                Text(verbatim: "\(marked) / \(section.countries.count)")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.inkTertiary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, DS.Space.xxs)
        .background(DS.Color.panel)
    }

    // MARK: - Строка

    private func row(_ country: Country) -> some View {
        let status = log.status(for: country.id)
        return HStack(spacing: DS.Space.xs) {
            // Вся левая часть строки — одна большая кнопка «был»: это то,
            // ради чего список открыли, и промахнуться по ней негде.
            Button {
                onMark(status == .visited ? nil : .visited, country)
            } label: {
                HStack(spacing: DS.Space.sm) {
                    visitedBox(isOn: status == .visited)

                    Text(country.displayName)
                        .font(DS.Font.body)
                        .foregroundStyle(status == nil ? DS.Color.inkSecondary : DS.Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer(minLength: 0)

                    if status == .living {
                        Image(systemName: "house.fill")
                            .font(.system(size: DS.Size.glyph, weight: .semibold))
                            .foregroundStyle(DS.StatusColor.glow(.living))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(country.displayName)
            .accessibilityValue(status == .visited ? "был" : "не отмечено")

            Button {
                onMark(status == .wishlist ? nil : .wishlist, country)
            } label: {
                wishlistButton(isOn: status == .wishlist)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Хочу побывать: \(country.displayName)")
        }
        .padding(.vertical, 6)
        .padding(.horizontal, DS.Space.xs)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .fill(status == nil ? Color.clear : DS.Color.surfaceSunken.opacity(0.5))
        }
    }

    /// «Был» — квадратная галочка слева, как в любом списке дел.
    ///
    /// Значок виден и в пустой клетке, только бледный: два одинаковых
    /// пустых квадрата по краям строки ничего не говорили о том, чем они
    /// отличаются, и правый выглядел вторым «был».
    private func visitedBox(isOn: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isOn ? DS.StatusColor.glow(.visited).opacity(0.9) : Color.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isOn ? Color.clear : DS.Color.borderStrong, lineWidth: 1.5)
                }
            Image(systemName: "checkmark")
                .font(.system(size: DS.Size.glyph, weight: .bold))
                .foregroundStyle(isOn ? DS.Color.inkOnAccent : DS.Color.inkTertiary.opacity(0.55))
        }
        .frame(width: 30, height: 30)
        .animation(motion.animation(.snap), value: isOn)
    }

    /// «Хочу» — круг со звёздочкой справа.
    ///
    /// Круг, а не второй квадрат: форма отличает кнопку с другим смыслом
    /// быстрее, чем значок внутри неё.
    private func wishlistButton(isOn: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isOn ? DS.StatusColor.glow(.wishlist).opacity(0.9) : Color.clear)
                .overlay {
                    Circle().strokeBorder(isOn ? Color.clear : DS.Color.border, lineWidth: 1.5)
                }
            Image(systemName: "sparkles")
                .font(.system(size: DS.Size.glyph, weight: .semibold))
                .foregroundStyle(isOn ? DS.Color.inkOnAccent : DS.Color.inkTertiary.opacity(0.55))
        }
        .frame(width: 30, height: 30)
        .animation(motion.animation(.snap), value: isOn)
    }

    private var doneButton: some View {
        PillButton("Готово", kind: .tinted(accent), fullWidth: true, action: onDismiss)
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
