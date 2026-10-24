import SwiftUI

/// Что именно сейчас примеряют.
///
/// Полотно и палитра примеряются по отдельности: выбирая цвета, ты должен
/// видеть их на **своём** полотне, а не на чужом.
enum ThemePreview: Equatable {
    case surface(MapSurface)
    case palette(MapPalette)

    var id: String {
        switch self {
        case let .surface(surface): return "surface:" + surface.id
        case let .palette(palette): return "palette:" + palette.id
        }
    }

    var isPremium: Bool {
        switch self {
        case let .surface(surface): return surface.isPremium
        case let .palette(palette): return palette.isPremium
        }
    }
}

/// Выбор оформления карты.
///
/// Две вкладки, а не один список. Полотно — то, на чём нарисована карта;
/// палитра — чем закрашены страны. Раньше это было слито в одну тему, и
/// «бумага с яркими странами» была невозможна в принципе: пришлось бы
/// заводить отдельную тему на каждое сочетание.
///
/// Панель живёт в одном слое с картой: пока листаешь, карта под ней видна и
/// меняется сразу. Платное можно примерить — оно применяется к твоей настоящей
/// карте, пока панель открыта, и снимается при закрытии. Без этого продавать
/// оформление бессмысленно: по квадратику превью невозможно понять, каково это.
@MainActor
struct ThemePicker: View {

    @Environment(\.dsMotion) private var motion

    let surface: MapSurface
    let palette: MapPalette
    let preview: ThemePreview?
    let onSelectSurface: (MapSurface) -> Void
    let onSelectPalette: (MapPalette) -> Void
    let onPreview: (ThemePreview?) -> Void
    let onDismiss: () -> Void
    let onOpenGallery: () -> Void

    enum Tab: String, CaseIterable, Identifiable {
        case surface = "Полотно"
        case palette = "Цвета"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .surface
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
            .fill(DS.Color.scrim)
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

