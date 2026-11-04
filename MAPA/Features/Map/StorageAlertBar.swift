import SwiftUI

/// Полоса «данные не прочитались».
///
/// Тихий отказ здесь неотличим от пустой карты: человек решит, что потерял
/// пятнадцать лет поездок, и начнёт отмечать заново — поверх целого файла,
/// который приложение просто не поняло. Поэтому говорим прямо: файл на
/// месте, запись остановлена, вот что можно сделать.
///
/// Полоса живёт над картой рядом со статистикой, а не в настройках: беда
/// касается всего, что человек сейчас делает, и прятать её вглубь нельзя.
struct StorageAlertBar: View {

    let failure: StorageFailure
    let accent: Color
    let onRestore: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DS.Space.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: DS.Size.iconSm, weight: .semibold))
                .foregroundStyle(DS.Color.danger)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: DS.Space.xxs) {
                Text(title)
                    .font(DS.Font.subhead)
                    .foregroundStyle(DS.Color.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(explanation)
                    .font(DS.Font.micro)
                    .foregroundStyle(DS.Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onRestore) {
                    Text("Восстановить из копии")
                        .font(DS.Font.caption)
                        .foregroundStyle(accent)
                        .padding(.vertical, DS.Space.xxs)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(DS.Space.sm)
        .dsGlass(radius: DS.Radius.md, shadow: .medium)
        .accessibilityElement(children: .combine)
    }

    private var title: LocalizedStringKey {
        switch failure {
        case .futureVersion: return "Данные записаны новой версией"
        case .unreadable:    return "Данные не прочитались"
        }
    }

    private var explanation: LocalizedStringKey {
        switch failure {
        case .futureVersion:
            return "Обнови MAPA, чтобы их открыть. Пока запись остановлена — файл не пострадает."
        case .unreadable:
            return "Файл на месте, но приложение его не понимает. Запись остановлена, чтобы ничего не затереть."
        }
    }
}
