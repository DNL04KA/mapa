import SwiftUI

/// Экран покупки MAPA+.
///
/// Говорит ровно то, что человек получит, и ровно одну цену. Ни обратного
/// отсчёта, ни «осталось два часа», ни зачёркнутой цены, которой никогда
/// не было: в приложении про честные данные торговать срочностью было бы
/// странно.
@MainActor
struct PlusSheet: View {

    @Environment(\.dsMotion) private var motion

    @ObservedObject var shop: Shop
    let accent: Color
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            scrim
            VStack(spacing: 0) {
                Spacer(minLength: 96)
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
        .transition(.move(edge: .bottom))
    }

    private var content: some View {
        VStack(spacing: DS.Space.md) {
            Capsule()
                .fill(DS.Color.borderStrong)
                .frame(width: 38, height: 4)

            Text("MAPA+")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(DS.Gradient.accent)

            Text("Пятнадцать полотен, где меняется не цвет, а материал карты, и восемь палитр к ним.")
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            samples

            VStack(alignment: .leading, spacing: DS.Space.xs) {
                point("paintpalette", "Пергамент, чертёж, звёздное небо под сушей")
                point("infinity", "Один раз и навсегда — это не подписка")
                point("person.2", "Работает на всех твоих устройствах")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            action
            footer
        }
    }

    /// Четыре платных полотна вживую: обещание словами проверить нельзя,
    /// а посмотреть — можно.
    private var samples: some View {
        HStack(spacing: DS.Space.xs) {
            ForEach(MapSurface.premium.prefix(4)) { surface in
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .fill(surface.previewGradient)
                    .frame(height: 76)
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            .strokeBorder(DS.Color.border, lineWidth: 1)
                    }
            }
        }
        .accessibilityHidden(true)
    }

    private func point(_ icon: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.xs) {
            Image(systemName: icon)
                .font(.system(size: DS.Size.iconSm, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 22)
            Text(text)
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var action: some View {
        if shop.isPlus {
            HStack(spacing: DS.Space.xs) {
                Image(systemName: "checkmark.seal.fill")
                Text("MAPA+ открыт")
            }
            .font(DS.Font.subhead)
            .foregroundStyle(DS.Gradient.statusForeground(.living))
            .frame(maxWidth: .infinity)
            .frame(minHeight: DS.Size.controlHeight)
            .background(DS.Gradient.status(.living))
            .clipShape(Capsule(style: .continuous))
        } else {
            switch shop.state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: DS.Size.controlHeight)

            case .unavailable:
                // Честно: не «ошибка», а «витрина не отвечает». Чаще всего
                // это нет сети, а до публикации — товар ещё не заведён.
                Text("Витрина недоступна. Проверь сеть и попробуй ещё раз.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

            case let .ready(price):
                PillButton(LocalizedStringKey("Открыть за \(price)"),
                           kind: .tinted(accent), fullWidth: true) {
                    Task { await shop.buy() }
                }
                .disabled(shop.isBuying)
                .opacity(shop.isBuying ? 0.6 : 1)
            }

            Button {
                Task { await shop.restore() }
            } label: {
                Text("Восстановить покупку")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: DS.Size.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(shop.isBuying)
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let failure = shop.failure {
            Text(failure)
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.danger)
                .multilineTextAlignment(.center)
        }

        #if DEBUG
        // В сборке для разработки покупка идёт через локальную витрину:
        // настоящих денег здесь нет, и делать вид, что есть, незачем.
        Text("Тестовая витрина: деньги не списываются")
            .font(DS.Font.micro)
            .foregroundStyle(DS.Color.inkTertiary)
        #endif
    }
}
