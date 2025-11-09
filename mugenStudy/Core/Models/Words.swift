import Foundation

struct WordEntry: Decodable {
    let word: String
    let level: Int
    let meaning: String
    let pos: String
}

enum WordsLoader {
    static func load() throws -> [WordEntry] {
        let url = Bundle.main.url(forResource: "words", withExtension: "json")!
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([WordEntry].self, from: data)
    }

    // 等確率で1語
    static func randomWord() -> WordEntry? {
        guard let words = try? load() else { return nil }
        return words.randomElement()
    }

    // 条件付きランダム：level一致、level範囲、品詞（pos）でフィルタ可
    static func randomWord(level: Int? = nil, pos: String? = nil) -> WordEntry {
        let words = try! load()
        let filtered = words.filter { word in
            let level = level.map { $0 == word.level } ?? true
            let pos = pos.map { $0 == word.pos } ?? true
            return level && pos
        }
        return (filtered.isEmpty ? words : filtered).randomElement()!
    }
}
