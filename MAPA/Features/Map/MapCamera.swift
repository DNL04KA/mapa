import SwiftUI

/// Состояние камеры над картой.
///
/// Храним не «смещение в пикселях», а зум и центр в единичном пространстве.
/// Так ограничения формулируются на человеческом языке («центр не ближе
/// половины экрана к краю мира») и не разъезжаются при смене размера вьюпорта.
public struct MapCamera: Equatable {

    /// 1 — мир ровно по ширине экрана.
    public var zoom: CGFloat
    /// Точка мира под центром экрана, в единичном пространстве.
    public var center: CGPoint

    /// Минимальный зум зависит от экрана: карта должна закрывать его целиком.
    ///
    /// Мир в Меркаторе — квадрат, а экран телефона вытянут. Если вписать мир
    /// по ширине, сверху и снизу останутся полосы воды без суши, и карта
    /// перестаёт читаться как карта. Поэтому вписываем по высоте: видно около
    /// 165° долготы, зато экран занят полностью, а вправо и влево мир бесконечен.
    public static func minZoom(for viewport: CGSize) -> CGFloat {
        guard viewport.width > 0, viewport.height > 0 else { return 1 }
        return max(1, viewport.height / viewport.width)
    }
    /// Потолок продиктован не производительностью, а данными: у Natural Earth 1:110m
    /// береговая линия начинает распадаться на видимые отрезки примерно после 14×.
    /// Для выбора страны пальцем этого с запасом хватает — на 14× по ширине экрана
    /// умещается около 26° долготы. Поднимется вместе с переходом на 1:50m.
    public static let maxZoom: CGFloat = 14

    /// Обзор мира. Зум подставится при первом же `clamped(in:)`.
    public static let world = MapCamera(zoom: 1, center: CGPoint(x: 0.5, y: 0.5))

    public init(zoom: CGFloat = 1, center: CGPoint = CGPoint(x: 0.5, y: 0.5)) {
        self.zoom = zoom
        self.center = center
    }

    /// Сторона квадрата мира в точках экрана.
    public func worldSide(in viewport: CGSize) -> CGFloat {
        viewport.width * zoom
    }

    /// Единичное пространство → экран. Именно эту матрицу получает `Canvas`,
    /// поэтому сами пути не пересчитываются никогда.
    public func transform(in viewport: CGSize) -> CGAffineTransform {
        let side = worldSide(in: viewport)
        let tx = viewport.width / 2 - center.x * side
        let ty = viewport.height / 2 - center.y * side
        return CGAffineTransform(translationX: tx, y: ty).scaledBy(x: side, y: side)
    }

    public func screenPoint(unit: CGPoint, in viewport: CGSize) -> CGPoint {
        unit.applying(transform(in: viewport))
    }

    /// Экран → единичное пространство. X заворачивается: тап справа от
    /// 180-го меридиана должен попадать в Чукотку, а не мимо карты.
    public func unitPoint(screen: CGPoint, in viewport: CGSize) -> CGPoint {
        let side = worldSide(in: viewport)
        guard side > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        return CGPoint(
            x: Self.wrap(center.x + (screen.x - viewport.width / 2) / side),
            y: center.y + (screen.y - viewport.height / 2) / side
        )
    }

    /// По горизонтали мир бесконечен: доехав до 180-го меридиана, ты просто
    /// продолжаешь двигаться дальше. Поэтому по X не ограничиваем, а заворачиваем.
    /// По вертикали край есть — полюса, там упор.
    public func clamped(in viewport: CGSize) -> MapCamera {
        var result = self
        result.zoom = min(max(zoom, Self.minZoom(for: viewport)), Self.maxZoom)
        result.center.x = Self.wrap(result.center.x)

        let side = result.worldSide(in: viewport)
        guard side > 0 else { return result }

        let halfHeight = viewport.height / 2 / side

        result.center.y = halfHeight * 2 >= 1
            ? 0.5
            : min(max(result.center.y, halfHeight), 1 - halfHeight)

        return result
    }

    /// Приводит долготу в [0, 1). Отрицательный остаток в Swift сохраняет знак,
    /// поэтому прибавляем единицу перед вторым взятием остатка.
    public static func wrap(_ value: CGFloat) -> CGFloat {
        let remainder = value.truncatingRemainder(dividingBy: 1)
        return remainder < 0 ? remainder + 1 : remainder
    }

    /// Копии мира, которые сейчас попадают на экран.
    /// Обычно одна, на минимальном зуме — две.
    public func visibleWorldOffsets(in viewport: CGSize) -> [CGFloat] {
        let side = worldSide(in: viewport)
        guard side > 0 else { return [0] }

        let half = viewport.width / 2 / side
        let first = Int(floor(center.x - half))
        let last = Int(floor(center.x + half))
        guard last >= first, last - first < 8 else { return [0] }
        return (first...last).map(CGFloat.init)
    }

    /// Зум с сохранением точки под пальцами: то, за что ухватились, остаётся на месте.
    public func zoomed(by factor: CGFloat, anchor screenPoint: CGPoint, in viewport: CGSize) -> MapCamera {
        let anchorUnit = unitPoint(screen: screenPoint, in: viewport)

        var result = self
        result.zoom = min(max(zoom * factor, Self.minZoom(for: viewport)), Self.maxZoom)

        // Сдвигаем центр так, чтобы `anchorUnit` снова оказался под тем же пикселем.
        let newSide = result.worldSide(in: viewport)
        guard newSide > 0 else { return result.clamped(in: viewport) }
        result.center = CGPoint(
            x: anchorUnit.x - (screenPoint.x - viewport.width / 2) / newSide,
            y: anchorUnit.y - (screenPoint.y - viewport.height / 2) / newSide
        )

        return result.clamped(in: viewport)
    }

    /// Сдвиг пальцем: экранные точки переводим в доли мира.
    public func panned(by translation: CGSize, in viewport: CGSize) -> MapCamera {
        let side = worldSide(in: viewport)
        guard side > 0 else { return self }

        var result = self
        result.center.x -= translation.width / side
        result.center.y -= translation.height / side
        return result.clamped(in: viewport)
    }

    /// Камера, при которой страна занимает экран с запасом по краям.
    public func focused(on country: Country, in viewport: CGSize, padding: CGFloat = 0.28) -> MapCamera {
        let box = country.bounds
        guard box.width > 0, box.height > 0 else { return self }

        let zoomForWidth = (1 - padding) / box.width
        let zoomForHeight = (viewport.height / viewport.width) * (1 - padding) / box.height

        var result = self
        result.zoom = min(max(min(zoomForWidth, zoomForHeight), Self.minZoom(for: viewport)), Self.maxZoom)
        result.center = CGPoint(x: box.midX, y: box.midY)
        return result.clamped(in: viewport)
    }
}
