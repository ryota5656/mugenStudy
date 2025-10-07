import Foundation

struct CEFRGrammarData: Decodable {
    let grammar_by_cefr: [Entry]
    struct Entry: Decodable {
        let level: String
        let topics: [String]
    }
}

enum CEFRGrammarLoader {
    private static func load() throws -> CEFRGrammarData {
        let url = Bundle.main.url(forResource: "CEFR_grammar", withExtension: "json")!
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CEFRGrammarData.self, from: data)
    }

    static func randomTopic(for level: ToeicLevel) -> String? {
        let allowed = allowedCEFRLevels(for: level)
        guard let data = try? load() else { return nil }
        let pool = data.grammar_by_cefr
            .filter { allowed.contains($0.level) }
            .flatMap { $0.topics }
        return pool.randomElement()
    }

    private static func allowedCEFRLevels(for level: ToeicLevel) -> [String] {
        switch level {
        case .l200: return ["A1", "A2"]      // ~200
        case .l400: return ["A2", "B1"]      // 201-400
        case .l600: return ["B1"]             // 401-600
        case .l800: return ["B2"]             // 601-800
        case .l990: return ["C1"]             // 801-990
        }
    }
}


