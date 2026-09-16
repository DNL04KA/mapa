import SwiftUI

// MARK: - Доступность

/// Переключатели вынесены в самый верх витрины намеренно:
/// проверять Reduce Motion нужно постоянно, а не один раз перед релизом.
struct AccessibilitySection: View {

    @Environment(\.dsMotion) private var motion
    @Binding var previewReduceMotion: Bool
    @Binding var previewReduceTransparency: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionHeader("Доступность", subtitle: "Тумблеры имитируют системные настройки")

            GlassCard {
                VStack(spacing: DS.Space.sm) {
                    toggle("Reduce Motion", isOn: $previewReduceMotion, active: motion.reduceMotion)
                    Divider().overlay(DS.Color.hairline)
                    toggle("Reduce Transparency", isOn: $previewReduceTransparency, active: motion.reduceTransparency)
                }
            }
        }
    }

    private func toggle(_ title: String, isOn: Binding<Bool>, active: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.ink)
                Text(active ? "включено" : "выключено")
                    .font(DS.Font.caption)
                    .foregroundStyle(active ? DS.Palette.mint : DS.Color.inkTertiary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(DS.Color.accent)
        }
        .frame(minHeight: DS.Size.hitTarget)
    }
}

// MARK: - Цвет

struct ColorSection: View {

    private let swatches: [(String, Color)] = [
        ("canvas", DS.Color.canvas),
        ("background", DS.Color.background),
        ("surface", DS.Color.surface),
        ("raised", DS.Color.surfaceRaised),
        ("ink", DS.Color.ink),
        ("inkSecondary", DS.Color.inkSecondary),
        ("inkTertiary", DS.Color.inkTertiary),
        ("accent", DS.Color.accent),
        ("mapWater", DS.Color.mapWater),
        ("mapLandIdle", DS.Color.mapLandIdle),
        ("danger", DS.Color.danger)
    ]

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: DS.Space.sm)]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionHeader("Цвет", subtitle: "Семантические роли, а не оттенки")

            LazyVGrid(columns: columns, spacing: DS.Space.sm) {
                ForEach(swatches, id: \.0) { name, color in
                    VStack(alignment: .leading, spacing: DS.Space.xxs) {
                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            .fill(color)
                            .frame(height: 52)
                            .overlay {
                                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                    .strokeBorder(DS.Color.hairline, lineWidth: 1)
                            }
                        Text(name)
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.inkTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
    }
}

// MARK: - Градиенты

struct GradientSection: View {

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionHeader("Градиенты статусов", subtitle: "Ими будут заливаться страны")

            HStack(spacing: DS.Space.sm) {
                ForEach(TravelStatus.allCases) { status in
                    VStack(spacing: DS.Space.xs) {
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .fill(DS.Gradient.status(status))
                            .frame(height: 96)
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: status.icon)
                                    .font(.system(size: DS.Size.iconMd, weight: .bold))
                                    .foregroundStyle(DS.Color.inkOnAccent.opacity(0.55))
                                    .padding(DS.Space.xs)
                            }
                            .dsShadow(.glow(DS.Gradient.statusGlowColor(status), radius: 22))

                        Text(status.title)
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Color.inkSecondary)
                    }
                }
            }

            // Мягкий вариант — фон под чипами и карточками.
            HStack(spacing: DS.Space.sm) {
                ForEach(TravelStatus.allCases) { status in
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .fill(DS.Gradient.statusSoft(status))
                        .frame(height: 36)
                }
            }
        }
    }
}

// MARK: - Типографика

struct TypographySection: View {

