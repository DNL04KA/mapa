import PhotosUI
import SwiftUI

/// Панель открытого маршрута.
///
/// Одна панель на два состояния, а не два экрана. Свёрнутая — тонкая полоса
/// с итогами: карта остаётся открытой, и точки добавляются тапом по городам.
/// Развёрнутая — редактор с порядком, днями и отзывами.
/// Если развести их по экранам, между «собрать» и «поправить» появится переход,
/// а это ровно то место, где маршрут бросают недоделанным.
@MainActor
struct RoutePanel: View {

    @Environment(\.dsMotion) private var motion

    let route: Route
    let accent: Color
    @Binding var isExpanded: Bool

    let onRemovePoint: (RoutePoint) -> Void
    let onMovePoint: (Int, Int) -> Void
    let onTogglePassed: (RoutePoint) -> Void
    let onSetPhoto: (RoutePoint, UIImage?) -> Void
    let onChangeDays: (RoutePoint, Int) -> Void
    let onSetStartDate: (Date?) -> Void
    let onRename: (String) -> Void
    let onSetStatus: (JourneyStatus) -> Void
    let onRate: (Int, String) -> Void
    let onRemoveReview: () -> Void
    let onDone: () -> Void

    @State private var draggingID: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var isComposing = false
    @State private var draftRating = 5
    @State private var draftText = ""
    @State private var photoTarget: RoutePoint?
    @State private var photoItem: PhotosPickerItem?
    @State private var isPickingPhoto = false
    @State private var draftTitle = ""
    @FocusState private var titleFocused: Bool

    private let rowHeight: CGFloat = 104

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            panel
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var panel: some View {
        VStack(spacing: DS.Space.md) {
            summary

            if isExpanded {
                Divider().overlay(DS.Color.hairline)

                // Прокрутка обязательна: десяток точек плюс отзывы не влезут
                // ни в какой экран, а «Готово» должно остаться на виду.
                // Оценка стоит до точек, а не после них.
                // Пять городов — это больше пятисот точек высоты, и всё, что
                // лежало под ними, человек просто не находил: отзывы были
                // написаны, но для него их не существовало.
                header
                dates

                // Оценка — у пройденной поездки и ни у какой другой.
                // Ставить звёзды плану, в который ещё не съездил, не
                // значит ничего: оценивают то, что уже случилось.
                if route.status == .completed {
                    ratingBar
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Space.md) {
                        points
                        if route.status == .completed {
                            reviews
                        }
                    }
                    .padding(.bottom, DS.Space.xs)
                }
                .frame(maxHeight: 420)
                .scrollIndicators(.hidden)
            }

            PillButton(route.points.count >= 2 ? "Готово" : "Закрыть",
                       kind: .tinted(accent), fullWidth: true, action: onDone)
        }
        .padding(.horizontal, DS.Space.screen)
        .padding(.top, DS.Space.sm)
        .padding(.bottom, DS.Space.xl)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedTopShape(radius: DS.Radius.xl)
                .fill(panelFill)
                .overlay {
                    // Тонкое стекло поверх светлой карты давало мутно-серый
                    // фон: белый текст на нём тонул, а фотографии выцветали.
                    // Плотная тёмная подложка возвращает и контраст, и глубину.
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
        .transition(.move(edge: .bottom))
    }

    private var panelFill: AnyShapeStyle {
        motion.reduceTransparency
            ? AnyShapeStyle(DS.Color.materialFallback)
            : AnyShapeStyle(.ultraThinMaterial)
    }

    // MARK: - Итоги

    private var summary: some View {
        Button {
            Haptics.shared.tap(.light)
            withAnimation(motion.animation(.smooth)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: DS.Space.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(route.displayTitle)
                        .font(DS.Font.subhead)
                        .foregroundStyle(DS.Color.ink)
                        .lineLimit(1)

                    Text(totalsText)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.inkTertiary)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)

                if let average = route.averageRating {
                    HStack(spacing: DS.Space.xxs) {
                        RatingStars(value: average, size: 12, tint: accent)
                        Text(String(format: "%.1f", average))
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Color.inkSecondary)
                            .monospacedDigit()
                    }
                }

