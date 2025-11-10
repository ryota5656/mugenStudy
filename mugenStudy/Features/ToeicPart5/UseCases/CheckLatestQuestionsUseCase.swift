import Foundation

protocol CheckLatestQuestionsUseCase {
    func execute() async throws -> [ToeicQuestion]
}

final class DefaultCheckLatestQuestionsUseCase: CheckLatestQuestionsUseCase {
    private let questionsRepo: QuestionsRepository
    init(questionsRepo: QuestionsRepository) {
        self.questionsRepo = questionsRepo
    }

    func execute() async throws -> [ToeicQuestion] {
        // まずキャッシュから直近1件取得
        let cached = try await questionsRepo.fetchLatestFromCache(limit: 1)
        if let first = cached.first {
            // サーバにより新しいものがあるかチェック
            let hasNewer = try await questionsRepo.existsNewerThan(since: first.updatedAt)
            if hasNewer {
                // その日時以降を昇順で取得
                return try await questionsRepo.fetchPage(from: first.updatedAt, descending: false, pageSize: 10)
            } else {
                // 既存のキャッシュに問題なければ通常のページングで10件取得（昇順で埋める）
                return try await questionsRepo.fetchPage(from: nil, descending: false, pageSize: 10)
            }
        } else {
            // キャッシュ空なら通常のページングで取得
            return try await questionsRepo.fetchPage(from: nil, descending: false, pageSize: 10)
        }
    }
}


