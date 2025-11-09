import Foundation

protocol VocabWordsRepositoryProtocol {
    func words(category: NgslWordCategory, start: Int, end: Int) async -> [NgslWord]
    func randomMeanings(count: Int, pos: String?) -> [String]
    func randomWord(category: NgslWordCategory) -> NgslWord?
}

struct VocabWordsRepository: VocabWordsRepositoryProtocol {
    private let dataSource: NgslWordsDataSource

    init(dataSource: NgslWordsDataSource = BundleNgslWordsDataSource()) {
        self.dataSource = dataSource
    }

    func words(category: NgslWordCategory, start: Int, end: Int) async -> [NgslWord] {
        // Load bands; if loading fails, return an empty list
        guard let bands = try? await dataSource.loadBands().bands else { return [] }
        guard let band = bands.first(where: { $0.category == category }) else { return [] }
        // Normalize to 1-based indices and clamp to bounds
        let lower = max(start, 1)
        let upper = min(end, band.words.count)
        guard lower <= upper else { return [] }
        let s = lower - 1, e = upper - 1
        
        return Array(band.words[s...e])
    }
    
    func randomMeanings(count: Int, pos: String?) -> [String] {
        guard let bands = try? dataSource.loadBands().bands else { return [] }
        let flat = bands.flatMap { $0.words }
        let pool = pos.map { p in flat.filter { $0.pos == p } } ?? flat
        return Array(pool.shuffled().prefix(count)).map { $0.meaning }
    }

    func randomWord(category: NgslWordCategory) -> NgslWord? {
        guard let band = try? dataSource.loadBands().bands.first(where: { $0.category == category }) else { return nil }
        return band.words.randomElement()
    }
}
