import Foundation

struct ScoreWord: Decodable {
    let word: String
    let meaning: String
    let pos: String
}

// スコア帯（例: 300, 400, ...）ごとに単語配列を束ねる段（バンド）構造
struct ScoreBand: Decodable {
    let score: Int
    let words: [ScoreWord]
}

// score_words.json は {"score300": [..], "score400": [..], ...} 形式。
// これを段構造（bands）へ変換して保持する。
struct ScoreWords: Decodable {
    let bands: [ScoreBand]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: [ScoreWord]].self)
        // "score300" → 300 へ変換し、空配列は除外、昇順で整列
        let bands = dict.compactMap { (k, v) -> ScoreBand? in
            guard let s = Int(k.replacingOccurrences(of: "score", with: "")), !v.isEmpty else { return nil }
            return ScoreBand(score: s, words: v)
        }.sorted { $0.score < $1.score }
        self.bands = bands
    }
}

enum ScoreWordsLoader {
    // decode済み段構造を取得
    static func load() throws -> ScoreWords {
        let url = Bundle.main.url(forResource: "score_words", withExtension: "json")!
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ScoreWords.self, from: data)
    }

    // 利用可能なスコア帯一覧（例: [300, 400, ...]）
    static func availableScores() -> [Int] {
        (try? load().bands.map { $0.score }) ?? []
    }

    // 例: score = 300 → "score300" キーからランダムに1語
    static func randomWord(score: Int) -> ScoreWord? {
        guard let words = try? load() else { return nil }
        return words.bands.first(where: { $0.score == score })?.words.randomElement()
    }

    // スコア範囲で合致するキーを集約し、その中から等確率で1語
    static func randomWord(scoreRange: ClosedRange<Int>) -> ScoreWord? {
        guard let words = try? load() else { return nil }
        let flat: [ScoreWord] = words.bands
            .filter { scoreRange.contains($0.score) }
            .flatMap { $0.words }
        return flat.randomElement()
    }

    // 複数スコアを指定（例: [300, 600]）して集合から1語
    static func randomWord(scores: [Int]) -> ScoreWord? {
        guard !scores.isEmpty, let words = try? load() else { return nil }
        let keyset = Set(scores)
        let flat = words.bands.filter { keyset.contains($0.score) }.flatMap { $0.words }
        return flat.isEmpty ? nil : flat.randomElement()
    }

    // 近似スコア（最も近いキー）から1語。完全一致がなければ最小差のキーを選ぶ
    static func randomWord(approxScore: Int) -> ScoreWord? {
        guard let words = try? load() else { return nil }
        guard let best = words.bands.min(by: { abs($0.score - approxScore) < abs($1.score - approxScore) }) else { return nil }
        return best.words.randomElement()
    }
}


