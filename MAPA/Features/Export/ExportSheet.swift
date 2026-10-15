import SwiftUI

/// Экспорт карты в картинку для соцсетей.
@MainActor
struct ExportSheet: View {

    @Environment(\.dsMotion) private var motion

    let theme: MapTheme
    let geometry: WorldGeometry
    let overlay: MapOverlayState
    let statistics: TravelStatistics
    let route: Route?
    let homeCity: String?
    /// Габариты отмеченных стран в единичном пространстве — по ним кадрируем.
    let markedBounds: CGRect?
    let onDismiss: () -> Void

    @State private var format: ExportFormat = .story
    @State private var template: ExportTemplate = .map
    @State private var rendered: Image?
    @State private var isRendering = false
    @State private var video: URL?
    @State private var videoProgress: Double?
    @State private var dragOffset: CGFloat = 0

    /// Высота превью. Карточка рисуется в натуральную величину и ужимается —
    /// так видно ровно то, что уйдёт в файл.
    private let previewHeight: CGFloat = 340

    var body: some View {
        ZStack(alignment: .bottom) {
            scrim
            panel
        }
        .ignoresSafeArea()
        .task(id: renderKey) { await render() }
        .onChange(of: renderKey) { _ in
            // Сменили формат или шаблон — прежнее видео уже не про то.
            video = nil
            videoProgress = nil
        }
    }

    private var scrim: some View {
        Rectangle()
            .fill(DS.Color.scrim)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .transition(.opacity)
            .accessibilityLabel("Закрыть экспорт")
            .accessibilityAddTraits(.isButton)
    }

    private var panel: some View {
        VStack(spacing: DS.Space.md) {
            Capsule()
                .fill(DS.Color.borderStrong)
                .frame(width: 38, height: 4)

            Text("Поделиться")
                .font(DS.Font.title)
                .foregroundStyle(DS.Color.ink)

            if route != nil {
                picker(ExportTemplate.allCases, selection: $template) { $0.title }
            }

            preview

            picker(ExportFormat.allCases, selection: $format) { $0.title }

            shareButton
            videoButton
        }
        .padding(.horizontal, DS.Space.screen)
        .padding(.top, DS.Space.sm)
        .padding(.bottom, DS.Space.xl + DS.Space.xs)
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

    // MARK: - Превью

    private var preview: some View {
        card
            .scaleEffect(previewScale, anchor: .center)
            .frame(
                width: format.pointSize.width * previewScale,
                height: previewHeight
            )
            .dsRounded(DS.Radius.md)
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(DS.Color.border, lineWidth: 1)
            }
            .animation(motion.animation(.smooth), value: format)
            .accessibilityHidden(true)
    }

    private var previewScale: CGFloat {
        previewHeight / format.pointSize.height
    }

    private var card: ExportCard {
        ExportCard(
            template: route == nil ? .map : template,
            format: format,
            theme: theme,
            geometry: geometry,
            overlay: overlay,
            camera: camera,
            statistics: statistics,
            route: route,
            homeCity: homeCity
        )
    }

    /// Кадрируем по тому, что показываем: маршрут — по своим точкам,
    /// карта — по отмеченным странам. Иначе в кадр попадает пустой океан.
    private var camera: MapCamera {
        let viewport = format.pointSize

        if (route == nil ? ExportTemplate.map : template) == .route,
           let route, route.points.count > 1 {
            let xs = route.points.map(\.unitPoint.x)
            let ys = route.points.map(\.unitPoint.y)
            let box = CGRect(
                x: xs.min() ?? 0, y: ys.min() ?? 0,
                width: (xs.max() ?? 0) - (xs.min() ?? 0),
                height: (ys.max() ?? 0) - (ys.min() ?? 0)
            )
            return MapCamera().fitting(box, in: viewport, padding: 0.35)
        }

        guard let markedBounds else {
            return MapCamera(zoom: viewport.height / viewport.width, center: CGPoint(x: 0.5, y: 0.45))
        }
        return MapCamera().fitting(markedBounds, in: viewport, padding: 0.3)
    }

    // MARK: - Кнопки

