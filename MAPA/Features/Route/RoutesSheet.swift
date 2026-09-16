import SwiftUI

/// Список сохранённых маршрутов.
@MainActor
struct RoutesSheet: View {

    @Environment(\.dsMotion) private var motion

    let routes: [Route]
    let accent: Color
    let onOpen: (Route) -> Void
    let onCreate: () -> Void
    let onDelete: (Route) -> Void
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var confirmingDelete: UUID?

    var body: some View {
        ZStack(alignment: .bottom) {
            scrim
            panel
        }
        .ignoresSafeArea()
    }

    private var scrim: some View {
        Rectangle()
            .fill(DS.Palette.void.opacity(0.4))
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .transition(.opacity)
            .accessibilityLabel("Закрыть маршруты")
            .accessibilityAddTraits(.isButton)
    }

    private var panel: some View {
        VStack(spacing: DS.Space.md) {
            Capsule()
                .fill(DS.Color.borderStrong)
                .frame(width: 38, height: 4)

            Text("Маршруты")
                .font(DS.Font.title)
                .foregroundStyle(DS.Color.ink)

            if routes.isEmpty {
                empty
            } else {
                ScrollView {
                    VStack(spacing: DS.Space.xs) {
                        ForEach(routes) { route in
                            row(route)
                        }
                    }
                }
                .frame(maxHeight: 360)
                .scrollIndicators(.hidden)
            }

            PillButton("Новый маршрут", icon: "plus", kind: .primary, fullWidth: true, action: onCreate)
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

    private var empty: some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Text("Маршрутов пока нет")
                .font(DS.Font.headline)
                .foregroundStyle(DS.Color.ink)
            Text("Маршрут — это города по порядку: куда сначала, куда потом и на сколько дней.")
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlass(radius: DS.Radius.md, shadow: .low)
    }

    private func row(_ route: Route) -> some View {
        HStack(spacing: DS.Space.sm) {
            Button {
                onOpen(route)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(route.displayTitle)
                        .font(DS.Font.subhead)
                        .foregroundStyle(DS.Color.ink)
                        .lineLimit(1)

                    HStack(spacing: DS.Space.xs) {
                        Text(subtitle(route))
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.inkTertiary)
                            .monospacedDigit()

                        if let average = route.averageRating {
                            RatingStars(value: average, size: 10, tint: accent)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Удаление в два шага: маршрут собирают долго, и случайный тап
            // по корзине не должен стирать работу без вопроса.
            Button {
                if confirmingDelete == route.id {
                    onDelete(route)
                    confirmingDelete = nil
                } else {
                    Haptics.shared.warning()
                    withAnimation(motion.animation(.snap)) { confirmingDelete = route.id }
                }
            } label: {
                Image(systemName: confirmingDelete == route.id ? "trash.fill" : "trash")
                    .font(.system(size: DS.Size.iconSm, weight: .semibold))
                    .foregroundStyle(confirmingDelete == route.id ? DS.Color.danger : DS.Color.inkTertiary)
                    .frame(width: DS.Size.hitTarget, height: DS.Size.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(confirmingDelete == route.id ? "Подтвердить удаление" : "Удалить маршрут")
        }
        .padding(.horizontal, DS.Space.sm)
        .frame(minHeight: DS.Size.hitTarget + 8)
        .dsGlass(radius: DS.Radius.sm, shadow: .low)
    }

    private func subtitle(_ route: Route) -> String {
        var parts = [Plural.format(route.points.count, "точка", "точки", "точек")]
        if route.totalDays > 0 {
            parts.append(Plural.format(route.totalDays, "день", "дня", "дней"))
        }
        return parts.joined(separator: " · ")
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
