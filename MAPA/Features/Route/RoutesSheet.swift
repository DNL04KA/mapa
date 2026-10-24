import SwiftUI

/// Список маршрутов.
///
/// Раньше здесь была строка с названием и корзиной, пока тот же маршрут
/// в панели показывался Колизеем, фотографиями городов и днями. Одна вещь
/// в двух местах должна выглядеть одинаково, иначе приложение кажется
/// собранным из кусков.
@MainActor
struct RoutesSheet: View {

    @Environment(\.dsMotion) private var motion
    @Environment(\.dynamicTypeSize) private var typeSize

    let routes: [Route]
    /// Наброски по странам, которые человек отметил.
    let suggestions: [CountrySuggestion]
    let accent: Color
    let onOpen: (Route) -> Void
    let onCreate: () -> Void
    let onDelete: (Route) -> Void
    let onTakeSuggestion: (CountrySuggestion) -> Void
    let onOpenCommunity: () -> Void
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
            .fill(DS.Color.scrim)
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

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.lg) {
                    if routes.isEmpty {
                        empty
                    } else {
                        mine
                    }
                    if !suggestions.isEmpty {
                        byCountry
                    }
                    community
                }
                .padding(.bottom, DS.Space.xs)
            }
            // Прокрутка занимает всё, что ей дают, поэтому высоту задаём
            // сами: иначе под тремя строками оставалась ладонь пустоты.
            .frame(height: contentHeight)
            .scrollIndicators(.hidden)
            // Нижний край растворяется: обрезанная ровно пополам карточка
            // выглядит сломанной вёрсткой, а не продолжением списка.
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.93),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            PillButton("Новый маршрут", icon: "plus",
                       kind: .tinted(accent), fullWidth: true, action: onCreate)
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

    /// Высота содержимого на глаз, но с потолком: точный расчёт в прокрутке
    /// всё равно невозможен, а пустоты под коротким списком быть не должно.
    private var contentHeight: CGFloat {
        let own = routes.isEmpty ? 120 : CGFloat(routes.count) * 84 + 34
        let country = suggestions.isEmpty ? 0 : CGFloat(suggestions.count) * 84 + 58
        // На крупном шрифте строка занимает полторы высоты, и в прежние
        // четыреста тридцать точек помещалось полторы карточки.
        let ceiling: CGFloat = typeSize.isAccessibilitySize ? 560 : 430
        return min(ceiling, own + country + 210)
    }

    private var panelFill: AnyShapeStyle {
        motion.reduceTransparency
            ? AnyShapeStyle(DS.Color.materialFallback)
            : AnyShapeStyle(.ultraThinMaterial)
    }

    // MARK: - Свои

    private var mine: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            SectionHeader("Твои маршруты")
            ForEach(Array(routes.enumerated()), id: \.element.id) { index, route in
                row(route).dsReveal(index)
            }
        }
    }

    private func row(_ route: Route) -> some View {
        let confirming = confirmingDelete == route.id

        return HStack(spacing: DS.Space.sm) {
            Button {
                if confirming {
                    withAnimation(motion.animation(.snap)) { confirmingDelete = nil }
                } else {
                    onOpen(route)
                }
            } label: {
                HStack(spacing: DS.Space.sm) {
                    cover(route)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(route.displayTitle)
                            .font(DS.Font.subhead)
                            .foregroundStyle(DS.Color.ink)
                            .lineLimit(1)

                        if confirming {
                            Text("Удалить маршрут?")
                                .font(DS.Font.micro)
                                .foregroundStyle(DS.Color.danger)
                        } else {
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
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Удаление в два шага, и второй шаг подписан словами.
            // Маршрут собирают долго, а меняющаяся иконка корзины — слишком
            // тихий вопрос для действия, которое не отменить.
            Button {
                if confirming {
                    onDelete(route)
                    confirmingDelete = nil
                } else {
                    Haptics.shared.warning()
                    withAnimation(motion.animation(.snap)) { confirmingDelete = route.id }
                }
            } label: {
                Group {
                    if confirming {
                        Text("Удалить")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Color.inkOnAccent)
                            .padding(.horizontal, DS.Space.sm)
                            .frame(height: 30)
                            .background(DS.Color.danger, in: Capsule())
                    } else {
                        Image(systemName: "trash")
                            .font(.system(size: DS.Size.iconSm, weight: .semibold))
                            .foregroundStyle(DS.Color.inkTertiary)
                            .frame(width: DS.Size.hitTarget, height: DS.Size.hitTarget)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(confirming ? "Подтвердить удаление" : "Удалить маршрут")
        }
        .padding(DS.Space.xs)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Color.surfaceRaised.opacity(0.5))
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .strokeBorder(confirming ? DS.Color.danger.opacity(0.5) : DS.Color.hairline,
                                      lineWidth: 1)
                }
        }
    }

    /// Снимок первого города маршрута.
    private func cover(_ route: Route) -> some View {
        ZStack {
            Rectangle().fill(accent.opacity(0.12))

            if let photo = CityFacts.cover(for: route.points.first?.cityID) {
                RemoteImage(url: photo.small)
            } else {
                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.system(size: DS.Size.iconSm, weight: .semibold))
                    .foregroundStyle(accent.opacity(0.7))
            }
        }
        .frame(width: 56, height: 56)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
    }

    // MARK: - По странам

    /// Наброски по отмеченным странам.
    ///
    /// Раньше они жили только внутри карточки страны, и найти их можно было
    /// лишь случайно. Искать маршрут человек идёт сюда — здесь им и место.
    private var byCountry: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            SectionHeader("По странам", subtitle: String(localized: "Собрано из главных городов"))

            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                Button {
                    onTakeSuggestion(suggestion)
                } label: {
                    HStack(spacing: DS.Space.sm) {
                        ZStack {
                            Rectangle().fill(accent.opacity(0.12))
                            if let photo = suggestion.stops.first?.photo {
                                RemoteImage(url: photo.small)
                            }
                        }
                        .frame(width: 56, height: 56)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.country.displayName)
                                .font(DS.Font.subhead)
                                .foregroundStyle(DS.Color.ink)
                                .lineLimit(1)

                            Text(Plural.cities(suggestion.stops.count)
                                 + " · " + Plural.days(suggestion.totalDays))
                                .font(DS.Font.micro)
                                .foregroundStyle(DS.Color.inkTertiary)
                                .monospacedDigit()
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "plus.circle")
                            .font(.system(size: DS.Size.iconSm, weight: .semibold))
                            .foregroundStyle(accent)
                            .padding(.trailing, DS.Space.xs)
                    }
                    .padding(DS.Space.xs)
                    .background {
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .fill(DS.Color.surfaceRaised.opacity(0.5))
                            .overlay {
                                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                    .strokeBorder(DS.Color.hairline, lineWidth: 1)
                            }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .dsReveal(index)
                .accessibilityLabel("Взять маршрут по стране: \(suggestion.country.displayName)")
            }
        }
    }

    // MARK: - Пусто и сообщество

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

    /// Раздел сообщества.
    ///
    /// Заполнять его выдуманными маршрутами выдуманных людей я не стал:
    /// человек начнёт их сохранять и планировать по ним поездку, а они
    /// ненастоящие. Пустой раздел честнее и заодно объясняет, чего ждать.
    /// Вход в сообщество.
    ///
    /// Раньше здесь висела заглушка «пока никого нет». Теперь это дверь:
    /// за ней топ маршрутов по оценкам и люди, которые их собрали. Если
    /// сервер не подключён, об этом честно скажет тот экран, а не этот.
    private var community: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            SectionHeader("Сообщество")

            Button(action: onOpenCommunity) {
                HStack(spacing: DS.Space.sm) {
                    Image(systemName: "trophy")
                        .font(.system(size: DS.Size.iconMd, weight: .medium))
                        .foregroundStyle(accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Лучшие маршруты и люди")
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Color.ink)
                            .lineLimit(1)
                        Text("Топ по оценкам тех, кто уже съездил")
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
    }

    private func subtitle(_ route: Route) -> String {
        if route.isComplete { return String(localized: "Пройден целиком") }
        if route.isInProgress {
            return String(format: NSLocalizedString("%@ из %@ пройдено", comment: ""),
                          "\(route.visitedCount)", "\(route.points.count)")
        }
        var parts = [Plural.cities(route.points.count)]
        if route.totalDays > 0 {
            parts.append(Plural.days(route.totalDays))
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
