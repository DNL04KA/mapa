import SwiftUI
import UIKit

/// Настройки.
///
/// Всё, что раньше лежало по углам: язык прятался в панели оформления,
/// версию приложения негде было посмотреть, а копию своей карты — сделать.
/// Теперь это одно место, и оно же отвечает на вопрос «откуда вы взяли эти
/// данные»: источники названы здесь, а не только в мелком шрифте под
/// фотографиями.
@MainActor
struct SettingsSheet: View {

    @Environment(\.dsMotion) private var motion
    @ObservedObject var shop: Shop

    let accent: Color
    /// Копия карты — то, что уедет в файл.
    let backup: () -> URL?
    /// Возвращает `false`, если файл оказался чужим.
    let onRestore: (URL) -> Bool
    let onOpenAppearance: () -> Void
    let onOpenPlus: () -> Void
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isImporting = false
    @State private var note: String?

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            scrim
            VStack(spacing: 0) {
                Spacer(minLength: 72)
                panel
            }
        }
        .ignoresSafeArea()
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            guard case let .success(url) = result else { return }
            // Молчание после восстановления — худший ответ: человек не
            // знает, подменилась его карта или он выбрал не тот файл.
            let restored = onRestore(url)
            withAnimation(motion.animation(.snap)) {
                note = restored
                    ? String(localized: "Карта восстановлена из копии")
                    : String(localized: "Это не похоже на копию MAPA")
            }
        }
    }

    private var scrim: some View {
        Rectangle()
            .fill(DS.Color.scrim)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .transition(.opacity)
            .accessibilityLabel("Закрыть настройки")
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

            Text("Настройки")
                .font(DS.Font.title)
                .foregroundStyle(DS.Color.ink)
                .frame(maxWidth: .infinity)

            appearance
            data
            about
        }
    }

    // MARK: - Разделы

    private var appearance: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            SectionHeader("Вид и язык")

            row("paintpalette", "Оформление", detail: nil, action: onOpenAppearance)

            if shop.isPlus {
                row("checkmark.seal.fill", "MAPA+", detail: String(localized: "открыт"),
                    action: onOpenPlus)
            } else {
                row("sparkles", "MAPA+", detail: price, action: onOpenPlus)
            }

            // Язык приложение не выбирает само: iOS хранит это рядом с
            // остальными языковыми настройками телефона, и дублировать их
            // у себя — значит разъехаться с системой.
            row("globe", "Язык", detail: AppLocale.isRussian ? "Русский" : "English") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        }
    }

    private var price: String? {
        if case let .ready(price) = shop.state { return price }
        return nil
    }

    private var data: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            SectionHeader("Твои данные", subtitle: String(localized: "Они лежат только на этом телефоне"))

            if let file = backup() {
                ShareLink(item: file) {
                    rowLabel("square.and.arrow.up", "Сохранить копию",
                             detail: String(localized: "файл"))
                }
                .buttonStyle(.plain)
            }

            row("square.and.arrow.down", "Восстановить из копии", detail: nil) {
                isImporting = true
            }

            if let note {
                Text(note)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            SectionHeader("О приложении")

            row("info.circle", "Версия", detail: version, action: nil)

            link("hand.raised", "Политика конфиденциальности",
                 "https://dnl04ka.github.io/mapa/privacy.html")
            link("questionmark.circle", "Поддержка",
                 "https://dnl04ka.github.io/mapa/support.html")

            // Источники названы прямо: карта из Natural Earth, места и
            // фотографии из Викиданных и Викисклада. Это не формальность —
            // на этих данных приложение и стоит.
            VStack(alignment: .leading, spacing: 2) {
                Text("Границы — Natural Earth")
                Text("Места и фотографии — Викиданные и Викисклад")
            }
            .font(DS.Font.micro)
            .foregroundStyle(DS.Color.inkTertiary)
            .padding(.top, DS.Space.xxs)
        }
    }

    // MARK: - Кирпичики

    private func row(_ icon: String, _ title: LocalizedStringKey,
                     detail: String?, action: (() -> Void)?) -> some View {
        Button {
            guard let action else { return }
            Haptics.shared.tap(.light)
            action()
        } label: {
            rowLabel(icon, title, detail: detail, showsChevron: action != nil)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

    private func row(_ icon: String, _ title: LocalizedStringKey,
                     detail: String?, action: @escaping () -> Void) -> some View {
        row(icon, title, detail: detail, action: Optional(action))
    }

    private func rowLabel(_ icon: String, _ title: LocalizedStringKey,
                          detail: String?, showsChevron: Bool = true) -> some View {
        HStack(spacing: DS.Space.sm) {
            Image(systemName: icon)
                .font(.system(size: DS.Size.iconSm, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 24)

            Text(title)
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.ink)

            Spacer(minLength: DS.Space.xs)

            if let detail {
                Text(detail)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkTertiary)
                    .lineLimit(1)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: DS.Size.glyph, weight: .bold))
                    .foregroundStyle(DS.Color.inkTertiary)
            }
        }
        .padding(DS.Space.sm)
        .dsGlass(radius: DS.Radius.md, shadow: .low)
        .contentShape(Rectangle())
    }

    private func link(_ icon: String, _ title: LocalizedStringKey, _ address: String) -> some View {
        row(icon, title, detail: nil) {
            guard let url = URL(string: address) else { return }
            UIApplication.shared.open(url)
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
