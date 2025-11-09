import Foundation
internal import Combine
import SwiftUI

// MARK: - Filter Mode
enum RangeFilterMode: String, CaseIterable, Identifiable {
    case all
    case incorrectOnly
    case unlearnedOnly
    var id: Self { self }
    var title: String {
        switch self {
        case .all: return "すべて"
        case .incorrectOnly: return "不正解のみ"
        case .unlearnedOnly: return "未学習のみ"
        }
    }
}

class VocabRangeViewModel: ObservableObject {
    
    @Published var allWords: [NgslWord] = []
    @Published var selectedWords: [NgslWord] = []
    @Published var showFavoritesOnly: Bool = false
    @Published var lastResults: [String: Bool] = [:]
    @Published var filterMode: RangeFilterMode = .all
    @Published var batchSize: Int = 10
    @Published var startIndex: Int = 1
    @Published var endIndex: Int = 20
    @Published var isInitialized: Bool = false
    @Published var shouldNavigateToTestScreen = false
    @Published var favoriteWords: Set<String> = []
    @Published var shuffleOn: Bool = false
    var filteredCount: Int { selectedWords.count }
    
    
    var effectiveStart: Int {
        guard !selectedWords.isEmpty else { return 0 }
        return min(max(1, startIndex), selectedWords.count)
    }
    var effectiveEnd: Int {
        guard !selectedWords.isEmpty else { return 0 }
        return max(effectiveStart, min(endIndex, selectedWords.count))
    }

    // 表示用レンジ（シャッフル考慮）
    var rangedWords: [NgslWord] {
        let base = shuffleOn ? selectedWords.shuffled() : selectedWords
        guard !base.isEmpty, effectiveStart > 0, effectiveEnd > 0 else { return [] }
        let s = effectiveStart - 1
        let e = effectiveEnd - 1
        if s > e { return [] }
        return Array(base[s...e])
    }

    // 進捗カウント（UI 表示用）
    var progressCorrect: Int { allWords.filter { lastResults[$0.word] == true }.count }
    var progressIncorrect: Int { allWords.filter { lastResults[$0.word] == false }.count }
    var progressUnlearned: Int { allWords.filter { lastResults[$0.word] == nil }.count }
    var progressTotal: Int { allWords.count }
    
    private var cancellables = Set<AnyCancellable>()
    private let repository: VocabWordsRepositoryProtocol
    private let recentResultUseCase: FetchRecentResultUseCaseProtocol
    private let favoriteUseCase: FavoriteWordUseCaseProtocol

    var type: NgslWordCategory
    var rangeLabel: VocabRange
    
    init(type: NgslWordCategory,
         item: VocabRange,
         repository: VocabWordsRepositoryProtocol = VocabWordsRepository(),
         recentResultUseCase: FetchRecentResultUseCaseProtocol = DefaultFetchRecentResultUseCase(),
         favoriteUseCase: FavoriteWordUseCaseProtocol = DefaultFavoriteWordUseCase()
    ) {
        self.type = type
        self.rangeLabel = item
        self.repository = repository
        self.recentResultUseCase = recentResultUseCase
        self.favoriteUseCase = favoriteUseCase
        setupBindings()
    }
    
    func setupBindings() {
        // showFavoritesOnlyが変わるたびに自動でdisplayItemsを更新
        $showFavoritesOnly
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isOn in
                self?.applyLikeFilter(isOn)
            }
            .store(in: &cancellables)
        
        $filterMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyFilter()
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    func loadWords() async{
        self.allWords = await repository.words(category: type, start: rangeLabel.start, end: rangeLabel.end)
        self.selectedWords = self.allWords
        refreshRecentResults()
        refreshFavorites()
    }

    @MainActor
    func ensureInitialized() async {
        if isInitialized { return }
        await loadWords()
        applyFilter()
        isInitialized = true
        endIndex = min(allWords.count, max(20, endIndex))
    }
    
    func parseRange(_ label: String) -> ClosedRange<Int> {
        let parts = label.split(separator: "-")
        guard parts.count == 2, let s = Int(parts[0]), let e = Int(parts[1]) else {
            return 1...10
        }
        return s...e
    }
    
    @MainActor
    func applyLikeFilter(_ isOn: Bool) {
        // 現状はお気に入りデータを保持していないため、トグル変更のトリガとして全体再計算のみ行う
        applyFilter()
    }

    @MainActor
    func applyFilter() {
        withAnimation(.easeInOut) {
            // まず正誤/未学習のフィルタ
            let base: [NgslWord] = {
                switch filterMode {
                case .all:
                    return allWords
                case .incorrectOnly:
                    return allWords.filter { lastResults[$0.word] == false }
                case .unlearnedOnly:
                    return allWords.filter { lastResults[$0.word] == nil }
                }
            }()
            // お気に入りのみ
            selectedWords = showFavoritesOnly
                ? base.filter { favoriteWords.contains($0.word) }
                : base
        }
    }
    
    func initializeMockLastResults() { /* no-op: Realm 履歴を利用 */ }
    
    func submitTest() {
        print(selectedWords)
        shouldNavigateToTestScreen = true
    }

    // お気に入りの切替
    func toggleFavorite(_ word: String) {
        let isFav = favoriteWords.contains(word)
        // 対象NgslWordを特定
        guard let w = allWords.first(where: { $0.word == word }) else { return }
        // 永続化（UseCase経由）
        favoriteUseCase.setFavorite(for: w, isFavorite: !isFav)
        // ローカル状態も更新
        if isFav { favoriteWords.remove(word) } else { favoriteWords.insert(word) }
        // お気に入りで絞り込み中なら、一覧を再計算
        if showFavoritesOnly { applyFilter() }
    }

    // 全単語の順序をシャッフル（必要なら再フィルタ）
    func shuffleAllWords() {
        allWords.shuffle()
        applyFilter()
    }

    // デバッグ用: レンジ内のテスト結果をランダム更新
    func simulateTestProgress() {
        var map = lastResults
        for w in rangedWords {
            map[w.word] = Bool.random()
        }
        lastResults = map
    }

    // Realm の最近の履歴から直近の正誤を再構築
    func refreshRecentResults(limit: Int = 1) {
        var map: [String: Bool] = [:]
        for w in allWords {
            if let latest = recentResultUseCase.latestIsCorrect(for: w) {
                map[w.word] = latest
            }
        }
        lastResults = map
    }

    // Realm のお気に入り状態をメモリへ反映
    func refreshFavorites() {
        var set: Set<String> = []
        for w in allWords {
            if favoriteUseCase.isFavorite(for: w) {
                set.insert(w.word)
            }
        }
        favoriteWords = set
    }
}

