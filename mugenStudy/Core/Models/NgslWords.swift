import Foundation

struct NgslBand: Decodable {
    let category: NgslWordCategory
    let words: [NgslWord]
}

struct NgslWord: Decodable, Equatable, Hashable {
    let word: String
    let meaning: String
    let pos: String
}

enum NgslWordCategory: String, Codable {
    case essential
    case frequent1

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
