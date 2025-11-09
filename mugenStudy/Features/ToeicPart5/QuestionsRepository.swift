import Foundation
import FirebaseFirestore

// MARK: - Repository Protocols
protocol QuestionsRepository {
    func save(items: [ToeicQuestion], level: Int?) async throws
    func fetchLatestFromCache(limit: Int) async throws -> [ToeicQuestion]
    func fetchPage(from date: Date?, descending: Bool, pageSize: Int) async throws -> [ToeicQuestion]
    func existsNewerThan(since date: Date) async throws -> Bool
    func incrementChoice(questionId: UUID, choiceIndex: Int) async
}

// MARK: - Firebase-backed Implementation
final class FirebaseQuestionsRepository: QuestionsRepository {
    private let service: FirebaseService
    init(service: FirebaseService = FirebaseService()) {
        self.service = service
    }

    func save(items: [ToeicQuestion], level: Int?) async throws {
        try await service.saveQuestions(collection: "toeic_part5_items", items: items, level: level)
    }

    func fetchLatestFromCache(limit: Int) async throws -> [ToeicQuestion] {
        try await service.fetchQuestions(collection: "toeic_part5_items", limit: limit, source: .cache)
    }

    func fetchPage(from date: Date?, descending: Bool, pageSize: Int) async throws -> [ToeicQuestion] {
        try await service.fetchQuestionsPage(
            collection: "toeic_part5_items",
            from: date,
            descending: descending,
            pageSize: pageSize
        ).items
    }

    func existsNewerThan(since date: Date) async throws -> Bool {
        try await service.existsNewerThan(collection: "toeic_part5_items", since: date)
    }

    func incrementChoice(questionId: UUID, choiceIndex: Int) async {
        await service.incrementChoiceCountRTDB(questionId: questionId, choiceIndex: choiceIndex)
    }
}


