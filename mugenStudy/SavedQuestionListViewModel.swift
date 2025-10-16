import Foundation
internal import Combine
import FirebaseFirestore

final class SavedQuestionListViewModel: ObservableObject {
    @Published private(set) var items: [ToeicQuestion] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var selectedType: QuestionType? = nil
    @Published var dateFrom: Date? = nil
    @Published var dateTo: Date? = nil
    @Published private(set) var canLoadMore: Bool = false
    

    private let answerStore: AnswerHistoryStoring
    private let firebase: FirebaseService
    private var lastSnapshot: DocumentSnapshot? = nil {
        didSet { canLoadMore = lastSnapshot != nil }
    }

    init(firebase: FirebaseService = FirebaseService(), answerStore: AnswerHistoryStoring = AnswerHistoryStoreFactory.makeDefault()) {
        self.firebase = firebase
        self.answerStore = answerStore
    }

    func setType(_ type: QuestionType?) {
        selectedType = type
        Task { await reloadAll() }
    }

    @MainActor
    private func setLoadingState() {
        isLoading = true
        errorMessage = nil
        items = []
        lastSnapshot = nil
    }

    func reloadAll() async {
        await MainActor.run { self.setLoadingState() }

        // Phase 1: cache 即時表示
        do {
            let page = try await firebase.fetchQuestionsPage(
                collection: "toeic_part5_items",
                type: selectedType,
                from: dateFrom,
                to: dateTo,
                pageSize: 20,
                startAfter: nil,
                source: .cache
            )
            await MainActor.run {
                self.items = page.items
                self.lastSnapshot = page.lastSnapshot
            }
        } catch {
            // ignore cache miss
        }

        // Phase 2: サーバーから差分のみ取得してマージ
//        let maxUpdatedAt: Date? = items.map { $0.updatedAt }.max()
//        let effectiveFrom: Date? = {
//            switch (dateFrom, maxUpdatedAt) {
//            case (nil, nil): return nil
//            case (let a?, nil): return a
//            case (nil, let b?): return b
//            case (let a?, let b?): return max(a, b)
//            }
//        }()
//
//        if effectiveFrom != nil {
//            do {
//                let delta = try await firebase.fetchQuestionsPage(
//                    collection: "toeic_part5_items",
//                    type: selectedType,
//                    from: effectiveFrom,
//                    to: dateTo,
//                    pageSize: 20,
//                    startAfter: nil
//                )
//                await MainActor.run {
//                    if !delta.items.isEmpty {
//                        let combined = delta.items + self.items
//                        var seen: Set<UUID> = []
//                        let deduped: [ToeicQuestion] = combined.filter { q in
//                            if seen.contains(q.id) { return false }
//                            seen.insert(q.id)
//                            return true
//                        }
//                        self.items = deduped.sorted { $0.updatedAt > $1.updatedAt }
//                        // lastSnapshot はキャッシュ側のものを維持
//                    }
//                }
//            } catch {
//                // 差分取得失敗は黙ってスキップ（キャッシュ表示は維持）
//            }
//        } else {
//            // キャッシュが空などの場合は通常の1ページを取得
//            await loadMore()
//        }

        await MainActor.run { self.isLoading = false }
    }

    func loadMore() async {
        do {
            let page = try await firebase.fetchQuestionsPage(
                collection: "toeic_part5_items",
                type: selectedType,
                from: dateFrom,
                to: dateTo,
                pageSize: 20,
                startAfter: lastSnapshot,
                source: .cache
            )
            await MainActor.run {
                if !page.items.isEmpty {
                    let combined = self.items + page.items
                    var seen: Set<UUID> = []
                    self.items = combined.filter { q in
                        if seen.contains(q.id) { return false }
                        seen.insert(q.id)
                        return true
                    }
                }
                self.lastSnapshot = page.lastSnapshot
            }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }
    }
    
    func selectChoice(index: UUID, isCorrect: Bool) {
        answerStore.save(questionId: index, isCorrect: isCorrect)
    }
}

