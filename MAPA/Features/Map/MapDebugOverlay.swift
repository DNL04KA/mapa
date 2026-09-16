import SwiftUI

/// Панель замеров. Нужна ровно затем, чтобы «плавно» перестало быть
/// вопросом ощущений: на экране видно время кадра, число точек и текущий зум.
///
/// Обновляется по таймеру раз в треть секунды — читать счётчики на каждом кадре
/// значило бы мешать тому, что мы измеряем.
struct MapDebugOverlay: View {

    let stats: RenderStats
    let geometry: WorldGeometry?
    let camera: MapCamera
    let loadDuration: TimeInterval

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.33)) { _ in
            VStack(alignment: .leading, spacing: 2) {
                row("кадр", value: String(format: "%.2f мс", stats.lastMilliseconds))
                row("среднее", value: String(format: "%.2f мс", stats.averageMilliseconds))
                row("худший", value: String(format: "%.2f мс", stats.worstMilliseconds))
                Divider().overlay(DS.Color.hairline).padding(.vertical, 2)
                row("стран", value: "\(geometry?.countries.count ?? 0)")
                row("точек", value: "\(geometry?.pointCount ?? 0)")
                row("загрузка", value: String(format: "%.0f мс", loadDuration * 1000))
                row("зум", value: String(format: "%.2f×", camera.zoom))
            }
            .padding(DS.Space.sm)
            .frame(width: 168, alignment: .leading)
            .dsGlass(radius: DS.Radius.sm, shadow: .low)
        }
    }

    private func row(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(DS.Color.inkTertiary)
            Spacer(minLength: DS.Space.xs)
            Text(value)
                .foregroundStyle(DS.Color.ink)
                .monospacedDigit()
        }
        .font(DS.Font.micro)
    }
}
