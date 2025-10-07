import SwiftUI
import FirebaseFirestore

struct SavedQuestionListView: View {
    @StateObject private var viewModel = SavedQuestionListViewModel()

    var body: some View {
        List {
            filterSection
            if let error = viewModel.errorMessage {
                Text(error).foregroundColor(.red)
            } else if viewModel.isLoading {
                HStack { Spacer(); ProgressView("読み込み中…"); Spacer() }
            } else if viewModel.items.isEmpty {
                Text("保存済みの問題がありません")
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.items) { item in
                    NavigationLink(
                        destination:SinglePracticeView(
                            question: item,
                            onSelect: { isCorrect,selectIndex in
                                viewModel.selectChoice(index: item.id, isCorrect: isCorrect)
                            })
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.type.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(item.prompt)
                                .font(.body)
                                .lineLimit(3)
                        }
                        .padding(.vertical, 4)
                    }
                }
                if viewModel.canLoadMore {
                    HStack { Spacer();
                        Button(action: { Task { await viewModel.loadMore() } }) {
                            Text("さらに読み込む")
                        }
                        Spacer() }
                }
            }
        }
        .navigationTitle("保存済み")
        .task { await viewModel.reloadAll() }
        .refreshable { await viewModel.reloadAll() }
    }

    private var filterSection: some View {
        Section {
            HStack {
                Menu {
                    Button("すべて", action: { viewModel.setType(nil) })
                    ForEach(QuestionType.allCases) { t in
                        Button(t.displayName, action: { viewModel.setType(t) })
                    }
                } label: {
                    Label(viewModel.selectedType?.displayName ?? "タイプ: すべて", systemImage: "line.3.horizontal.decrease.circle")
                }
                Spacer()
                Menu {
                    DatePicker("開始", selection: Binding(get: { viewModel.dateFrom ?? Date() }, set: { viewModel.dateFrom = $0 }), displayedComponents: [.date])
                    DatePicker("終了", selection: Binding(get: { viewModel.dateTo ?? Date() }, set: { viewModel.dateTo = $0 }), displayedComponents: [.date])
                    Button("クリア", action: { viewModel.dateFrom = nil; viewModel.dateTo = nil; Task { await viewModel.reloadAll() } })
                } label: {
                    Label("日付", systemImage: "calendar")
                }
            }
        }
    }
}

