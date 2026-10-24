import SwiftUI

/// Панель города.
///
/// Короче страничной карточки: у города пока нет ни описания, ни фотографий —
/// есть имя, размер и расстояние. Раздувать её ради объёма незачем.
@MainActor
struct CitySheet: View {

    @Environment(\.dsMotion) private var motion

    let city: City
    let countryName: String?
    let home: HomePlace?
    let isHome: Bool
    let accent: Color
    let onSetHome: () -> Void
    /// Открыть страну, в которой город стоит.
    let onOpenCountry: () -> Void
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var preview: Landmark?

    var body: some View {
        ZStack(alignment: .bottom) {
            scrim
            panel
        }
        .ignoresSafeArea()
        .photoViewer($preview)
        #if DEBUG
        // Снять открытую фотографию симулятором иначе нельзя: нажимать
        // ему нечем. Только отладочная сборка.
        .onAppear {
            guard ProcessInfo.processInfo.environment["MAPA_PHOTO"] == "1" else { return }
            preview = CityFacts.landmarks(for: city.id).first { $0.small != nil }
        }
        #endif
    }

    private var scrim: some View {
        Rectangle()
            .fill(DS.Color.scrim)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .transition(.opacity)
            .accessibilityLabel("Закрыть город")
            .accessibilityAddTraits(.isButton)
    }

