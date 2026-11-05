import SwiftUI

/// Правка одной остановки: сколько дней, сколько денег, что не забыть.
///
/// Отдельный лист, а не поля прямо в строке маршрута. В строке уже живут
/// номер, фотография, название, дата, шаг дней, список мест и ручка
/// перетаскивания — ещё два поля там не поместятся, а высота строки
/// участвует в расчёте перетаскивания и меняться не может.
///
/// Бюджет здесь — на всю остановку, а не на день: человек прикидывает
/// «Токио обойдётся тысячи в две», а не считает по суткам. Сумма по
/// поездке складывается из остановок — одна правда, а не две.
@MainActor
struct RoutePointEditor: View {

    let point: RoutePoint
    let accent: Color
    let arrival: Date?

    let onChangeDays: (Int) -> Void
    let onChangeBudget: (Int) -> Void
    let onChangeNote: (String) -> Void
    let onDone: () -> Void

    @State private var budgetText = ""
    @State private var note = ""
    @FocusState private var field: Field?

    private enum Field { case budget, note }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.lg) {
            header
            daysRow
            budgetRow
            noteRow
            Spacer(minLength: 0)
            PillButton("Готово", kind: .tinted(accent), fullWidth: true, action: commitAndClose)
        }
        .padding(DS.Space.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DS.Color.panel)
        .onAppear {
            budgetText = point.budget > 0 ? "\(point.budget)" : ""
            note = point.note
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(point.name)
                .font(DS.Font.title)
                .foregroundStyle(DS.Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let arrival {
                Text(TripDateFormat.day(arrival))
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkTertiary)
            } else if let country = point.countryName {
                Text(country)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkTertiary)
            }
        }
    }

    private var daysRow: some View {
        HStack(spacing: DS.Space.sm) {
            label("calendar", "Дней здесь")
            Spacer(minLength: 0)

            stepper("minus", enabled: point.days > 1) { onChangeDays(point.days - 1) }

            Text("\(point.days)")
                .font(DS.Font.numeral)
                .foregroundStyle(DS.Color.ink)
                .monospacedDigit()
                .frame(minWidth: 34)

            stepper("plus", enabled: point.days < 60) { onChangeDays(point.days + 1) }
        }
    }

    private var budgetRow: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            label("creditcard", "Бюджет остановки")

            HStack(spacing: DS.Space.xs) {
                Text("€")
                    .font(DS.Font.headline)
                    .foregroundStyle(DS.Color.inkTertiary)

                TextField("0", text: $budgetText)
                    .font(DS.Font.headline)
                    .foregroundStyle(DS.Color.ink)
                    .keyboardType(.numberPad)
                    .focused($field, equals: .budget)
                    .onChange(of: budgetText) { value in
                        // Отсекаем всё, кроме цифр, прямо при наборе:
                        // числовая клавиатура на iPad и внешняя клавиатура
                        // пропускают и буквы.
                        let digits = value.filter(\.isNumber)
                        if digits != value { budgetText = String(digits.prefix(7)) }
                    }
            }
            .padding(.horizontal, DS.Space.sm)
            .frame(height: DS.Size.controlHeight)
            .dsGlass(radius: DS.Radius.md, shadow: .low)
        }
    }

    private var noteRow: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            label("square.and.pencil", "Заметка")

            TextField("Что не забыть", text: $note, axis: .vertical)
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.ink)
                .lineLimit(2...5)
                .focused($field, equals: .note)
                .padding(DS.Space.sm)
                .frame(minHeight: DS.Size.controlHeight, alignment: .topLeading)
                .dsGlass(radius: DS.Radius.md, shadow: .low)
        }
    }

    private func label(_ icon: String, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: DS.Space.xs) {
            Image(systemName: icon)
                .font(.system(size: DS.Size.iconSm, weight: .semibold))
                .foregroundStyle(accent)
            Text(title)
                .font(DS.Font.callout)
                .foregroundStyle(DS.Color.inkSecondary)
        }
    }

    private func stepper(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.shared.tap(.soft)
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: DS.Size.glyph, weight: .bold))
                .foregroundStyle(enabled ? accent : DS.Color.inkTertiary.opacity(0.4))
                .frame(width: 40, height: 40)
                .background { Circle().fill(enabled ? accent.opacity(0.12) : Color.clear) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    /// Текстовые поля отдаём наружу при закрытии, а не на каждое нажатие
    /// клавиши: иначе маршрут писался бы на диск посимвольно.
    private func commitAndClose() {
        field = nil
        onChangeBudget(Int(budgetText) ?? 0)
        onChangeNote(note.trimmingCharacters(in: .whitespacesAndNewlines))
        onDone()
    }
}
