import SwiftUI

/// Корень приложения. Здесь и только здесь:
/// • живёт фон приложения;
/// • ставится контекст доступности (`dsMotionEnvironment`);
/// • прогревается хаптика.
struct RootView: View {

    /// Ручные переключатели для проверки Reduce Motion / Reduce Transparency
    /// без похода в Настройки. Системные значения они не отменяют — только дополняют.
    @State private var previewReduceMotion = false
    @State private var previewReduceTransparency = false
    @State private var showsGallery = false
    @StateObject private var settings = AppSettings()

    var body: some View {
        ZStack {
            // Аврора почти погашена: под картой во весь экран её всё равно
            // не видно, а по краям она добавляла цвета там, где он не нужен.
            AuroraBackground(intensity: settings.theme.isLight ? 0 : 0.5, colors: settings.theme.auroraColors)

            WorldMapView(
                surface: settings.surface,
                palette: settings.palette,
                onSelectSurface: { settings.select($0) },
                onSelectPalette: { settings.select($0) },
                onOpenGallery: { showsGallery = true }
            )
        }
        .dsMotionEnvironment(
            forceReduceMotion: previewReduceMotion,
            forceReduceTransparency: previewReduceTransparency
        )
        .animation(.easeInOut(duration: 0.35), value: settings.theme)
        // Цветовая схема идёт от темы, и нужна она ровно ради статус-бара:
        // белые часы на белой карте не читаются. Панели при этом остаются
        // тёмными — им схему навязываем отдельно.
        .preferredColorScheme(settings.theme.isLight ? .light : .dark)
        .sheet(isPresented: $showsGallery) {
            galleryScene
        }
        .onAppear {
            Haptics.shared.prepare()
        }
    }

    private var galleryScene: some View {
        ZStack {
            AuroraBackground(colors: settings.theme.auroraColors)

            DesignSystemGalleryView(
                previewReduceMotion: $previewReduceMotion,
                previewReduceTransparency: $previewReduceTransparency
            )
        }
        .dsMotionEnvironment(
            forceReduceMotion: previewReduceMotion,
            forceReduceTransparency: previewReduceTransparency
        )
        .preferredColorScheme(.dark)
    }
}

// Xcode 14 ещё не знает макрос #Preview, поэтому классический PreviewProvider.
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView().preferredColorScheme(.dark)
    }
}
