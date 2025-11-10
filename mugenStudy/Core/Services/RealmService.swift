import Foundation

// MARK: - Protocol (storage abstraction)
protocol AnswerHistoryStoring {
    func save(questionId: UUID, isCorrect: Bool)
    func recentResults(questionId: UUID, limit: Int) -> [Bool]
    func setFavorite(questionId: UUID, isFavorite: Bool)
    func isFavorite(questionId: UUID) -> Bool
}

// MARK: - Factory (decide real or noop)
enum AnswerHistoryStoreFactory {
    static func makeDefault() -> AnswerHistoryStoring {
        #if canImport(RealmSwift)
        return RealmAnswerHistoryStore()
        #else
        return NoopAnswerHistoryStore()
        #endif
    }
}

#if canImport(RealmSwift)
import RealmSwift

final class AnswerHistoryObject: Object {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var questionUUID: String
    @Persisted var totalCount: Int
    @Persisted var totalCorrect: Int
    @Persisted var isFavorite: Bool
    @Persisted var createdAt: Date
    @Persisted var updatedAt: Date
}

final class AnswerAttemptObject: Object {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var questionUUID: String
    @Persisted var isCorrect: Bool
    @Persisted var createdAt: Date
}

final class RealmAnswerHistoryStore: AnswerHistoryStoring {
    func save(questionId: UUID, isCorrect: Bool) {
        do {
            print(Realm.Configuration.defaultConfiguration.fileURL!)
            
            let realm = try Realm()
            try realm.write {
                // 直近試行レコードを追加
                let attempt = AnswerAttemptObject()
                attempt.questionUUID = questionId.uuidString
                attempt.isCorrect = isCorrect
                attempt.createdAt = Date()
                realm.add(attempt)

                if let history = realm.objects(AnswerHistoryObject.self)
                    .filter("questionUUID = %@", questionId.uuidString)
                    .first {
                    
                    // 更新
                    history.totalCount += 1
                    if isCorrect {
                        history.totalCorrect += 1
                    }
                    history.updatedAt = Date()
                } else {
                    // 新規作成
                    let obj = AnswerHistoryObject()
                    obj.questionUUID = questionId.uuidString
                    obj.totalCount = 1
                    obj.totalCorrect = isCorrect ? 1 : 0
                    obj.createdAt = Date()
                    obj.updatedAt = Date()
                    realm.add(obj)
                }
            }
        } catch {
            print("Realm save error: \(error)")
        }
    }

    func recentResults(questionId: UUID, limit: Int) -> [Bool] {
        do {
            let realm = try Realm()
            let results = realm.objects(AnswerAttemptObject.self)
                .filter("questionUUID = %@", questionId.uuidString)
                .sorted(byKeyPath: "createdAt", ascending: false)
                .prefix(limit)
            print(Array(results))
            return Array(results).map { $0.isCorrect }
        } catch {
            print("Realm fetch error: \(error)")
            return []
        }
    }

    func setFavorite(questionId: UUID, isFavorite: Bool) {
        do {
            let realm = try Realm()
            try realm.write {
                if let history = realm.objects(AnswerHistoryObject.self)
                    .filter("questionUUID = %@", questionId.uuidString)
                    .first {
                    history.isFavorite = isFavorite
                    history.updatedAt = Date()
                } else {
                    let obj = AnswerHistoryObject()
                    obj.questionUUID = questionId.uuidString
                    obj.totalCount = 0
                    obj.totalCorrect = 0
                    obj.isFavorite = isFavorite
                    obj.createdAt = Date()
                    obj.updatedAt = Date()
                    realm.add(obj)
                }
            }
        } catch {
            print("Realm setFavorite error: \(error)")
        }
    }

    func isFavorite(questionId: UUID) -> Bool {
        do {
            let realm = try Realm()
            return realm.objects(AnswerHistoryObject.self)
                .filter("questionUUID = %@", questionId.uuidString)
                .first?.isFavorite ?? false
        } catch {
            print("Realm isFavorite error: \(error)")
            return false
        }
    }
}

#else

// MARK: - No-op fallback when RealmSwift is unavailable
final class NoopAnswerHistoryStore: AnswerHistoryStoring {
    func save(questionId: UUID, isCorrect: Bool) {
        // no-op
    }
    func recentResults(questionId: UUID, limit: Int) -> [Bool] { [] }
    func setFavorite(questionId: UUID, isFavorite: Bool) { }
    func isFavorite(questionId: UUID) -> Bool { false }
}

#endif


