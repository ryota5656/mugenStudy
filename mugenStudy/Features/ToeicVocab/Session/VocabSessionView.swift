import SwiftUI

struct VocabSessionView: View {
    @StateObject private var vm: VocabSessionViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(words: [NgslWord], range: Int) {
        _vm = StateObject(wrappedValue: VocabSessionViewModel(wordsQueue: words, range: range))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if vm.isFinished {
                    VocabResultView(
                        total: vm.total,
                        correct: vm.correctCount,
                        onRestart: { vm.restartSameRange() },
                        onContinue: (vm.hasNextRange ? { vm.startNextRange() } : nil),
                        onExit: { dismiss() }
                    )
                } else {
                    HStack {
                        Text(vm.progressText)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    if let question = vm.currentQuestion {
                        SinglePracticeView(
                            question: question,
                            onSelect: { isCorrect, index in
                                vm.submit(choice: index)
                            },
                            onNext: {
                                vm.next()
                            }
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Vocabulary Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            vm.start()
        }
        .allowsHitTesting(!vm.isLoading)
        .overlay(alignment: .center) {
            if vm.isLoading {
                ZStack {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.circular)
                        Text("生成中...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}

//#Preview {
//}
