import SwiftUI
import FoundationModels

struct ToeicVocabularyView: View {
    @StateObject private var viewModel = ToeicVocabularyViewModel()
    
    // セッションの準備
    let session = LanguageModelSession()
    
    private var canSend: Bool {
        !viewModel.isLoading &&
        !viewModel.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !viewModel.userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
            NavigationView {
                ScrollView {
                    VStack(spacing: 20) {
                        // Instructions入力エリア
                        VStack(alignment: .leading, spacing: 8) {
                            Text("指示文（Instructions）")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextEditor(text: $viewModel.instructions)
                                .frame(minHeight: 80)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                        }
                        
                        // ユーザー入力エリア
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ユーザー入力")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextEditor(text: $viewModel.userInput)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                        }
                        
                        // 送信ボタン
                        Button {
                            viewModel.output = nil
                            viewModel.sendPrompt()
                        } label: {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(viewModel.isLoading ? "処理中..." : "送信")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(canSend ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(!canSend)
                        
                        // 出力エリア
                        if let output = viewModel.output {
                            let sample = ToeicQuestion(
                                id: UUID(),
                                type: .vocabulary,
                                prompt: output.prompt ?? "",
                                choices: ["\(viewModel.selectWord?.meaning ?? "")", "提唱者，支持者，提唱する", "余分な，余り", "社内の，オフイス間の"],
                                answerIndex: 0,
                                filledSentenceJa: output.promptJa
                            )
                            SinglePracticeView(question: sample, onSelect: { isCorrect, selectedIndex in
                            })
                            VStack(alignment: .leading, spacing: 8) {
                                Text("出力結果")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(viewModel.selectWord?.word ?? "")
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .textSelection(.enabled)
                                
                                Text(viewModel.bolded(output.prompt ?? "", keyword: viewModel.selectWord?.word ?? ""))
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .textSelection(.enabled)
                                
                                Text(output.promptJa ?? "")
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding()
                    .onTapGesture {
                        // キーボードを閉じる
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                .navigationTitle("Foundation Models Chat")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
}

#Preview("FeedChatView") {
    ToeicVocabularyView()
}

