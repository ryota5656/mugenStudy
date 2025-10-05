import SwiftUI
import Foundation

// MARK: - View
struct ToeicPart5View: View {
    @StateObject private var viewModel = ToeicPart5ViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    settingsSection
                    Divider()
                    contentSection
                }
                .padding()
                .navigationTitle("mugenTOEICpart5")
            }
        }
    }
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("スコア帯")
                .font(.headline)
            Picker("レベル", selection: $viewModel.selectedLevel) {
                ForEach(ToeicLevel.allCases) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(.segmented)
            
            Text("出題カテゴリ（複数選択可）")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(QuestionType.allCases) { t in
                        Toggle(isOn: Binding(
                            get: { viewModel.selectedTypes.contains(t) },
                            set: { isOn in
                                if isOn { viewModel.selectedTypes.insert(t) } else { viewModel.selectedTypes.remove(t) }
                            }
                        )) {
                            Text(t.displayName)
                        }
                        .toggleStyle(.button)
                    }
                }
            }
            
            Button(action: {
                Task { await viewModel.fetchQuestions2() }
            }) {
                HStack {
                    if viewModel.isLoading { ProgressView() }
                    Text("問題を生成")
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var contentSection: some View {
        Group {
            if let error = viewModel.errorMessage {
                Text(error).foregroundColor(.red)
            } else if viewModel.isLoading {
                ProgressView("生成中…")
            } else if let q = viewModel.currentQuestion {
                questionView(q)
            } else {
                Text("上のボタンから問題を生成してください")
            }
        }
    }
    
    @ViewBuilder
    private func questionView(_ q: ToeicQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(q.type.displayName)
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                Spacer()
                Text("\(viewModel.currentIndex + 1) / \(viewModel.questions.count)")
                    .font(.subheadline)
            }
            Text(q.prompt)
                .font(.title3)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(q.choices.enumerated()), id: \.offset) { idx, choice in
                    Button(action: { viewModel.selectChoice(idx) }) {
                        HStack(alignment: .top) {
                            Text(String(UnicodeScalar(65 + idx)!))
                                .bold()
                            Text(choice)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.showExplanation)
                }
            }
            
            if viewModel.showExplanation, let selected = viewModel.selectedChoiceIndex {
                let isCorrect = selected == q.answerIndex
                HStack(spacing: 8) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isCorrect ? .green : .red)
                    Text(isCorrect ? "正解！" : "不正解")
                        .bold()
                }
                Text("解説: \(q.explanation)")
                    .font(.body)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, maxHeight: 500)
                Text("英文：「\(q.filledSentence ?? "")」")
                    .font(.body)
                    .padding(.top, 4)
                Text("日本語訳：「\(q.filledSentenceJa ?? "")」")
                    .font(.body)
                    .padding(.top, 4)
                ForEach(Array((q.choiceTranslationsJa ?? []).enumerated()), id: \.offset) { idx, choice in
                    Text("選択肢\(String(UnicodeScalar(65 + idx)!))：「\(choice)」")
                        .font(.body)
                        .padding(.top, 4)
                }

                Button(action: { viewModel.goNext() }) {
                    Text(viewModel.isLastQuestion ? "終了" : "次へ")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    ToeicPart5View()
}
