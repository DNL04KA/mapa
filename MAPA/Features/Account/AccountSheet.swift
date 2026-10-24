import SwiftUI

/// Профиль.
///
/// Открывается до всякого входа и не требует его: карту ты отмечаешь для
/// себя. Вход нужен ровно там, где появляется второй человек — опубликовать
/// маршрут, сохранить чужой, перенести свою карту на новый телефон. Поэтому
/// экран начинается с того, что у тебя уже есть, а не с формы регистрации.
@MainActor
struct AccountSheet: View {

    @Environment(\.dsMotion) private var motion
    @ObservedObject var account: AccountStore

    let accent: Color
    let statistics: TravelStatistics
    /// Страны, которые человек отметил. Это и есть его профиль: имя и
    /// аватарка без них — пустая форма.
    let visited: [Country]
    let wishlist: [Country]
    let homeCity: String?
    let routeCount: Int
    let onOpenCountry: (Country) -> Void
    let onOpenRoutes: () -> Void
    let onDismiss: () -> Void
    /// Шестерёнка в шапке профиля.
    let onOpenSettings: () -> Void
    /// Открыть список стран. Снять отметку иначе можно было, только найдя
    /// страну на карте, — а именно её человек обычно и не может найти.
    let onEditMarks: () -> Void

    @State private var draftName: String = ""
    @State private var isEditingName = false
    @State private var dragOffset: CGFloat = 0
    @State private var isPickingAvatar = false
    @State private var isCreatingProfile = false
    @FocusState private var nameFocused: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ZStack(alignment: .bottom) {
            scrim

            // Полоса сверху, за которую панель не заходит: иначе на крупном
            // шрифте она дорастает до «острова» и имя оказывается под ним.
            VStack(spacing: 0) {
                Spacer(minLength: 96)
                panel
            }

            if isCreatingProfile {
                ProfileSetupSheet(
                    account: account,
                    accent: accent,
                    onDone: {
                        withAnimation(motion.animation(.smooth)) { isCreatingProfile = false }
                    },
                    onDismiss: {
                        withAnimation(motion.animation(.smooth)) { isCreatingProfile = false }
                    }
                )
                .zIndex(2)
            }

            if isPickingAvatar {
                AvatarPicker(
                    current: account.profile.avatar,
                    accent: accent,
                    onSelect: { avatar in
                        account.setAvatar(avatar)
                        withAnimation(motion.animation(.smooth)) { isPickingAvatar = false }
                    },
                    onDismiss: {
                        withAnimation(motion.animation(.smooth)) { isPickingAvatar = false }
                    }
                )
                .zIndex(1)
            }
        }
        .ignoresSafeArea()
        #if DEBUG
        // Снимок выбора аватарки: нажать на карандаш симулятору нечем.
        .onAppear {
            if ProcessInfo.processInfo.environment["MAPA_AVATARS"] == "1" {
                isPickingAvatar = true
            }
            if ProcessInfo.processInfo.environment["MAPA_NEW_PROFILE"] == "1" {
                account.forgetHandleForScreenshot()
                isCreatingProfile = true
            }
        }
        #endif
    }

    private var scrim: some View {
        Rectangle()
            .fill(DS.Color.scrim)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .transition(.opacity)
            .accessibilityLabel("Закрыть профиль")
            .accessibilityAddTraits(.isButton)
    }

    private var panel: some View {
        // На крупном шрифте содержимое панели перерастает экран: имя уходит
        // под «остров», а строка про сервер обрезается полосой жестов.
        // `ViewThatFits` показывает список как есть, пока он помещается, и
        // включает прокрутку, когда перестал, — без ладони пустоты под
        // короткой панелью, которую оставил бы `ScrollView` всегда.
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }.scrollIndicators(.hidden)
        }
        .padding(.horizontal, DS.Space.screen)
        .padding(.top, DS.Space.sm)
        // Нижний отступ с запасом на полосу жестов: фон панели заходит под
        // неё намеренно, а текст — нет.
        .padding(.bottom, DS.Space.xl + DS.Space.lg)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedTopShape(radius: DS.Radius.xl)
                .fill(panelFill)
                .overlay {
                    UnevenRoundedTopShape(radius: DS.Radius.xl)
                        .fill(DS.Color.panel.opacity(motion.reduceTransparency ? 1 : 0.9))
                }
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
        VStack(spacing: DS.Space.md) {
            Capsule()
                .fill(DS.Color.borderStrong)
                .frame(width: 38, height: 4)

            // Две группы, а не одиннадцать подряд: `ViewBuilder` принимает
            // не больше десяти дочерних вью.
            Group {
                header
                if !account.profile.isCreated { createProfileCard }
                summary
                countrySection("Был", visited, status: .visited)
                countrySection("Хочу", wishlist, status: .wishlist)
                marksRow
                routesRow
            }

            Group {
                whatSignInGives
                providers

                if !account.profile.isLocal {
                    PillButton("Выйти", kind: .secondary, fullWidth: true) {
                        Task { await account.signOut() }
                    }
                }
            }
        }
    }

    /// Приглашение завести профиль.
    ///
    /// Не загородка на входе, а карточка в середине экрана: приложением
    /// можно пользоваться и без профиля, и человек, который просто красит
    /// карту, не должен об этом спотыкаться.
    private var createProfileCard: some View {
        Button {
            Haptics.shared.tap(.light)
            withAnimation(motion.animation(.smooth)) { isCreatingProfile = true }
        } label: {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: "at")
                    .font(.system(size: DS.Size.iconMd, weight: .semibold))
                    .foregroundStyle(accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Создать профиль")
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Color.ink)
                    Text("Никнейм и картинка — чтобы к тебе можно было зайти")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.inkTertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: DS.Size.glyph, weight: .bold))
                    .foregroundStyle(DS.Color.inkTertiary)
            }
            .padding(DS.Space.sm)
            .dsGlass(radius: DS.Radius.md, shadow: .low)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Три числа, которыми человек и представляется: сколько мира, сколько
    /// стран, откуда он.
    private var summary: some View {
        DS.Reflow(spacing: DS.Space.xs) {
            summaryTile(String(format: "%.1f%%", statistics.worldPercent), "мира открыто")
            summaryTile("\(statistics.exploredCount)", "стран")
            summaryTile(homeCity ?? "—", "дом")
        }
    }

    private func summaryTile(_ value: String, _ caption: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DS.Font.numeral)
                .foregroundStyle(DS.Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(caption)
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.inkTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Space.sm)
        .dsGlass(radius: DS.Radius.md, shadow: .low)
        .accessibilityElement(children: .combine)
    }

    /// Список стран с отметкой.
    ///
    /// То, ради чего в профиль и заходят: карта показывает цвет, а список
    /// показывает счёт. Названия — кнопками: из профиля логично провалиться
    /// в страну, а не возвращаться искать её на карте.
    @ViewBuilder
    private func countrySection(_ title: LocalizedStringKey,
                                _ countries: [Country],
                                status: TravelStatus) -> some View {
        if !countries.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                SectionHeader(title, subtitle: Plural.countries(countries.count))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Space.xs) {
                        ForEach(countries) { country in
                            Button {
                                onOpenCountry(country)
                            } label: {
                                HStack(spacing: DS.Space.xxs) {
                                    Circle()
                                        .fill(DS.StatusColor.colors(status, flagHue: country.flagHue)[0])
                                        .frame(width: 10, height: 10)
                                    Text(country.displayName)
                                        .font(DS.Font.caption)
                                        .foregroundStyle(DS.Color.ink)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, DS.Space.sm)
                                .padding(.vertical, DS.Space.xs)
                                .background {
                                    Capsule(style: .continuous)
                                        .fill(DS.Color.surfaceRaised.opacity(0.6))
                                        .overlay {
                                            Capsule(style: .continuous)
                                                .strokeBorder(DS.Color.border, lineWidth: 1)
                                        }
                                }
                                .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DS.Space.screen)
                }
                .padding(.horizontal, -DS.Space.screen)
            }
        }
    }

    private var marksRow: some View {
        Button(action: onEditMarks) {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: "checklist")
                    .font(.system(size: DS.Size.iconSm, weight: .semibold))
                    .foregroundStyle(accent)
                Text(visited.isEmpty && wishlist.isEmpty
                     ? "Отметить страны" : "Изменить отметки")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.ink)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: DS.Size.glyph, weight: .bold))
                    .foregroundStyle(DS.Color.inkTertiary)
            }
            .padding(DS.Space.sm)
            .dsGlass(radius: DS.Radius.md, shadow: .low)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var routesRow: some View {
        if routeCount > 0 {
            Button(action: onOpenRoutes) {
                HStack(spacing: DS.Space.sm) {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.system(size: DS.Size.iconSm, weight: .semibold))
                        .foregroundStyle(accent)
                    Text("Мои маршруты")
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Color.ink)
                    Spacer(minLength: 0)
                    Text(Plural.routes(routeCount))
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.inkTertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: DS.Size.glyph, weight: .bold))
                        .foregroundStyle(DS.Color.inkTertiary)
                }
                .padding(DS.Space.sm)
                .dsGlass(radius: DS.Radius.md, shadow: .low)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var panelFill: AnyShapeStyle {
        motion.reduceTransparency
            ? AnyShapeStyle(DS.Color.materialFallback)
            : AnyShapeStyle(.ultraThinMaterial)
    }

    // MARK: - Шапка

    private var header: some View {
        // На крупном шрифте имя не помещается рядом с аватаркой: «Путешест
        // венник» — одно слово в двести точек, и ужимать его дальше некуда.
        // Поэтому шапка перестраивается: аватарка с карандашом сверху, имя
        // и подпись под ними во всю ширину.
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    HStack {
                        avatar
                        Spacer(minLength: 0)
                        settingsButton
                        editButton
                    }
                    names
                }
            } else {
                HStack(spacing: DS.Space.md) {
                    avatar
                    names
                    Spacer(minLength: 0)
                    settingsButton
                    editButton
                }
            }
        }
    }

    private var names: some View {
        VStack(alignment: .leading, spacing: 2) {
            if isEditingName {
                TextField("Имя", text: $draftName)
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.ink)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { commitName() }
            } else {
                // Имя — одно длинное слово, и переносить его нельзя:
                // «Путешеств / енник» выглядит сломанным. Сжимается.
                Text(account.profile.displayName)
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            // А это уже несколько слов — им перенос к лицу.
            Text(account.profile.email ?? account.profile.provider.title)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.inkTertiary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var settingsButton: some View {
        Button(action: onOpenSettings) {
            Image(systemName: "gearshape")
                .font(.system(size: DS.Size.iconSm, weight: .semibold))
                .foregroundStyle(DS.Color.inkSecondary)
                .frame(width: DS.Size.hitTarget, height: DS.Size.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Настройки")
    }

    private var editButton: some View {
        Button {
            if isEditingName {
                commitName()
            } else {
                draftName = account.profile.name
                withAnimation(motion.animation(.snap)) { isEditingName = true }
                nameFocused = true
            }
        } label: {
            Image(systemName: isEditingName ? "checkmark" : "pencil")
                .font(.system(size: DS.Size.iconSm, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: DS.Size.hitTarget, height: DS.Size.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isEditingName ? "Сохранить имя" : "Изменить имя")
    }

    private func commitName() {
        account.rename(draftName)
        nameFocused = false
        withAnimation(motion.animation(.snap)) { isEditingName = false }
    }

    private var avatar: some View {
        Button {
            Haptics.shared.tap(.light)
            withAnimation(motion.animation(.smooth)) { isPickingAvatar = true }
        } label: {
            AvatarView(avatar: account.profile.avatar, size: 64)
                .overlay(alignment: .bottomTrailing) {
                    // Маленький карандаш в углу: без него непонятно,
                    // что по кружку вообще можно нажать.
                    Image(systemName: "pencil")
                        .font(.system(size: DS.Size.glyphSm, weight: .bold))
                        .foregroundStyle(DS.Color.inkOnAccent)
                        .padding(5)
                        .background(accent, in: Circle())
                        .overlay { Circle().strokeBorder(DS.Color.panel, lineWidth: 2) }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Изменить аватарку")
    }

    // MARK: - Зачем входить

    private var whatSignInGives: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            SectionHeader("Что даёт вход")

            row("arrow.triangle.2.circlepath", "Карта и маршруты переедут на новый телефон")
            row("paperplane", "Свои маршруты можно опубликовать")
            row("bookmark", "Чужие — сохранить и пройти")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ icon: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.xs) {
            Image(systemName: icon)
                .font(.system(size: DS.Size.glyph, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 18)
            Text(text)
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Вход

    @ViewBuilder
    private var providers: some View {
        if account.profile.isLocal {
            VStack(spacing: DS.Space.xs) {
                ForEach([AuthProvider.apple, .google, .email], id: \.self) { provider in
                    providerButton(provider)
                }

                if !account.canSignIn {
                    // Кнопки на месте, но не притворяются работающими.
                    // Нарисовать вход, за которым ничего нет, — хуже,
                    // чем честно сказать, что его пока нет.
                    Text("Вход заработает, когда подключим сервер. Пока карта, маршруты и оценки живут на этом телефоне и никуда не уходят.")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, DS.Space.xxs)
                }
            }
        }
    }

    private func providerButton(_ provider: AuthProvider) -> some View {
        Button {
            Task { await account.signIn(with: provider) }
        } label: {
            HStack(spacing: DS.Space.xs) {
                Image(systemName: provider.icon)
                    .font(.system(size: DS.Size.iconSm, weight: .semibold))
                // «Вход через Google» на крупном шрифте не умещался в
                // пилюлю и обрывался на «Goo…». Кнопка растёт по высоте.
                Text(signInTitle(provider))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .font(DS.Font.subhead)
            .foregroundStyle(DS.Color.ink)
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.xs)
            .frame(maxWidth: .infinity)
            .frame(minHeight: DS.Size.controlHeight)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
                    .fill(DS.Color.surfaceRaised.opacity(0.6))
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.Radius.pill, style: .continuous)
                            .strokeBorder(DS.Color.border, lineWidth: 1)
                    }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!account.canSignIn)
        .opacity(account.canSignIn ? 1 : 0.45)
    }

    private func signInTitle(_ provider: AuthProvider) -> LocalizedStringKey {
        switch provider {
        case .apple:  return "Вход с Apple"
        case .google: return "Вход через Google"
        case .email:  return "Вход по почте"
        case .local:  return "На этом телефоне"
        }
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { dragOffset = max(0, $0.translation.height) }
            .onEnded { value in
                if value.translation.height > 90 || value.predictedEndTranslation.height > 220 {
                    onDismiss()
                }
                withAnimation(motion.animation(.snap)) { dragOffset = 0 }
            }
    }
}
