import Foundation

struct GrammarData: Decodable {
    let grammar_categories: [GrammarCategory]
}

struct GrammarCategory: Decodable {
    let id: String
    let label_ja: String
    let subcategories: [String]
}

enum GrammarLoader {
    static func load() throws -> GrammarData {
        let url = Bundle.main.url(forResource: "grammar", withExtension: "json")!
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(GrammarData.self, from: data)
    }
    
    static func randomSubcategory() -> String {
        let data = try! GrammarLoader.load()
        let category = data.grammar_categories.randomElement()!
        return category.subcategories.randomElement()!
    }
}
