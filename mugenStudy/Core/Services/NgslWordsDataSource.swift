import Foundation

protocol NgslWordsDataSource {
    func loadBands() throws -> NgslWords
}

struct BundleNgslWordsDataSource: NgslWordsDataSource {
    func loadBands() throws -> NgslWords {
        let url = Bundle.main.url(forResource: "ngsl_words", withExtension: "json")!
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(NgslWords.self, from: data)
    }

    // 全語をフラットに取得
    func allWords() -> [NgslWord] {
        guard let bands = try? loadBands().bands else { return [] }
        return bands.flatMap { $0.words }
    }
    
    // 利用可能なカテゴリ一覧
    func availableCategories() -> [NgslWordCategory] {
        (try? loadBands().bands.map { $0.category }) ?? []
    }

    // カテゴリ指定でランダムで1語
    func random(category: NgslWordCategory, pos: String? = nil) -> NgslWord? {
        guard let band = try? loadBands().bands.first(where: { $0.category == category }) else { return nil }
        let pool = pos.map { p in band.words.filter { $0.pos == p } } ?? band.words
        return pool.randomElement()
    }
    
    // カテゴリ指定で10語
    func words(category: NgslWordCategory, indexRange: ClosedRange<Int>) -> [NgslWord] {
        guard let band = try? loadBands().bands.first(where: { $0.category == category }) else { return [] }
        let words = band.words
        let lower = max(indexRange.lowerBound, 1)
        let upper = min(indexRange.upperBound, words.count)
        
        guard lower <= upper else { return [] }
        let start = lower - 1
        let end = upper - 1
        return Array(words[start...end])
    }

    // 複数カテゴリから1語
    func random(categories: [NgslWordCategory], pos: String? = nil) -> NgslWord? {
        guard let bands = try? loadBands().bands else { return nil }
        let set = Set(categories)
        let flat = bands.filter { set.contains($0.category) }.flatMap { $0.words }
        let pool = pos.map { p in flat.filter { $0.pos == p } } ?? flat
        return pool.randomElement()
    }

    // 全体から1語
    func random() -> NgslWord? {
        let pool = allWords()
        return pool.randomElement()
    }

    // 1始まりのインデックス範囲でランダム抽出（全体）
    // 例: 1...10 は先頭10語からランダム
    func random(indexRange: ClosedRange<Int>) -> NgslWord? {
        let words = allWords()
        guard !words.isEmpty else { return nil }
        let lower = max(indexRange.lowerBound, 1)
        let upper = min(indexRange.upperBound, words.count)
        guard lower <= upper else { return nil }
        let start = lower - 1
        let end = upper - 1
        let slice = words[start...end]
        return slice.randomElement()
    }

    // 品詞（pos）でフィルタして1語（全体）
    func random(pos: String? = nil) -> NgslWord? {
        let pool = allWords()
        let filtered = pos.map { p in pool.filter { $0.pos == p } } ?? pool
        return filtered.randomElement()
    }

    // 複数語をランダム取得（重複なし）
    func random(count: Int, pos: String? = nil, category: NgslWordCategory? = nil) -> [NgslWord] {
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


