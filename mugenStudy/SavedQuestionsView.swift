import SwiftUI
import FirebaseFirestore

struct SavedQuestionsView: View {
    @StateObject private var viewModel = SavedQuestionsViewModel()

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
                    NavigationLink(destination: SinglePracticeView(question: item, viewModel: viewModel)) {
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

struct SinglePracticeView: View {
    let question: ToeicQuestion
    @State private var selected: Int? = nil
    @State private var showExplanation: Bool = false
    @ObservedObject var viewModel: SavedQuestionsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(question.prompt)
                    .font(.title3)
                ForEach(Array(question.choices.enumerated()), id: \.offset) { idx, choice in
                    Button(action: {
                        selected = idx
                        showExplanation = true
                        let isCorrect = (idx == question.answerIndex)
                        viewModel.selectChoice(index: question.id, isCorrect: isCorrect)
                    }) {
                        HStack(alignment: .top) {
                            Text(String(UnicodeScalar(65 + idx)!)).bold()
                            Text(choice).multilineTextAlignment(.leading)
                            Spacer()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(showExplanation)
                }

                if showExplanation, let s = selected {
                    let isCorrect = (s == question.answerIndex)
                    HStack(spacing: 8) {
                        Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isCorrect ? .green : .red)
                        Text(isCorrect ? "正解！" : "不正解").bold()
                    }
                    if !question.explanation.isEmpty {
                        Text("解説: \(question.explanation)")
                            .padding(.top, 4)
                    }
                    if let filled = question.filledSentence { Text("英文: \(filled)") }
                    if let ja = question.filledSentenceJa { Text("日本語訳: \(ja)") }
                }
            }
            .padding()
        }
        .navigationTitle("単問演習")
    }
}
