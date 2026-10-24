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
    let onDismiss: () -> Void

    @State private var draftName: String = ""
    @State private var isEditingName = false
    @State private var dragOffset: CGFloat = 0
    @State private var isPickingAvatar = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            scrim
            panel

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
        VStack(spacing: DS.Space.md) {
            Capsule()
                .fill(DS.Color.borderStrong)
                .frame(width: 38, height: 4)

            header
            whatSignInGives
            providers

            if !account.profile.isLocal {
                PillButton("Выйти", kind: .secondary, fullWidth: true) {
                    Task { await account.signOut() }
                }
            }
        }
        .padding(.horizontal, DS.Space.screen)
        .padding(.top, DS.Space.sm)
        .padding(.bottom, DS.Space.xl)
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

    private var panelFill: AnyShapeStyle {
        motion.reduceTransparency
            ? AnyShapeStyle(DS.Color.materialFallback)
            : AnyShapeStyle(.ultraThinMaterial)
    }

    // MARK: - Шапка

    private var header: some View {
        HStack(spacing: DS.Space.md) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                if isEditingName {
                    TextField("Имя", text: $draftName)
                        .font(DS.Font.title)
                        .foregroundStyle(DS.Color.ink)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit { commitName() }
                } else {
                    Text(account.profile.name)
                        .font(DS.Font.title)
                        .foregroundStyle(DS.Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }

                Text(account.profile.email ?? account.profile.provider.title)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

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
                .font(.system(size: DS.Size.glyphMd, weight: .semibold))
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
                Text(signInTitle(provider))
                Spacer(minLength: 0)
            }
            .font(DS.Font.subhead)
            .foregroundStyle(DS.Color.ink)
            .padding(.horizontal, DS.Space.md)
            .frame(maxWidth: .infinity)
            .frame(height: DS.Size.controlHeight)
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
