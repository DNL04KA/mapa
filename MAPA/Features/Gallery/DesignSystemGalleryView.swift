import SwiftUI

/// Витрина дизайн-системы.
///
/// Это не «демо-экран ради демо». Пока нет карты, именно здесь мы глазами
/// и пальцами проверяем то, что нельзя проверить тестами: читаемость палитры,
/// характер пружин, силу хаптики и поведение при Reduce Motion / Transparency.
/// На 3-м этапе экран останется в проекте как рабочий инструмент.
struct DesignSystemGalleryView: View {

    @Binding var previewReduceMotion: Bool
    @Binding var previewReduceTransparency: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                header

                AccessibilitySection(
                    previewReduceMotion: $previewReduceMotion,
                    previewReduceTransparency: $previewReduceTransparency
                )

                // ViewBuilder принимает максимум 10 дочерних view,
                // поэтому секции сгруппированы. На вёрстку Group не влияет.
                Group {
                    ColorSection()
                    GradientSection()
                    TypographySection()
                    LayoutSection()
                    ElevationSection()
                }

                Group {
                    MotionSection()
                    HapticsSection()
                    ComponentsSection()
                }

                footer
            }
            .dsScreenPadding()
            .padding(.top, DS.Space.xl)
            .padding(.bottom, DS.Space.huge)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text("MAPA")
                .font(DS.Font.hero)
                .tracking(-1)
                .foregroundStyle(DS.Gradient.accent)

            Text("Дизайн-система · этап 1")
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        Text("Всё, что появится дальше — карта, карточки стран, маршруты — собирается только из этих токенов.")
            .font(DS.Font.caption)
            .foregroundStyle(DS.Color.inkTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DesignSystemGalleryView_Previews: PreviewProvider {
    static var previews: some View {
        RootView().preferredColorScheme(.dark)
    }
}