            tabs

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    switch tab {
                    case .surface:
                        surfaceSection("Открыто", MapSurface.free)
                        premiumBlock
                        surfaceSection(nil, MapSurface.premium)
                    case .palette:
                        paletteSection("Открыто", MapPalette.free)
                        premiumBlock
                        paletteSection(nil, MapPalette.premium)
                    }
                    languageRow
                    footer
                }
                .padding(.bottom, DS.Space.sm)
            }
            .frame(maxHeight: 440)
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

    // MARK: - Вкладки

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { item in
                let isOn = tab == item
                Button {
                    Haptics.shared.selection()
                    // Примерка снимается при переходе: иначе непонятно,
                    // что именно сейчас надето на карту.
                    onPreview(nil)
                    withAnimation(motion.animation(.snap)) { tab = item }
                } label: {
                    Text(LocalizedStringKey(item.rawValue))
                        .font(DS.Font.callout)
                        .foregroundStyle(isOn ? DS.Color.inkOnAccent : DS.Color.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background {
                            if isOn {
                                Capsule().fill(DS.Color.ink)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(3)
        .background(Capsule().fill(DS.Color.surfaceSunken.opacity(0.7)))
    }

    // MARK: - Полотна

    private func surfaceSection(_ title: String?, _ items: [MapSurface]) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            if let title { Text(title).dsOverline() }
            LazyVGrid(columns: columns, spacing: DS.Space.md) {
                ForEach(items) { item in
                    tile(
                        name: item.name,
                        subtitle: item.subtitle,
                        accent: item.accent,
                        isPremium: item.isPremium,
                        isSelected: item.id == surface.id && preview == nil,
                        isPreviewing: preview == .surface(item)
                    ) {
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .fill(item.previewGradient)
                    } tap: {
                        choose(.surface(item), isFree: !item.isPremium) {
                            onSelectSurface(item)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Палитры

    private func paletteSection(_ title: String?, _ items: [MapPalette]) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            if let title { Text(title).dsOverline() }
            LazyVGrid(columns: columns, spacing: DS.Space.md) {
                ForEach(items) { item in
                    tile(
                        name: item.name,
                        subtitle: item.subtitle,
                        accent: item.previewColors.first ?? surface.accent,
                        isPremium: item.isPremium,
                        isSelected: item.id == palette.id && preview == nil,
                        isPreviewing: preview == .palette(item)
                    ) {
                        paletteSwatch(item)
                    } tap: {
                        choose(.palette(item), isFree: !item.isPremium) {
                            onSelectPalette(item)
                        }
                    }
                }
            }
        }
    }

    /// Цвета показываем на твоём полотне, а не на нейтральном фоне:
    /// одна и та же палитра на бумаге и в ночи выглядит по-разному.
    private func paletteSwatch(_ item: MapPalette) -> some View {
        let colors = item.id == MapPalette.monoAccent.id
            ? Array(repeating: surface.accent, count: 4)
            : item.previewColors

        return ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(surface.previewGradient)

            HStack(spacing: 3) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color)
                }
            }
            .padding(DS.Space.xs)
        }
    }

    // MARK: - Плитка

    private func choose(_ item: ThemePreview, isFree: Bool, apply: () -> Void) {
        if isFree {
            Haptics.shared.selection()
            onPreview(nil)
            apply()
        } else {
            Haptics.shared.tap(.soft)
            onPreview(preview == item ? nil : item)
        }
    }

    private func tile<Art: View>(
        name: String,
        subtitle: String?,
        accent: Color,
        isPremium: Bool,
        isSelected: Bool,
        isPreviewing: Bool,
        @ViewBuilder art: () -> Art,
        tap: @escaping () -> Void
    ) -> some View {
        Button(action: tap) {
            VStack(spacing: DS.Space.xs) {
                ZStack {
                    art()
                        .frame(height: 78)
                        .overlay {
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .strokeBorder(
                                    isSelected || isPreviewing ? accent : DS.Color.border,
                                    lineWidth: isSelected || isPreviewing ? 2 : 1
                                )
                        }

                    if isPreviewing {
                        badge("eye.fill", size: DS.Size.iconMd)
                    } else if isPremium {
                        badge("lock.fill", size: DS.Size.iconSm)
                    } else if isSelected {
                        badge("checkmark", size: DS.Size.iconMd)
                    }
                }

                VStack(spacing: 0) {
                    // Названия полотен и палитр лежат в модели обычными
                    // строками, но в таблице переводов они есть — поэтому
                    // оборачиваем в ключ, а не показываем как есть.
                    Text(LocalizedStringKey(name))
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.ink)
                    if let subtitle {
                        Text(LocalizedStringKey(subtitle))
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
        .accessibilityLabel(Text(LocalizedStringKey(name)))
        .accessibilityHint(isPremium ? "Платное. Коснись, чтобы примерить" : "Применить")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func badge(_ icon: String, size: CGFloat) -> some View {
        Image(systemName: icon)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.7), radius: 4)
    }

    /// Блок подписки. Никаких кнопок «купить»: покупок ещё нет,
    /// и рисовать их — обманывать.
    private var premiumBlock: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.xs) {
                Text("MAPA+")
                    .font(DS.Font.brand)
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

            Text(tab == .surface
                 ? "Пятнадцать полотен, где меняется не цвет, а материал карты: пергамент со штриховкой пером, миллиметровка чертежа, звёздное небо под сушей."
                 : "Восемь палитр — от одноцветного угля до неоновой вывески. Любая ложится на любое полотно, и это твои сто с лишним сочетаний.")
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Label("Коснись любого — примеришь на своей карте", systemImage: "hand.tap")
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

    /// Язык приложения.
    ///
    /// Своего переключателя внутри нет намеренно. iOS сама заводит для
    /// приложения с двумя и более переводами пункт «Язык» в своих настройках,
    /// и этот путь всегда верен: он переживает перезапуск, учитывает порядок
    /// языков у человека и не требует подменять бандл на ходу. Наше дело —
    /// довести туда, а не изображать то же самое своими руками.
    private var languageRow: some View {
        Button {
            Haptics.shared.tap(.light)
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        } label: {
            HStack(spacing: DS.Space.xs) {
                Image(systemName: "globe")
                    .font(.system(size: DS.Size.iconSm, weight: .semibold))
                Text("Язык приложения")
                Spacer(minLength: 0)
                Text(languageName)
                    .foregroundStyle(DS.Color.inkTertiary)
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: DS.Size.glyphMd, weight: .bold))
                    .foregroundStyle(DS.Color.inkTertiary)
            }
            .font(DS.Font.callout)
            .foregroundStyle(DS.Color.inkSecondary)
            .frame(height: DS.Size.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Откроются настройки приложения"))
    }

    /// Язык, который система выбрала из наших переводов, — его и показываем.
    private var languageName: String {
        let code = Bundle.main.preferredLocalizations.first ?? "ru"
        return Locale(identifier: code).localizedString(forLanguageCode: code)?.capitalized
            ?? code.uppercased()
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