    private var panel: some View {
        VStack(spacing: DS.Space.md) {
            Capsule()
                .fill(DS.Color.borderStrong)
                .frame(width: 38, height: 4)

            header
            walk
            facts
            actions
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

    private var header: some View {
        VStack(spacing: DS.Space.xxs) {
            Text(city.displayName)
                .font(DS.Font.title)
                .foregroundStyle(DS.Color.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.6)

            HStack(spacing: DS.Space.xs) {
                if let countryName {
                    Text(countryName)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.inkTertiary)
                }
                if city.isCapital {
                    Text("столица")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.inkOnAccent)
                        .padding(.horizontal, DS.Space.xs)
                        .padding(.vertical, 2)
                        .background(accent)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// Прогулка по городу.
    ///
    /// Не просто список мест, а порядок, в котором их обходят: от центра к
    /// ближайшему, потом к ближайшему из оставшихся. Ради этого в городе и
    /// оказываешься — а «начать отсюда маршрут по стране» здесь было не к
    /// месту и занимало половину панели.
    ///
    /// Под каждым снимком стоит имя автора и лицензия. Это не мелкий шрифт
    /// ради приличия: фотографии с Викисклада можно показывать именно при
    /// условии, что автора назвали.
    @ViewBuilder
    private var walk: some View {
        let plan = CityWalk.plan(for: city)
        let steps = plan.steps.filter { $0.place.small != nil }

        if !steps.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                SectionHeader("Что посмотреть", subtitle: walkSubtitle(plan))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: DS.Space.sm) {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            stepTile(step, number: index + 1)
                        }
                    }
                    .padding(.horizontal, DS.Space.screen)
                }
                .padding(.horizontal, -DS.Space.screen)
            }
        } else {
            let places = CityFacts.landmarks(for: city.id)
            if !places.isEmpty {
                Text(places.map(\.name).joined(separator: " · "))
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// «4 места · 5 км пешком». Расстояние показываем, только если оно
    /// посчитано по настоящим координатам всех точек.
    private func walkSubtitle(_ plan: CityWalk.Plan) -> String? {
        let places = Plural.places(plan.steps.count)
        guard !plan.isEmpty, plan.distance > 0.3,
              plan.steps.allSatisfy({ $0.place.coordinate != nil }) else { return places }
        return places + " · " + String(format: NSLocalizedString("%@ км пешком", comment: ""),
                                       Self.walkFormatter.string(
                                        from: NSNumber(value: plan.distance)) ?? "")
    }

    private func stepTile(_ step: CityWalk.Step, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            // Снимок открывается целиком: разглядывать Колизей в полтораста
            // точек нечестно по отношению и к Колизею, и к человеку.
            Button {
                Haptics.shared.tap(.light)
                withAnimation(motion.animation(.smooth)) { preview = step.place }
            } label: {
                ZStack(alignment: .topLeading) {
                    ZStack {
                        Rectangle().fill(accent.opacity(0.10))
                        RemoteImage(url: step.place.small)
                    }
                    .frame(width: 152, height: 104)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            .strokeBorder(DS.Color.hairline, lineWidth: 1)
                    }

                    Text("\(number)")
                        .font(DS.Font.micro)
                        .foregroundStyle(DS.Color.inkOnAccent)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(accent))
                        .padding(6)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(number). \(step.place.name)")
            .accessibilityHint("Открыть фотографию")

            Text(step.place.name)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.ink)
                .lineLimit(1)

            if let credit = step.place.credit {
                // Две строки, а не одна: обрезанное имя автора — это уже
                // не указание авторства.
                Text(credit)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.inkTertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 152, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var facts: some View {
        HStack(spacing: DS.Space.sm) {
            fact(
                value: Self.populationFormatter.string(from: NSNumber(value: city.population)) ?? "—",
                caption: "человек",
                icon: "person.2"
            )

            if let distance = distanceFromHome {
                fact(value: distance, caption: "от дома", icon: "arrow.triangle.swap")
            } else {
                fact(value: city.name, caption: "на карте", icon: "textformat")
            }
        }
    }

    /// Подпись — ключ перевода, а не строка: `Text(String)` ничего не
    /// переводит, и на английском телефоне под числом стояло «человек»
    /// при готовом переводе в таблице.
    private func fact(value: String, caption: LocalizedStringKey, icon: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Image(systemName: icon)
                .font(.system(size: DS.Size.iconSm, weight: .semibold))
                .foregroundStyle(accent)

            Text(value)
                .font(DS.Font.subhead)
                .foregroundStyle(DS.Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(caption)
                .font(DS.Font.micro)
                .foregroundStyle(DS.Color.inkTertiary)
        }
        .padding(DS.Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlass(radius: DS.Radius.sm, shadow: .low)
        .accessibilityElement(children: .combine)
    }

    /// `nil`, если дома нет или дом — это и есть текущий город.
    private var distanceFromHome: String? {
        guard let home, !isHome else { return nil }
        let kilometres = city.distance(to: home.coordinate)
        guard kilometres > 1 else { return nil }
        return "\(Self.distanceFormatter.string(from: NSNumber(value: Int(kilometres))) ?? "") км"
    }

    /// Что отсюда можно сделать.
    ///
    /// Две негромкие кнопки, а не одна большая: главное на этом экране —
    /// места и порядок их обхода, а не кнопка. «Начать маршрут по стране»
    /// отсюда убрана совсем: в городе она была не к месту и занимала
    /// половину панели. Маршрут по-прежнему собирается касаниями по карте,
    /// когда он открыт.
    private var actions: some View {
        DS.Reflow(spacing: DS.Space.xs) {
            smallButton(countryName ?? String(localized: "Страна"),
                        icon: "map", action: onOpenCountry)
            smallButton(isHome ? String(localized: "Твой дом здесь")
                               : String(localized: "Сделать домом"),
                        icon: isHome ? "house.fill" : "house",
                        isOn: isHome,
                        action: onSetHome)
        }
    }

    private func smallButton(_ title: String, icon: String, isOn: Bool = false,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Space.xxs) {
                Image(systemName: icon)
                    .font(.system(size: DS.Size.iconSm, weight: .semibold))
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(DS.Font.caption)
            .foregroundStyle(isOn ? DS.Gradient.statusForeground(.living) : DS.Color.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: DS.Size.hitTarget)
            .background {
                if isOn {
                    DS.Gradient.status(.living)
                } else if motion.reduceTransparency {
                    DS.Color.surfaceRaised
                } else {
                    Rectangle().fill(.ultraThinMaterial)
                }
            }
            .clipShape(Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(isOn ? Color.white.opacity(0.35) : DS.Color.border, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isOn)
    }

    private var homeButton: some View {
        Button(action: onSetHome) {
            HStack(spacing: DS.Space.xs) {
                Image(systemName: isHome ? "house.fill" : "house")
                    .font(.system(size: DS.Size.iconSm, weight: .semibold))
                Text(isHome ? "Твой дом здесь" : "Сделать домом")
            }
            .font(DS.Font.subhead)
            .foregroundStyle(isHome ? DS.Gradient.statusForeground(.living) : DS.Color.ink)
            .frame(maxWidth: .infinity)
            .frame(height: DS.Size.hitTarget)
            .background {
                if isHome {
                    DS.Gradient.status(.living)
                } else if motion.reduceTransparency {
                    DS.Color.surfaceRaised
                } else {
                    Rectangle().fill(.ultraThinMaterial)
                }
            }
            .clipShape(Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(isHome ? Color.white.opacity(0.35) : DS.Color.border, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isHome)
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

    private static let populationFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter
    }()

    /// «5,5 км» — с одним знаком после запятой: прогулка измеряется
    /// шагами, а не метрами, и «5,485 км» здесь выглядит как опечатка.
    private static let walkFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    private static let distanceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter
    }()
}
