import Foundation

struct ScenesData: Decodable {
    let categories: [SceneCategory]
}

struct SceneCategory: Decodable {
    let id: String
    let label_ja: String
    let scenes: [String]
}

enum ScenesLoader {
    static func load() throws -> ScenesData {
        let url = Bundle.main.url(forResource: "scenes", withExtension: "json")!
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ScenesData.self, from: data)
    }

    // 全カテゴリからランダムで1シーン
    static func randomScene() -> String {
        let data = try! load()
        let scene = data.categories.flatMap(\.scenes).randomElement()!
        return scene
    }

    // 同一カテゴリ(id)内から、label_ja と scene のペアをランダムで1件返す
    // 返却: (categoryId, labelJa, scene)
    static func randomLabelAndScene() -> (categoryId: String, labelJa: String, scene: String)? {
        guard let data = try? load(),
              let cat = data.categories.randomElement(),
              let scene = cat.scenes.randomElement() else { return nil }
        return (cat.id, cat.label_ja, scene)
    }
}
