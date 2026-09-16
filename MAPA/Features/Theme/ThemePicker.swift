import SwiftUI

/// Выбор оформления карты.
///
/// Панель живёт в одном слое с картой: пока листаешь темы, карта под ними
/// видна и меняется сразу. Платную тему можно примерить — она применяется
/// к твоей настоящей карте, пока панель открыта, и снимается при закрытии.
/// Без этого продавать оформление бессмысленно: по квадратику превью
/// невозможно понять, каково это.
@MainActor
struct ThemePicker: View {

    @Environment(\.dsMotion) private var motion

    let current: MapTheme
    let preview: MapTheme?
    let onSelect: (MapTheme) -> Void
    let onPreview: (MapTheme?) -> Void
    let onDismiss: () -> Void
    let onOpenGallery: () -> Void

    @State private var dragOffset: CGFloat = 0

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: DS.Space.sm)]

    var body: some View {
        ZStack(alignment: .bottom) {
            scrim
            panel
        }
        .ignoresSafeArea()
    }

    private var scrim: some View {
        Rectangle()
            .fill(DS.Palette.void.opacity(0.35))
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .transition(.opacity)
            .accessibilityLabel("Закрыть выбор оформления")
            .accessibilityAddTraits(.isButton)
    }

    private var panel: some View {
        VStack(spacing: DS.Space.md) {
            Capsule()
                .fill(DS.Color.borderStrong)
                .frame(width: 38, height: 4)

            Text("Оформление")
                .font(DS.Font.title)
                .foregroundStyle(DS.Color.ink)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    section("Открыто", themes: MapTheme.free)
                    premiumBlock
                    section(nil, themes: MapTheme.premium)
                    footer
                }
                .padding(.bottom, DS.Space.sm)
            }
            .frame(maxHeight: 460)
            .scrollIndicators(.hidden)
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

    // MARK: - Секции

    private func section(_ title: String?, themes: [MapTheme]) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            if let title {
                Text(title).dsOverline()
            }
            LazyVGrid(columns: columns, spacing: DS.Space.md) {
                ForEach(themes) { swatch($0) }
            }
        }
    }

    /// Блок подписки. Никаких кнопок «купить»: покупок ещё нет,
    /// и рисовать их — обманывать.
    private var premiumBlock: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.xs) {
                Text("MAPA+")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, DS.Palette.indigoSoft],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                Spacer(minLength: 0)
                Text("скоро")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.inkOnAccent)
                    .padding(.horizontal, DS.Space.xs)
                    .padding(.vertical, 3)
                    .background(DS.Palette.indigoSoft)
                    .clipShape(Capsule())
            }

            Text("Пятнадцать оформлений, где меняется не цвет, а материал карты: пергамент со штриховкой пером, миллиметровка чертежа, звёздное небо под сушей.")
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Label("Коснись любой — примеришь на своей карте", systemImage: "hand.tap")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Palette.indigoSoft)
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [DS.Palette.indigo.opacity(0.28), DS.Palette.indigo.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .strokeBorder(DS.Palette.indigoSoft.opacity(0.45), lineWidth: 1)
                }
        }
    }

    // MARK: - Плитка темы

    private func swatch(_ theme: MapTheme) -> some View {
        let isSelected = theme.id == current.id && preview == nil
        let isPreviewing = preview?.id == theme.id

        return Button {
            if theme.isPremium {
                Haptics.shared.tap(.soft)
                onPreview(isPreviewing ? nil : theme)
            } else {
                Haptics.shared.selection()
                onPreview(nil)
                onSelect(theme)
            }
        } label: {
            VStack(spacing: DS.Space.xs) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(theme.previewGradient)
                        .frame(height: 78)
                        .overlay {
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .strokeBorder(
                                    isSelected || isPreviewing ? theme.accent : DS.Color.border,
                                    lineWidth: isSelected || isPreviewing ? 2 : 1
                                )
                        }
                        .overlay(alignment: .bottomTrailing) {
                            Circle()
                                .fill(theme.accent)
                                .frame(width: 12, height: 12)
                                .padding(DS.Space.xs)
                        }

                    if isPreviewing {
                        Image(systemName: "eye.fill")
                            .font(.system(size: DS.Size.iconMd, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.7), radius: 4)
                    } else if theme.isPremium {
                        Image(systemName: "lock.fill")
                            .font(.system(size: DS.Size.iconSm, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.7), radius: 4)
                    } else if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: DS.Size.iconMd, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.7), radius: 4)
                    }
                }

                VStack(spacing: 0) {
                    Text(theme.name)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.ink)
                    if let subtitle = theme.subtitle {
                        Text(subtitle)
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.inkTertiary)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
        .animation(motion.animation(.snap), value: isSelected)
        .accessibilityLabel(theme.name)
        .accessibilityHint(theme.isPremium ? "Платная тема. Коснись, чтобы примерить" : "Применить оформление")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var footer: some View {
        Button(action: onOpenGallery) {
            HStack(spacing: DS.Space.xs) {
                Image(systemName: "paintpalette")
                    .font(.system(size: DS.Size.iconSm, weight: .semibold))
                Text("Дизайн-система")
            }
            .font(DS.Font.callout)
            .foregroundStyle(DS.Color.inkTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: DS.Size.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
