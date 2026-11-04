import Foundation

/// Почему пользовательские данные не прочитались.
///
/// Отдельный тип, а не `nil`, потому что разница решающая. Пустой журнал и
/// журнал, который не удалось разобрать, выглядят на экране одинаково — и
/// именно это стоило бы человеку всей карты: приложение показало бы пустоту,
/// а первая же отметка записала бы эту пустоту поверх файла.
///
/// Поэтому хранилище больше не отвечает «ничего не вышло, держи пустое».
/// Оно говорит, что именно случилось, а вызывающий код останавливает запись.
enum StorageFailure: Error, Equatable {

    /// Файл записан версией приложения новее этой.
    ///
    /// Не поломка, а разница в возрасте: человек поставил свежую версию на
    /// одном телефоне и старую на другом. Трогать такой файл нельзя — в нём
    /// есть то, чего мы не умеем сохранить обратно.
    case futureVersion(found: Int, supported: Int)

    /// Файл есть, но разобрать его не вышло.
    case unreadable
}

/// Номер формата из файла — даже когда всё остальное не разобралось.
///
/// Нужен ровно для одного различия: «файл испорчен» и «файл от будущей
/// версии» лечатся по-разному, а оба приходят одной и той же ошибкой
/// декодера. Поэтому номер читаем отдельным крошечным разбором, который
/// не зависит от остальной схемы.
enum SchemaProbe {

    private struct Versioned: Decodable {
        let version: Int
    }

    static func version(in data: Data) -> Int? {
        try? JSONDecoder().decode(Versioned.self, from: data).version
    }

    /// Общая проверка для всех хранилищ: разобрать снимок, а если не вышло —
    /// объяснить почему.
    static func decode<T: Decodable>(_ type: T.Type,
                                     from data: Data,
                                     supported: Int,
                                     using decoder: JSONDecoder) throws -> T {
        if let version = version(in: data), version > supported {
            throw StorageFailure.futureVersion(found: version, supported: supported)
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw StorageFailure.unreadable
        }
    }
}
