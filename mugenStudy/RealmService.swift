import Foundation

// MARK: - Protocol (storage abstraction)
protocol AnswerHistoryStoring {
    func save(questionId: UUID, isCorrect: Bool)
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
    @Persisted var createdAt: Date
    @Persisted var updatedAt: Date
}

final class RealmAnswerHistoryStore: AnswerHistoryStoring {
    func save(questionId: UUID, isCorrect: Bool) {
        do {
            print(Realm.Configuration.defaultConfiguration.fileURL!)
            
            let realm = try Realm()
            try realm.write {
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
}

#else

// MARK: - No-op fallback when RealmSwift is unavailable
final class NoopAnswerHistoryStore: AnswerHistoryStoring {
    func save(questionId: UUID, isCorrect: Bool) {
        // no-op
    }
}

#endif


