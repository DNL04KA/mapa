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
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

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
            .accessibilityLabel("Закрыть город")
            .accessibilityAddTraits(.isButton)
    }

    private var panel: some View {
        VStack(spacing: DS.Space.md) {
            Capsule()
                .fill(DS.Color.borderStrong)
                .frame(width: 38, height: 4)

            header
            landmarks
            facts
            homeButton
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
            Text(city.nameRU)
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

    /// Что посмотреть в городе — с настоящими фотографиями.
    ///
    /// Под каждым снимком стоит имя автора и лицензия. Это не мелкий шрифт
    /// ради приличия: фотографии с Викисклада можно показывать именно при
    /// условии, что автора назвали.
    @ViewBuilder
    private var landmarks: some View {
        let photos = LandmarkPhotos.photos(for: city.nameRU)
        let names = CityFacts.landmarks(for: city.nameRU) ?? []

        if !photos.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: DS.Space.sm) {
                    ForEach(photos) { photo in
                        VStack(alignment: .leading, spacing: 5) {
                            ZStack {
                                Rectangle().fill(accent.opacity(0.10))
                                RemoteImage(url: photo.small)
                            }
                            .frame(width: 152, height: 104)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                    .strokeBorder(DS.Color.hairline, lineWidth: 1)
                            }

                            Text(photo.name)
                                .font(DS.Font.caption)
                                .foregroundStyle(DS.Color.ink)
                                .lineLimit(1)

                            if let credit = photo.credit {
                                // Две строки, а не одна: обрезанное имя автора —
                                // это уже не указание авторства.
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
                }
                .padding(.horizontal, DS.Space.screen)
            }
            .padding(.horizontal, -DS.Space.screen)
        } else if !names.isEmpty {
            Text(names.joined(separator: " · "))
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
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

    private func fact(value: String, caption: String, icon: String) -> some View {
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

    private static let distanceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter
    }()
}
