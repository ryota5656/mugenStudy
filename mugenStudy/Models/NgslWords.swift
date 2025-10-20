import Foundation

struct NgslBand: Decodable {
    let category: NgslWordCategory
    let words: [NgslWord]
}

struct NgslWord: Decodable {
    let word: String
    let meaning: String
    let pos: String
}

enum NgslWordCategory: String, Codable {
    case essential
    case frequent1
    case frequent2
    case frequent3

    // Create enum from raw JSON key with normalization
    init?(rawKey: String) {
        var k = rawKey.lowercased()
        k = k.replacingOccurrences(of: "１", with: "1")
            .replacingOccurrences(of: "２", with: "2")
            .replacingOccurrences(of: "３", with: "3")
        self.init(rawValue: k)
    }
}

struct NgslWords: Decodable {
    let bands: [NgslBand]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: [NgslWord]].self)
        let bands = dict.compactMap { (k, v) -> NgslBand? in
            guard let cat = NgslWordCategory(rawKey: k), !v.isEmpty else { return nil }
            return NgslBand(category: cat, words: v)
        }.sorted { $0.category.rawValue < $1.category.rawValue }
        self.bands = bands
    }
}

enum NgslWordsLoader {
    // フル構造（カテゴリ別バンド）を読み込む
    static func loadBands() throws -> NgslWords {
        let url = Bundle.main.url(forResource: "ngsl_words", withExtension: "json")!
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(NgslWords.self, from: data)
    }

    // 全語をフラットに取得
    static func allWords() -> [NgslWord] {
        guard let bands = try? loadBands().bands else { return [] }
        return bands.flatMap { $0.words }
    }

    // 利用可能なカテゴリ一覧
    static func availableCategories() -> [NgslWordCategory] {
        (try? loadBands().bands.map { $0.category }) ?? []
    }

    // カテゴリ指定で1語
    static func random(category: NgslWordCategory, pos: String? = nil) -> NgslWord? {
        guard let band = try? loadBands().bands.first(where: { $0.category == category }) else { return nil }
        let pool = pos.map { p in band.words.filter { $0.pos == p } } ?? band.words
        return pool.randomElement()
    }

    // 複数カテゴリから1語
    static func random(categories: [NgslWordCategory], pos: String? = nil) -> NgslWord? {
        guard let bands = try? loadBands().bands else { return nil }
        let set = Set(categories)
        let flat = bands.filter { set.contains($0.category) }.flatMap { $0.words }
        let pool = pos.map { p in flat.filter { $0.pos == p } } ?? flat
        return pool.randomElement()
    }

    // 全体から1語
    static func random() -> NgslWord? {
        let pool = allWords()
        return pool.randomElement()
    }

    // 品詞（pos）でフィルタして1語（全体）
    static func random(pos: String? = nil) -> NgslWord? {
        let pool = allWords()
        let filtered = pos.map { p in pool.filter { $0.pos == p } } ?? pool
        return filtered.randomElement()
    }

    // 複数語をランダム取得（重複なし）
    static func random(count: Int, pos: String? = nil, category: NgslWordCategory? = nil) -> [NgslWord] {
        guard count > 0 else { return [] }
        let base: [NgslWord]
        if let category = category, let band = try? loadBands().bands.first(where: { $0.category == category }) {
            base = band.words
        } else {
            base = allWords()
        }
        let pool = pos.map { p in base.filter { $0.pos == p } } ?? base
        return Array(pool.shuffled().prefix(count))
    }
}
