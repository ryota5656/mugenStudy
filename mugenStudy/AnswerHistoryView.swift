import SwiftUI

#if canImport(RealmSwift)
import RealmSwift
internal import Combine
import Realm

struct AnswerHistoryItem: Identifiable, Equatable {
    let id: String
    let questionUUID: String
    let totalCount: Int
    let totalCorrect: Int
    let createdAt: Date
    let updatedAt: Date
}

final class AnswerHistoryListModel: ObservableObject {
    @Published var items: [AnswerHistoryItem] = []
    private var notificationToken: NotificationToken?

    init() {
        reload()
        observe()
    }

    deinit {
        notificationToken?.invalidate()
    }

    private func reload() {
        do {
            let realm = try Realm()
            let results = realm.objects(AnswerHistoryObject.self)
                .sorted(byKeyPath: "createdAt", ascending: false)
            items = results.map { obj in
                AnswerHistoryItem(id: obj._id.stringValue,
                                  questionUUID: obj.questionUUID,
                                  totalCount: obj.totalCount,
                                  totalCorrect: obj.totalCorrect,
                                  createdAt: obj.createdAt,
                                  updatedAt: obj.updatedAt)
            }
        } catch {
            print("Realm read error: \(error)")
        }
    }

    private func observe() {
        do {
            let realm = try Realm()
            let results = realm.objects(AnswerHistoryObject.self)
                .sorted(byKeyPath: "createdAt", ascending: false)
            notificationToken = results.observe { [weak self] changes in
                switch changes {
                case .initial(let collection), .update(let collection, _, _, _):
                    self?.items = collection.map { obj in
                        AnswerHistoryItem(id: obj._id.stringValue,
                                          questionUUID: obj.questionUUID,
                                          totalCount: obj.totalCount,
                                          totalCorrect: obj.totalCorrect,
                                          createdAt: obj.createdAt,
                                          updatedAt: obj.updatedAt)
                    }
                case .error(let error):
                    print("Realm observe error: \(error)")
                }
            }
        } catch {
            print("Realm observe setup error: \(error)")
        }
    }
}

struct AnswerHistoryView: View {
    @StateObject private var model = AnswerHistoryListModel()

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }

    var body: some View {
        List {
            if model.items.isEmpty {
                Text("まだ履歴がありません")
                    .foregroundColor(.secondary)
            } else {
                ForEach(model.items) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("総解答数:\(item.totalCount)  正解数:\(item.totalCorrect)")
                                .bold()
                            Text("ID: \(item.questionUUID)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(dateFormatter.string(from: item.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("履歴")
    }
}

#else

struct AnswerHistoryView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("履歴")
                .font(.headline)
            Text("RealmSwift が導入されていないため履歴を表示できません。")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

#endif



