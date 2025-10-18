import SwiftUI

struct SinglePracticeView: View {
    let question: ToeicQuestion
    @State private var selected: Int? = nil
    @State private var showExplanation: Bool = false
    @State private var displayIndex: [Int] = []
    var onSelect: (_ isCorrect: Bool, _ selectIndex: Int) -> Void
    var onNext: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(question.type.displayName)
                        .font(.subheadline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                }
                Text(question.prompt)
                    .font(.title3)
                ForEach(Array(displayIndex.enumerated()), id: \.offset) { index, choiceIndex in
                    let choice = question.choices[choiceIndex]
                    Button(action: {
                        selected = choiceIndex
                        showExplanation = true
                        let isCorrect = (choiceIndex == question.answerIndex)
                        onSelect(isCorrect, choiceIndex)
                    }) {
                        HStack(alignment: .top) {
                            Text(String(UnicodeScalar(65 + index)!)).bold()
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

                    Text("解説: \(question.explanation)")
                        .font(.body)
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity, maxHeight: 500)
                    
                    Text("英文：「\(question.filledSentence ?? "")」")
                        .font(.body)
                        .padding(.top, 4)

                    Text("日本語訳：「\(question.filledSentenceJa ?? "")」")
                        .font(.body)
                        .padding(.top, 4)
                    
                    ForEach(Array(displayIndex.enumerated()), id: \.offset) { index, choiceIndex in
                        Text("選択肢\(String(UnicodeScalar(65 + index)!))：「\(question.choiceTranslationsJa?[choiceIndex] ?? "")」")
                            .font(.body)
                            .padding(.top, 4)
                    }
                }
                
            }
            .padding()
            .onAppear {
                if displayIndex.isEmpty {
                    displayIndex = Array(0..<question.choices.count)
                    displayIndex.shuffle()
                }
            }
            .onChange(of: question.id) { _ in
                displayIndex = Array(0..<question.choices.count)
                displayIndex.shuffle()
                selected = nil
                showExplanation = false
            }
        }
    }
}

#Preview {
    let sample = ToeicQuestion(
        id: UUID(),
        type: .partOfSpeech,
        prompt: "The manager was (____) satisfied with the quarterly results.",
        choices: ["extremely", "extreme", "extremes", "more"],
        answerIndex: 0,
        explanation: "『extremely』は副詞で形容詞『satisfied』を適切に修飾できる。『extreme』は形容詞、『extremes』は名詞複数、『more』は比較級を示す語でこの文法位置には不適切。",
        filledSentence: "The manager was extremely satisfied with the quarterly results.",
        filledSentenceJa: "マネージャーは四半期の結果に非常に満足していた。",
        choiceTranslationsJa: ["非常に", "極端な", "極端なもの", "より"]
    )
    return SinglePracticeView(question: sample, onSelect: { _, _ in })
}