    @ViewBuilder
    private var shareButton: some View {
        if let rendered {
            ShareLink(
                item: rendered,
                preview: SharePreview("Моя карта MAPA", image: rendered)
            ) {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: DS.Size.iconSm, weight: .semibold))
                    Text("Поделиться")
                }
            }
            .buttonStyle(DSButtonStyle(.primary, fullWidth: true))
            .simultaneousGesture(TapGesture().onEnded { Haptics.shared.tap(.light) })
        } else {
            HStack(spacing: DS.Space.xs) {
                ProgressView().tint(DS.Color.inkSecondary)
                Text(isRendering ? "Готовим картинку" : "Ошибка")
            }
            .font(DS.Font.subhead)
            .foregroundStyle(DS.Color.inkSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: DS.Size.controlHeight)
        }
    }

    private func picker<T: Identifiable & Hashable>(
        _ items: [T],
        selection: Binding<T>,
        title: @escaping (T) -> String
    ) -> some View {
        HStack(spacing: DS.Space.xxs) {
            ForEach(items) { item in
                let isSelected = item == selection.wrappedValue
                Button {
                    Haptics.shared.selection()
                    withAnimation(motion.animation(.snap)) { selection.wrappedValue = item }
                } label: {
                    Text(title(item))
                        .font(DS.Font.caption)
                        .foregroundStyle(isSelected ? DS.Color.inkOnAccent : DS.Color.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(isSelected ? DS.Color.ink : Color.white.opacity(0.06))
                        .clipShape(Capsule(style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Рендер

    /// Ключ пересчёта: меняется формат или шаблон — картинка собирается заново.
    private var renderKey: String {
        "\(format.rawValue)-\(template.rawValue)"
    }

    private func render() async {
        isRendering = true
        rendered = nil

        // Кадр отдаём следующему проходу цикла: иначе «Готовим картинку»
        // не успевает показаться и кнопка мигает.
        await Task.yield()

        let renderer = ImageRenderer(content: card)
        // Рисуем в точках, множим на три — получаем 1080 по ширине.
        renderer.scale = 3

        if let image = renderer.uiImage {
            rendered = Image(uiImage: image)
        }
        isRendering = false
    }

    // MARK: - Видео

    /// Карта, которая заполняется на глазах.
    ///
    /// Отдельной кнопкой, а не вместо картинки: видео собирается несколько
    /// секунд, и заставлять ждать того, кому нужна просто картинка, незачем.
    @ViewBuilder
    private var videoButton: some View {
        if let video {
            ShareLink(item: video) {
                HStack(spacing: DS.Space.xs) {
                    Image(systemName: "film")
                        .font(.system(size: DS.Size.iconSm, weight: .semibold))
                    Text("Поделиться видео")
                }
            }
            .buttonStyle(DSButtonStyle(.secondary, fullWidth: true))
            .simultaneousGesture(TapGesture().onEnded { Haptics.shared.tap(.light) })
        } else if let videoProgress {
            VStack(spacing: DS.Space.xxs) {
                ProgressView(value: videoProgress)
                    .tint(theme.accent)
                Text("Собираем видео")
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.inkTertiary)
            }
            .frame(height: DS.Size.controlHeight)
        } else {
            PillButton("Сделать видео", icon: "film", kind: .secondary, fullWidth: true) {
                Task { await renderVideo() }
            }
            .disabled(rendered == nil)
            .opacity(rendered == nil ? 0.4 : 1)
        }
    }

    private func renderVideo() async {
        videoProgress = 0

        let size = format.pixelSize
        let camera = self.camera
        let fullOverlay = overlay
        let fullStats = statistics

        let url = try? await VideoExporter.render(
            size: size,
            frameCount: ExportAnimation.frameCount,
            fps: ExportAnimation.fps,
            makeFrame: { index in
                let progress = ExportAnimation.progress(frame: index)
                let renderer = ImageRenderer(content: ExportCard(
                    template: template,
                    format: format,
                    theme: theme,
                    geometry: geometry,
                    overlay: ExportAnimation.overlay(fullOverlay, at: progress),
                    camera: camera,
                    statistics: ExportAnimation.statistics(fullStats, at: progress),
                    route: route,
                    homeCity: homeCity
                ))
                renderer.scale = 3
                return renderer.uiImage
            },
            onProgress: { value in videoProgress = value }
        )

        video = url
        videoProgress = nil
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
