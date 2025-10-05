import Foundation
import FirebaseFirestore

// MARK: - Firebase (Realtime Database) minimal REST client
final class FirebaseService {
    private let db = Firestore.firestore()

    // 各itemを別ドキュメントとして一括保存（バッチ書き込み; 1バッチ最大500件）
    func saveQuestions(collection: String, items: [ToeicQuestion], level: Int? = nil) async throws {
        guard !items.isEmpty else { return }
        let batch = db.batch()
        let col = db.collection(collection)
        let baseDate = Date()
        for (index, item) in items.enumerated() {
            let doc = col.document(item.id.uuidString)
            try batch.setData(from: item, forDocument: doc, merge: true)
            let offsetDate = baseDate.addingTimeInterval(TimeInterval(60 * index))
            var meta: [String: Any] = [
                "createdAt": offsetDate,
                "updatedAt": offsetDate
            ]
            if let level = level { meta["level"] = level }
            batch.setData(meta, forDocument: doc, merge: true)
        }
        
        batch.commit { error in
            if let error = error {
                print("Error writing batch \(error)")
            } else {
                print("Batch write succeeded.")
            }
        }
    }

    // 代替: items配列を1つのドキュメントにまとめて保存したい場合
    struct ItemsEnvelope: Codable {
        let createdAt: Date
        let items: [ToeicQuestion]
    }
    func saveQuestionsAsSingleDocument(collection: String, items: [ToeicQuestion]) async throws {
        guard !items.isEmpty else { return }
        let doc = db.collection(collection).document()
        let envelope = ItemsEnvelope(createdAt: Date(), items: items)
        try await doc.setData(from: envelope)
    }

    // 保存済み問題の取得（createdAt 降順）
    func fetchQuestions(collection: String, limit: Int? = nil, source: FirestoreSource = .default) async throws -> [ToeicQuestion] {
        var query: Query = db.collection(collection).order(by: "createdAt", descending: true)
        if let limit = limit { query = query.limit(to: limit) }
        let snapshot: QuerySnapshot
        switch source {
        case .cache:
            snapshot = try await query.getDocuments(source: .cache)
        case .server:
            snapshot = try await query.getDocuments(source: .server)
        case .default:
            snapshot = try await query.getDocuments()
        @unknown default:
            snapshot = try await query.getDocuments()
        }
        var result: [ToeicQuestion] = []
        result.reserveCapacity(snapshot.documents.count)
        for doc in snapshot.documents {
            if let item = try? doc.data(as: ToeicQuestion.self) {
                result.append(item)
            }
        }
        return result
    }

    // フィルタ＆ページング対応版
    func fetchQuestionsPage(
        collection: String,
        type: QuestionType? = nil,
        from: Date? = nil,
        to: Date? = nil,
        pageSize: Int = 20,
        startAfter: DocumentSnapshot? = nil,
        source: FirestoreSource = .default
    ) async throws -> (items: [ToeicQuestion], lastSnapshot: DocumentSnapshot?) {
        var q: Query = db.collection(collection)
        if let t = type { q = q.whereField("type", isEqualTo: t.rawValue) }
        if let from = from { q = q.whereField("updatedAt", isGreaterThan: from) }
        if let to = to { q = q.whereField("updatedAt", isLessThanOrEqualTo: to) }
        q = q.order(by: "updatedAt", descending: true).limit(to: pageSize)
        if let cursor = startAfter { q = q.start(afterDocument: cursor) }

        let snapshot: QuerySnapshot
        switch source {
        case .cache:
            snapshot = try await q.getDocuments(source: .cache)
        case .server:
            snapshot = try await q.getDocuments(source: .server)
        case .default:
            snapshot = try await q.getDocuments()
        @unknown default:
            snapshot = try await q.getDocuments()
        }
        var items: [ToeicQuestion] = []
        items.reserveCapacity(snapshot.documents.count)
        for doc in snapshot.documents {
            if let item = try? doc.data(as: ToeicQuestion.self) {
                items.append(item)
            }
        }
        return (items, snapshot.documents.last)
    }
}

