import Foundation

/// Совет по стране: сколько закладывать времени и денег и чем она
/// интересна с точки зрения архитектуры.
///
/// Написано руками и только для тех стран, за которые я отвечаю. Это
/// принципиально: «что посмотреть» есть в данных и собирается само для
/// всех стран, а «десять дней и сто евро в день» — оценка, и взять её
/// неоткуда. Выдумать правдоподобные числа для ста семидесяти шести стран
/// можно за вечер, и ровно поэтому делать этого нельзя.
struct CountryFacts {

    /// Одно предложение про архитектуру.
    let architecture: String
    /// Сколько дней советуют заложить.
    let days: ClosedRange<Int>
    /// Примерный бюджет на день в евро, без перелёта.
    let dailyBudget: ClosedRange<Int>

    var daysText: String { "\(days.lowerBound)–\(days.upperBound)" }
    var budgetText: String { "€\(dailyBudget.lowerBound)–\(dailyBudget.upperBound)" }

    static func facts(for countryID: String) -> CountryFacts? { catalog[countryID] }

    private static let catalog: [String: CountryFacts] = [
        "ITA": CountryFacts(
            architecture: "Античный Рим, романика, ренессанс и барокко — четыре эпохи в пределах одной улицы.",
            days: 10...14, dailyBudget: 70...130),
        "FRA": CountryFacts(
            architecture: "Готические соборы и османовские бульвары — Париж перестроили в XIX веке под линейку.",
            days: 8...12, dailyBudget: 80...150),
        "ESP": CountryFacts(
            architecture: "Мавританское наследие юга и модерн Гауди, у которого почти нет прямых линий.",
            days: 10...14, dailyBudget: 60...110),
        "PRT": CountryFacts(
            architecture: "Мануэлино с морскими канатами в камне и азулежу — плитка на фасадах целых кварталов.",
            days: 7...10, dailyBudget: 50...90),
        "DEU": CountryFacts(
            architecture: "Готика соборов и Баухаус — школа, из которой вырос весь современный дизайн.",
            days: 8...12, dailyBudget: 70...120),
        "GBR": CountryFacts(
            architecture: "Перпендикулярная готика и викторианский кирпич промышленных городов.",
            days: 8...12, dailyBudget: 90...160),
        "NLD": CountryFacts(
            architecture: "Узкие фасады с фронтонами — налог брали за ширину дома, и город вырос вверх.",
            days: 4...6, dailyBudget: 80...140),
        "CZE": CountryFacts(
            architecture: "Готика, барокко и кубизм: Прага — единственный город с кубистическими домами.",
            days: 4...7, dailyBudget: 45...80),
        "GRC": CountryFacts(
            architecture: "Классические ордера, с которых списывали фасады по всей Европе две тысячи лет.",
            days: 8...14, dailyBudget: 55...100),
        "TUR": CountryFacts(
            architecture: "Византийские купола и османские мечети Синана, выросшие из тех же куполов.",
            days: 8...12, dailyBudget: 40...80),
        "MAR": CountryFacts(
            architecture: "Риады, закрытые снаружи и раскрытые во двор, зеллидж и резной кедр.",
            days: 7...10, dailyBudget: 35...70),
        "EGY": CountryFacts(
            architecture: "Древнеегипетская: пилоны, гипостильные залы и колонны в форме папируса.",
            days: 8...12, dailyBudget: 40...80),
        "JPN": CountryFacts(
            architecture: "Деревянные храмы без единого гвоздя и метаболизм 1960-х с домами-капсулами.",
            days: 12...16, dailyBudget: 90...160),
        "CHN": CountryFacts(
            architecture: "Императорские дворцы на оси север–юг и изогнутые крыши на кронштейнах доугун.",
            days: 12...18, dailyBudget: 50...100),
        "THA": CountryFacts(
            architecture: "Буддийские ваты с многоярусными крышами и позолотой поверх тикового дерева.",
            days: 10...14, dailyBudget: 35...70),
        "IND": CountryFacts(
            architecture: "Могольская симметрия с айванами и джали — резными каменными решётками.",
            days: 12...18, dailyBudget: 30...60),
        "ARE": CountryFacts(
            architecture: "Небоскрёбы поверх ветряных башен барджиль — древних кондиционеров.",
            days: 5...7, dailyBudget: 100...200),
        "USA": CountryFacts(
            architecture: "Родина небоскрёба: чикагская школа, ар-деко Нью-Йорка, дома Райта.",
            days: 12...20, dailyBudget: 120...220),
        "MEX": CountryFacts(
            architecture: "Пирамиды майя и ацтеков рядом с колониальным барокко на их же камнях.",
            days: 10...14, dailyBudget: 45...90),
        "BRA": CountryFacts(
            architecture: "Модернизм Нимейера: бетон, который ведёт себя как ткань.",
            days: 12...18, dailyBudget: 50...100),
        "PER": CountryFacts(
            architecture: "Инкская кладка без раствора — камни подогнаны так, что не входит лезвие.",
            days: 10...14, dailyBudget: 45...85),
        "AUS": CountryFacts(
            architecture: "Оперный театр Утзона — оболочки-паруса, которые считали двадцать лет.",
            days: 14...21, dailyBudget: 90...160),
        "NOR": CountryFacts(
            architecture: "Ставкирки — деревянные церкви XII века, стоящие на мачтовых столбах.",
            days: 8...12, dailyBudget: 110...190),
        "ISL": CountryFacts(
            architecture: "Дерновые дома с травяными крышами и бетонный экспрессионизм Хадльгримскиркьи.",
            days: 6...10, dailyBudget: 120...200),
        "CHE": CountryFacts(
            architecture: "Шале с широкими свесами кровли и минимализм Ле Корбюзье, который отсюда родом.",
            days: 6...9, dailyBudget: 130...230)
    ]
}