    private let samples: [(String, Font)] = [
        ("hero · 56", DS.Font.hero),
        ("display · 36", DS.Font.display),
        ("title · 26", DS.Font.title),
        ("headline · 19", DS.Font.headline),
        ("body · 16", DS.Font.body),
        ("caption · 13", DS.Font.caption)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionHeader("Типографика", subtitle: "Системный шрифт, масштабируется Dynamic Type")

            GlassCard {
                VStack(alignment: .leading, spacing: DS.Space.sm) {
                    ForEach(samples, id: \.0) { name, font in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Осака")
                                .font(font)
                                .foregroundStyle(DS.Color.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            Text(name)
                                .font(DS.Font.micro)
                                .foregroundStyle(DS.Color.inkTertiary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Сетка и радиусы

struct LayoutSection: View {

    private let spaces: [(String, CGFloat)] = [
        ("xxs", DS.Space.xxs), ("xs", DS.Space.xs), ("sm", DS.Space.sm),
        ("md", DS.Space.md), ("lg", DS.Space.lg), ("xl", DS.Space.xl), ("xxl", DS.Space.xxl)
    ]

    private let radii: [(String, CGFloat)] = [
        ("sm", DS.Radius.sm), ("md", DS.Radius.md), ("lg", DS.Radius.lg), ("xl", DS.Radius.xl)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionHeader("Сетка", subtitle: "Шаг 4pt — общий ритм интерфейса")

            GlassCard {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    ForEach(spaces, id: \.0) { name, value in
                        HStack(spacing: DS.Space.xs) {
                            Text(name)
                                .font(DS.Font.micro)
                                .foregroundStyle(DS.Color.inkTertiary)
                                .frame(width: 30, alignment: .leading)
                            Capsule()
                                .fill(DS.Gradient.accent)
                                .frame(width: value, height: 8)
                            Text("\(Int(value))")
                                .font(DS.Font.micro)
                                .foregroundStyle(DS.Color.inkTertiary)
                        }
                    }
                }
            }

            HStack(spacing: DS.Space.sm) {
                ForEach(radii, id: \.0) { name, value in
                    VStack(spacing: DS.Space.xxs) {
                        RoundedRectangle(cornerRadius: value, style: .continuous)
                            .fill(DS.Color.surfaceRaised)
                            .overlay {
                                RoundedRectangle(cornerRadius: value, style: .continuous)
                                    .strokeBorder(DS.Color.border, lineWidth: 1)
                            }
                            .frame(height: 64)
                        Text(name)
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.inkTertiary)
                    }
                }
            }
        }
    }
}

// MARK: - Глубина

struct ElevationSection: View {

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionHeader("Глубина", subtitle: "Тень + светлая кромка + свечение")

            HStack(spacing: DS.Space.md) {
                card("low", shadow: .low)
                card("medium", shadow: .medium)
                card("high", shadow: .high)
            }
            .padding(.vertical, DS.Space.xs)
        }
    }

    private func card(_ title: String, shadow: DS.Shadow) -> some View {
        Text(title)
            .font(DS.Font.caption)
            .foregroundStyle(DS.Color.inkSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(DS.Color.surfaceRaised)
            .dsRounded(DS.Radius.md)
            .dsShadow(shadow)
    }
}

// MARK: - Движение

struct MotionSection: View {

    @Environment(\.dsMotion) private var motion
    @State private var activePreset: DS.Motion.Preset = .smooth
    @State private var isMoved = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionHeader("Движение", subtitle: "Тапни пресет — увидишь его характер")

            GlassCard {
                VStack(alignment: .leading, spacing: DS.Space.md) {
                    stage

                    VStack(spacing: DS.Space.xs) {
                        ForEach(DS.Motion.Preset.allCases) { preset in
                            presetRow(preset)
                        }
                    }
                }
            }
        }
    }

    /// Сцена, на которой «играет» выбранная пружина.
    private var stage: some View {
        GeometryReader { proxy in
            let travel = proxy.size.width - 56
            Circle()
                .fill(DS.Gradient.accent)
                .frame(width: 44, height: 44)
                .dsShadow(.glow(DS.Palette.indigo, radius: 18))
                .offset(x: isMoved ? travel : 0)
                .scaleEffect(isMoved ? 1.18 : 1)
        }
        .frame(height: 52)
    }

    @MainActor private func presetRow(_ preset: DS.Motion.Preset) -> some View {
        Button {
            activePreset = preset
            Haptics.shared.selection()
            withAnimation(motion.animation(preset)) {
                isMoved.toggle()
            }
        } label: {
            HStack(spacing: DS.Space.sm) {
                Circle()
                    .fill(activePreset == preset ? DS.Color.accent : DS.Color.border)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.title)
                        .font(DS.Font.subhead)
                        .foregroundStyle(DS.Color.ink)
                    Text(preset.usage)
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.inkTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DS.Color.inkTertiary)
            }
            .frame(minHeight: DS.Size.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Хаптика

struct HapticsSection: View {

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionHeader("Хаптика", subtitle: "На симуляторе не ощущается — нужен телефон")

            GlassCard {
                VStack(spacing: DS.Space.xs) {
                    row("Заливка страны", detail: "Core Haptics: щелчок + волна") {
                        Haptics.shared.countryFill()
                    }
                    Divider().overlay(DS.Color.hairline)
                    row("Снятие статуса", detail: "Мягкое затухание") {
                        Haptics.shared.countryClear()
                    }
                    Divider().overlay(DS.Color.hairline)
                    row("Выбор", detail: "selectionChanged") {
                        Haptics.shared.selection()
                    }
                    Divider().overlay(DS.Color.hairline)
                    row("Успех", detail: "notification .success") {
                        Haptics.shared.success()
                    }
                }
            }
        }
    }

    private func row(_ title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Color.ink)
                    Text(detail)
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.inkTertiary)
                }
                Spacer()
                Image(systemName: "waveform")
                    .font(.system(size: DS.Size.iconSm, weight: .semibold))
                    .foregroundStyle(DS.Color.accentSoft)
            }
            .frame(minHeight: DS.Size.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Компоненты

struct ComponentsSection: View {

    @Environment(\.dsMotion) private var motion
    @State private var selectedStatus: TravelStatus? = .visited
    @State private var countries: Double = 12
    @State private var worldPercent: Double = 5.9

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionHeader("Компоненты", subtitle: "Из них собирается всё остальное")

            HStack(spacing: DS.Space.sm) {
                PillButton("Сохранить", icon: "checkmark", kind: .primary) {}
                PillButton("Отмена", kind: .secondary) {}
            }

            // Прообраз шита выбора статуса с 3-го этапа.
            HStack(spacing: DS.Space.xs) {
                ForEach(TravelStatus.allCases) { status in
                    StatusChip(status: status, isSelected: selectedStatus == status) {
                        withAnimation(motion.animation(.bounce)) {
                            selectedStatus = (selectedStatus == status) ? nil : status
                        }
                    }
                }
            }

            statsCard
        }
    }

    /// Прообраз панели статистики с 4-го этапа: числа набегают, а не подменяются.
    @MainActor private var statsCard: some View {
        GlassCard(padding: DS.Space.lg) {
            VStack(alignment: .leading, spacing: DS.Space.md) {
                Text("Мир открыт на")
                    .dsOverline()

                HStack(alignment: .firstTextBaseline, spacing: DS.Space.md) {
                    AnimatedNumber.percent(worldPercent)
                        .animation(motion.animation(.smooth), value: worldPercent)

                    VStack(alignment: .leading, spacing: 0) {
                        AnimatedNumber(value: countries, font: DS.Font.numeral)
                            .animation(motion.animation(.smooth), value: countries)
                        Text("стран")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Color.inkSecondary)
                    }
                }

                PillButton("Отметить страну", icon: "plus", kind: .status(.visited), fullWidth: true) {
                    Haptics.shared.countryFill()
                    countries += 1
                    worldPercent = min(100, worldPercent + Double.random(in: 0.3...1.4))
                }
            }
        }
    }
}
