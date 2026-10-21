import SwiftUI

/// Создание профиля.
///
/// Отдельный шаг, а не обязательный вход на старте. Карту человек
/// отмечает для себя, и спрашивать у него никнейм до того, как он хоть
/// что-то увидел, — вернейший способ его потерять. Профиль нужен там, где
/// появляется второй человек: подписать свой маршрут, чтобы к тебе
/// зашли, оценить чужой.
///
/// Поэтому экран честно делит обещания на два списка: что заработает
/// сразу и что ждёт сервера. Писать «откроются оценки» там, где их пока
/// некому ставить, — тот же обман, только мелким шрифтом.
@MainActor
struct ProfileSetupSheet: View {

    @Environment(\.dsMotion) private var motion
    @ObservedObject var account: AccountStore
    @StateObject private var keyboard = KeyboardInset()

    let accent: Color
    let onDone: () -> Void
    let onDismiss: () -> Void

    @State private var handle = ""
    @State private var name = ""
    @State private var showsAvatars = false
    @State private var dragOffset: CGFloat = 0
    @FocusState private var handleFocused: Bool

    private var problem: String? {
        handle.isEmpty ? nil : Handle.problem(with: handle)
    }

    private var canCreate: Bool { Handle.isValid(handle) }

    var body: some View {
        ZStack(alignment: .bottom) {
            scrim

            VStack(spacing: 0) {
                Spacer(minLength: 72)
                panel
            }

            if showsAvatars {
                AvatarPicker(
                    current: account.profile.avatar,
                    accent: accent,
                    onSelect: { avatar in
                        account.setAvatar(avatar)
                        withAnimation(motion.animation(.smooth)) { showsAvatars = false }
                    },
                    onDismiss: {
                        withAnimation(motion.animation(.smooth)) { showsAvatars = false }
                    }
                )
                .zIndex(1)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            name = account.profile.name
            handleFocused = true
        }
    }

    private var scrim: some View {
        Rectangle()
            .fill(DS.Color.scrim)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .transition(.opacity)
            .accessibilityLabel("Закрыть")
            .accessibilityAddTraits(.isButton)
    }

    private var panel: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }.scrollIndicators(.hidden)
        }
        .padding(.horizontal, DS.Space.screen)
        .padding(.top, DS.Space.sm)
        // Клавиатуру панель пускает вперёд: без этого поле никнейма с
        // курсором в нём пряталось под ней вместе с кнопкой «Готово».
        .padding(.bottom, keyboard.height > 0
                 ? keyboard.height + DS.Space.md
                 : DS.Space.xl + DS.Space.lg)
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
        .animation(motion.animation(.smooth), value: keyboard.height)
        .offset(y: dragOffset)
        .gesture(dismissDrag)
        .transition(.move(edge: .bottom))
    }

    private var content: some View {
        VStack(spacing: DS.Space.md) {
            Capsule()
                .fill(DS.Color.borderStrong)
                .frame(width: 38, height: 4)

            Text("Профиль")
                .font(DS.Font.title)
                .foregroundStyle(DS.Color.ink)

            avatar
            handleField
            nameField
            whatItGives

            PillButton("Готово", kind: .tinted(accent), fullWidth: true) {
                guard account.createProfile(handle: handle, name: name) else { return }
                Haptics.shared.success()
                onDone()
            }
            .disabled(!canCreate)
            .opacity(canCreate ? 1 : 0.5)
        }
    }

    private var avatar: some View {
        Button {
            Haptics.shared.tap(.light)
            withAnimation(motion.animation(.smooth)) { showsAvatars = true }
        } label: {
            VStack(spacing: DS.Space.xxs) {
                AvatarView(avatar: account.profile.avatar, size: 96)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(DS.Color.inkOnAccent)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(accent))
                    }
                Text("Сменить картинку")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.inkTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var handleField: some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            // Собачка вплотную к набранному: с разрядкой «@ nikita»
            // читалось двумя словами, а никнейм — одно слово и один адрес.
            HStack(spacing: 0) {
                Text(verbatim: "@")
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.inkTertiary.opacity(0.7))

                TextField("никнейм", text: $handle)
                    .font(DS.Font.title)
                    .foregroundStyle(DS.Color.ink)
                    .focused($handleFocused)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: handle) { value in
                        // Приводим к хранимому виду прямо при наборе:
                        // так человек сразу видит, каким никнейм станет.
                        let cleaned = Handle.normalized(value)
                        if cleaned != value { handle = cleaned }
                    }

                if canCreate {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: DS.Size.iconSm))
                        .foregroundStyle(DS.Gradient.statusGlowColor(.living))
                }
            }
            .padding(.horizontal, DS.Space.md)
            .frame(height: DS.Size.controlHeight + 6)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Color.surfaceSunken.opacity(0.7))
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .strokeBorder(problem == nil ? DS.Color.hairline : DS.Color.danger,
                                          lineWidth: 1)
                    }
            }

            Text(problem ?? String(localized: "По нему тебя найдут и зайдут к тебе"))
                .font(DS.Font.micro)
                .foregroundStyle(problem == nil ? DS.Color.inkTertiary : DS.Color.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var nameField: some View {
        TextField("Имя", text: $name)
            .font(DS.Font.body)
            .foregroundStyle(DS.Color.ink)
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

    /// Два списка вместо одного: что работает сейчас и что ждёт сервера.
    private var whatItGives: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            line("checkmark.circle.fill", "Имя и картинка на твоей карте и в экспорте",
                 isReady: true)
            line("checkmark.circle.fill", "Никнейм, по которому к тебе зайдут",
                 isReady: true)
            line("clock", "Опубликовать маршрут и оценить чужой — когда подключим сервер",
                 isReady: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func line(_ icon: String, _ text: LocalizedStringKey, isReady: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.xs) {
            Image(systemName: icon)
                .font(.system(size: DS.Size.iconSm, weight: .semibold))
                // Цвет статуса, а не текст поверх него: `statusForeground`
                // рассчитан на заливку, и без неё галочка превращалась в
                // тёмное пятно на тёмной панели.
                .foregroundStyle(isReady ? DS.Gradient.statusGlowColor(.living)
                                         : DS.Color.inkTertiary)
                .frame(width: 20)
            Text(text)
                .font(DS.Font.caption)
                .foregroundStyle(isReady ? DS.Color.inkSecondary : DS.Color.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