                Image(systemName: "chevron.up")
                    .font(.system(size: DS.Size.glyph, weight: .bold))
                    .foregroundStyle(DS.Color.inkTertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .frame(minHeight: DS.Size.hitTarget)
            .overlay(alignment: .bottom) { progressLine }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Тонкая полоса прогресса под заголовком. Появляется только когда
    /// есть что показывать — у нетронутого маршрута её нет.
    @ViewBuilder
    private var progressLine: some View {
        if route.visitedCount > 0 {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DS.Color.hairline)
                    Capsule()
                        .fill(accent)
                        .frame(width: proxy.size.width * CGFloat(route.visitedCount) / CGFloat(max(route.points.count, 1)))
                        .animation(motion.animation(.smooth), value: route.visitedCount)
                }
            }
            .frame(height: 2)
        }
    }

    private var totalsText: String {
        guard !route.points.isEmpty else {
            return String(localized: "Коснись страны, затем города")
        }

        // Начатый маршрут в первую очередь про прогресс, а не про километры.
        if route.visitedCount > 0 {
            // Строка собирается здесь, а не в `Text`, и переводится тоже
            // здесь: `Text(String)` перевода не делает.
            var parts = [String(format: NSLocalizedString("%@ из %@ пройдено", comment: ""),
                                "\(route.visitedCount)", "\(route.points.count)")]
            if route.totalDays > 0 {
                parts.append(Plural.days(route.totalDays))
            }
            return parts.joined(separator: " · ")
        }

        var parts = [Plural.points(route.points.count)]
        if route.totalDays > 0 {
            parts.append(Plural.days(route.totalDays))
        }
        if route.totalDistanceKm > 1 {
            parts.append(String(format: NSLocalizedString("%@ км", comment: ""),
                                "\(Int(route.totalDistanceKm))"))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Шапка редактора

    /// Имя поездки и её состояние.
    ///
    /// Имя правится здесь, а не в свёрнутой полосе: та живёт поверх карты
    /// и нужна для «где я остановился», а не для редактуры. Состояние
    /// стоит рядом с именем, потому что это одно решение — «что это за
    /// поездка и что с ней сейчас».
    private var header: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            TextField("Название", text: $draftTitle)
                .font(DS.Font.headline)
                .foregroundStyle(DS.Color.ink)
                .focused($titleFocused)
                .submitLabel(.done)
                .onSubmit(commitTitle)
                .onChange(of: titleFocused) { focused in
                    if !focused { commitTitle() }
                }
                .padding(.horizontal, DS.Space.sm)
                .frame(height: DS.Size.controlHeight)
                .dsGlass(radius: DS.Radius.md, shadow: .low)
                .accessibilityLabel("Название маршрута")

            statusRow

            if let suggested = route.suggestedStatus() {
                suggestion(suggested)
            }
        }
        .onAppear { draftTitle = route.title }
        .onChange(of: route.id) { _ in draftTitle = route.title }
    }

    private var statusRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Space.xs) {
                ForEach(JourneyStatus.allCases) { status in
                    statusChip(status)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func statusChip(_ status: JourneyStatus) -> some View {
        let isOn = route.status == status
        return Button {
            Haptics.shared.tap(.light)
            onSetStatus(status)
        } label: {
            HStack(spacing: DS.Space.xxs) {
                Image(systemName: status.icon)
                    .font(.system(size: DS.Size.glyphSm, weight: .semibold))
                Text(status.title)
                    .font(DS.Font.caption)
            }
            .foregroundStyle(isOn ? DS.Color.inkOnAccent : DS.Color.inkSecondary)
            .padding(.horizontal, DS.Space.sm)
            .frame(height: 32)
            .background {
                Capsule().fill(isOn ? AnyShapeStyle(accent) : AnyShapeStyle(DS.Color.surfaceRaised.opacity(0.6)))
            }
            .overlay {
                Capsule().strokeBorder(isOn ? Color.clear : DS.Color.hairline, lineWidth: 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    /// Предложение сменить состояние.
    ///
    /// Приложение видит, что даты прошли или все точки пройдены, но
    /// переключать само не станет: поездку могли отменить или перенести.
    /// Поэтому это строка с кнопкой, а не молчаливое изменение.
    private func suggestion(_ status: JourneyStatus) -> some View {
        HStack(spacing: DS.Space.xs) {
            Image(systemName: status.icon)
                .font(.system(size: DS.Size.glyphSm, weight: .semibold))
                .foregroundStyle(accent)

            Text(suggestionText(for: status))
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                Haptics.shared.tap(.light)
                onSetStatus(status)
            } label: {
                Text("Отметить")
                    .font(DS.Font.caption)
                    .foregroundStyle(accent)
                    .padding(.horizontal, DS.Space.sm)
                    .frame(height: 30)
                    .background { Capsule().fill(accent.opacity(0.12)) }
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Space.sm)
        .dsGlass(radius: DS.Radius.md, shadow: .low)
    }

    private func suggestionText(for status: JourneyStatus) -> LocalizedStringKey {
        switch status {
        case .inProgress: return "Похоже, поездка началась"
        case .completed:  return "Похоже, поездка позади"
        case .planned:    return "Даты есть — можно считать запланированной"
        default:          return "Можно сменить состояние"
        }
    }

    /// Пустое имя не записываем: у маршрута есть расчётное название из
    /// первого и последнего города, и оно лучше пустой строки.
    private func commitTitle() {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != route.title else { return }
        onRename(trimmed)
        draftTitle = trimmed
    }

    // MARK: - Даты

    /// Когда едем.
    ///
    /// Пока даты нет, маршрут — это порядок городов и ничего больше: ни
    /// «сколько осталось», ни билета, ни брони. Поэтому строка стоит до
    /// точек, а не в конце списка, и у неё единственное действие.
    @ViewBuilder
    private var dates: some View {
        if !route.points.isEmpty {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: "calendar")
                    .font(.system(size: DS.Size.glyph, weight: .semibold))
                    .foregroundStyle(accent)

                if route.startDate == nil {
                    Text("Без дат")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.inkTertiary)

                    Spacer(minLength: 0)

                    Button {
                        Haptics.shared.tap(.light)
                        onSetStartDate(Calendar.current.startOfDay(for: Date()))
                    } label: {
                        Text("Назначить")
                            .font(DS.Font.caption)
                            .foregroundStyle(accent)
                            .padding(.horizontal, DS.Space.sm)
                            .frame(height: 30)
                            .background { Capsule().fill(accent.opacity(0.12)) }
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Назначить даты маршрута")
                } else {
                    DatePicker(
                        "Выезд",
                        selection: Binding(
                            get: { route.startDate ?? Date() },
                            set: { onSetStartDate(Calendar.current.startOfDay(for: $0)) }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(accent)

                    if let range = rangeText {
                        Text(range)
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Color.inkSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }

                    Spacer(minLength: 0)

                    Button {
                        Haptics.shared.tap(.soft)
                        onSetStartDate(nil)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: DS.Size.glyphSm, weight: .bold))
                            .foregroundStyle(DS.Color.inkTertiary)
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Убрать даты")
                }
            }
            .frame(minHeight: DS.Size.hitTarget)
        }
    }

    /// «по 26 марта» — когда вернёшься. День выезда виден в самом выборе
    /// даты, повторять его второй раз незачем.
    private var rangeText: String? {
        guard let end = route.endDate() else { return nil }
        return String(format: NSLocalizedString("по %@", comment: ""), TripDateFormat.day(end))
    }

    // MARK: - Точки

    @ViewBuilder
    private var points: some View {
        if route.points.isEmpty {
            Text("Коснись страны на карте — появятся её города. Тап по городу добавит его в маршрут.")
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // Расписание считается один раз на список, а не в каждой
            // строке: `body` зовут часто, а дат столько же, сколько точек.
            let schedule = route.schedule()

            VStack(spacing: 0) {
                ForEach(Array(route.points.enumerated()), id: \.element.id) { index, point in
                    row(point, at: index, stay: schedule.indices.contains(index) ? schedule[index] : nil)
                        .dsReveal(index)
                        .offset(y: offset(for: index))
                        .zIndex(point.id == draggingID ? 1 : 0)
                }
            }
            .animation(motion.animation(.snap), value: draggingID)
        }
    }

    private func row(_ point: RoutePoint, at index: Int, stay: Route.Stay?) -> some View {
        HStack(alignment: .top, spacing: DS.Space.xs) {
            // Номер с пунктиром — то же, что в ленте по стране. Список точек
            // и маршрут по стране это одна и та же вещь в двух местах, и
            // выглядеть они должны одинаково.
            rail(point, at: index, isLast: index == route.points.count - 1)

            photo(point)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: DS.Space.xs) {
                    Text(point.name)
                        .font(DS.Font.subhead)
                        .foregroundStyle(point.isVisited ? DS.Color.inkSecondary : DS.Color.ink)
                        .strikethrough(point.isVisited, color: DS.Color.inkTertiary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Button {
                        onRemovePoint(point)
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: DS.Size.iconSm, weight: .semibold))
                            .foregroundStyle(DS.Color.inkTertiary)
                            .frame(width: 26, height: 26)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Убрать \(point.name)")
                }

                HStack(spacing: DS.Space.xs) {
                    if let arrival = stay?.arrival {
                        // Дата вытесняет страну, а не добавляется к ней:
                        // строка узкая, а «когда» в поездке важнее, чем
                        // «в какой стране» — страна и так видна на карте.
                        Text(TripDateFormat.day(arrival))
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.inkSecondary)
                            .monospacedDigit()
                    } else if let country = point.countryName {
                        Text(country)
                            .font(DS.Font.micro)
                            .foregroundStyle(DS.Color.inkSecondary)
                    }
                    daysStepper(point)
                }

                // Достопримечательности прямо в строке маршрута: иначе, чтобы
                // вспомнить, зачем ты добавил город, надо уходить в карточку.
                if let landmarks = CityFacts.summary(for: point.cityID) {
                    Text(landmarks)
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.inkSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text("Что смотреть — расскажут те, кто был")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.inkTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.top, 2)

            // Ручка перетаскивания отдельно от карточки: если тащить за всю
            // строку, невозможно нажать «минус», шаг дней и фото.
            Image(systemName: "line.3.horizontal")
                .font(.system(size: DS.Size.iconSm, weight: .semibold))
                .foregroundStyle(DS.Color.inkTertiary)
                .frame(width: 26, height: rowHeight)
                .contentShape(Rectangle())
                .gesture(dragGesture(for: point, at: index))
                .accessibilityLabel("Переставить \(point.name)")
        }
        .padding(.vertical, DS.Space.xs)
        .frame(height: rowHeight)
    }

    /// Кружок с номером, он же отметка «пройдено».
    private func passMark(_ point: RoutePoint, at index: Int) -> some View {
        Button {
            onTogglePassed(point)
        } label: {
            ZStack {
                Circle()
                    .fill(point.isVisited ? accent : Color.clear)
                    .overlay {
                        Circle().strokeBorder(
                            point.isVisited ? Color.clear : DS.Color.border,
                            lineWidth: 1.5
                        )
                    }

                if point.isVisited {
                    Image(systemName: "checkmark")
                        .font(.system(size: DS.Size.glyphSm, weight: .bold))
                        .foregroundStyle(DS.Color.inkOnAccent)
                } else {
                    Text("\(index + 1)")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.inkSecondary)
                }
            }
            .frame(width: 22, height: 22)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(point.isVisited ? "\(point.name), пройдено" : "\(point.name), точка \(index + 1)")
        .accessibilityHint(point.isVisited ? "Снять отметку" : "Отметить пройденной")
    }

    /// Номер точки и пунктир до следующей.
    private func rail(_ point: RoutePoint, at index: Int, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            passMark(point, at: index)

            if !isLast {
                DashedLine()
                    .stroke(accent.opacity(0.45),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 5]))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 22)
        .padding(.top, 4)
    }

    private func photo(_ point: RoutePoint) -> some View {
        Button {
            photoTarget = point
            isPickingPhoto = true
        } label: {
            // Размер держит подложка, картинка и значок ложатся поверх неё.
            // Внутри стопки картинка с `.fill` раздувала бы её собой, и значок
            // уезжал бы за обрезку — на части карточек он так и пропадал.
            Rectangle()
                .fill(accent.opacity(0.10))
                .frame(width: 72, height: 72)
                .overlay {
                    if let id = point.photoID, let image = PhotoStore.routes.image(id: id) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else if let cover = CityFacts.cover(for: point.cityID) {
                        // Пока своего снимка нет — показываем город таким, какой
                        // он есть, а не серый квадрат.
                        RemoteImage(url: cover.small)
                    } else {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: DS.Size.iconMd, weight: .light))
                            .foregroundStyle(accent.opacity(0.7))
                    }
                }
                .clipped()
                .overlay(alignment: .bottomTrailing) {
                    // Плюс нужен только там, где снимок чужой: он говорит,
                    // что место ждёт твою фотографию.
                    if point.photoID == nil, CityFacts.cover(for: point.cityID) != nil {
                        plusBadge
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .strokeBorder(DS.Color.hairline, lineWidth: 1)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(point.photoID == nil ? "Добавить фото: \(point.name)" : "Фото: \(point.name)")
    }

    private var plusBadge: some View {
        Image(systemName: "plus")
            .font(.system(size: DS.Size.glyphSm, weight: .bold))
            .foregroundStyle(.white)
            .padding(4)
            .background(DS.Palette.void.opacity(0.55), in: Circle())
            .padding(4)
    }

    private func daysStepper(_ point: RoutePoint) -> some View {
        HStack(spacing: DS.Space.xxs) {
            stepperButton("minus", enabled: point.days > 1) {
                onChangeDays(point, point.days - 1)
            }

            Text("\(point.days)")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.ink)
                .monospacedDigit()
                .frame(minWidth: 16)

            stepperButton("plus", enabled: point.days < 60) {
                onChangeDays(point, point.days + 1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Дней в \(point.name): \(point.days)")
    }

    private func stepperButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.shared.tap(.soft)
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: DS.Size.glyphSm, weight: .bold))
                .foregroundStyle(enabled ? accent : DS.Color.inkTertiary.opacity(0.4))
                .frame(width: 24, height: 24)
                .background {
                    Circle().fill(enabled ? accent.opacity(0.12) : Color.clear)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: - Перетаскивание

    private func dragGesture(for point: RoutePoint, at index: Int) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if draggingID != point.id {
                    draggingID = point.id
                    Haptics.shared.tap(.soft)
                }
                dragOffset = value.translation.height
            }
            .onEnded { _ in
                let target = targetIndex(from: index)
                if target != index { onMovePoint(index, target) }
                draggingID = nil
                dragOffset = 0
            }
    }

    /// Куда встанет строка, если отпустить сейчас.
    private func targetIndex(from index: Int) -> Int {
        let shift = Int((dragOffset / rowHeight).rounded())
        return min(max(index + shift, 0), route.points.count - 1)
    }

    /// Сдвиг строки: перетаскиваемая едет за пальцем, остальные расступаются.
    private func offset(for index: Int) -> CGFloat {
        guard let draggingID,
              let from = route.points.firstIndex(where: { $0.id == draggingID })
        else { return 0 }

        if index == from { return dragOffset }

        let to = targetIndex(from: from)
        if from < to, index > from, index <= to { return -rowHeight }
        if from > to, index < from, index >= to { return rowHeight }
        return 0
    }

    // MARK: - Отзывы

    @ViewBuilder
    /// Оценка одним касанием.
    ///
    /// Раньше поставить её можно было только через форму с текстом, и
    /// большинство маршрутов так и оставались без оценки: писать отзыв ради
    /// четырёх звёзд никто не станет. Звёзды принимают оценку сразу, а текст
    /// остаётся отдельным добровольным шагом.
    private var ratingBar: some View {
        HStack(spacing: DS.Space.sm) {
            Text(route.myReview == nil ? "Оценить маршрут" : "Твоя оценка")
                .font(DS.Font.callout)
                .foregroundStyle(route.myReview == nil ? DS.Color.inkSecondary : DS.Color.ink)

            Spacer(minLength: 0)

            RatingStars(
                value: Double(route.myReview?.rating ?? 0),
                size: 17,
                tint: accent,
                onSelect: { rating in
                    onRate(rating, route.myReview?.text ?? "")
                }
            )
        }
        .padding(.horizontal, DS.Space.sm)
        .padding(.vertical, DS.Space.xs)
        .background {
            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                .fill(DS.Color.surfaceSunken.opacity(0.5))
        }
    }

    private var reviews: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            SectionHeader("Отзывы", subtitle: reviewsSubtitle)

            if isComposing {
                composer
            } else {
                Button {
                    draftRating = route.myReview?.rating ?? 5
                    draftText = route.myReview?.text ?? ""
                    withAnimation(motion.animation(.smooth)) { isComposing = true }
                } label: {
                    HStack(spacing: DS.Space.xs) {
                        Image(systemName: route.myReview == nil ? "star" : "pencil")
                            .font(.system(size: DS.Size.iconSm, weight: .semibold))
                        Text(route.myReview == nil ? "Оценить маршрут" : "Изменить свой отзыв")
                    }
                    .font(DS.Font.callout)
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: DS.Size.hitTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            ForEach(route.reviews) { review in
                reviewRow(review)
            }
        }
    }

    private var reviewsSubtitle: String? {
        guard let average = route.averageRating else {
            return String(localized: "Пока никто не оценивал")
        }
        return String(format: "%.1f · ", average)
            + Plural.reviews(route.reviews.count)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            RatingStars(value: Double(draftRating), size: 22, tint: accent) { draftRating = $0 }

            // Своё текстовое поле, а не TextEditor: у системного нет плейсхолдера
            // и он тащит собственный фон, который не вписывается в стекло.
            ZStack(alignment: .topLeading) {
                if draftText.isEmpty {
                    Text("Что стоит знать тому, кто поедет за тобой?")
                        .font(DS.Font.callout)
                        .foregroundStyle(DS.Color.inkTertiary)
                        .padding(.horizontal, DS.Space.xs)
                        .padding(.vertical, DS.Space.xs + 2)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $draftText)
                    .font(DS.Font.callout)
                    .foregroundStyle(DS.Color.ink)
                    .scrollContentBackground(.hidden)
                    .frame(height: 72)
                    .padding(.horizontal, DS.Space.xxs)
            }
            .background(DS.Color.surfaceSunken.opacity(0.5))
            .dsRounded(DS.Radius.sm)

            HStack(spacing: DS.Space.xs) {
                PillButton("Сохранить", kind: .primary, fullWidth: true) {
                    onRate(draftRating, draftText.trimmingCharacters(in: .whitespacesAndNewlines))
                    withAnimation(motion.animation(.smooth)) { isComposing = false }
                }

                if route.myReview != nil {
                    Button {
                        onRemoveReview()
                        withAnimation(motion.animation(.smooth)) { isComposing = false }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: DS.Size.iconSm, weight: .semibold))
                            .foregroundStyle(DS.Color.danger)
                            .frame(width: DS.Size.controlHeight, height: DS.Size.controlHeight)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Удалить отзыв")
                }
            }
        }
    }

    private func reviewRow(_ review: RouteReview) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            HStack(spacing: DS.Space.xs) {
                Text(review.authorName)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.ink)

                RatingStars(value: Double(review.rating), size: 11, tint: accent)

                Spacer(minLength: 0)

                Text(Self.dateFormatter.string(from: review.createdAt))
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.inkTertiary)
            }

            if !review.text.isEmpty {
                Text(review.text)
                    .font(DS.Font.callout)
                    .foregroundStyle(DS.Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlass(radius: DS.Radius.sm, shadow: .low)
        .accessibilityElement(children: .combine)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter
    }()
}

/// Вертикальная линия сверху вниз — для пунктира между точками.
private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}
