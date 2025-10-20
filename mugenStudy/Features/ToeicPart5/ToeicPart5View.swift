import SwiftUI
import Foundation
import GoogleMobileAds

// MARK: - View
struct ToeicPart5View: View {
    @StateObject private var viewModel = ToeicPart5ViewModel()
    @StateObject private var adManager = InterstitialAdManager(adUnitID: Bundle.main.object(forInfoDictionaryKey: "GAD_AT_CREATE_TOEIC5") as? String)
    
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
                .alert(isPresented: $viewModel.showErrorAlert) {
                    Alert(
                        title: Text("エラー"),
                        message: Text(viewModel.errorMessage ?? "不明なエラーが発生しました"),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .onAppear {
                adManager.delegate = viewModel
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
            HStack {
                Button(action: {
                    Task {
                        adManager.presentWhenReady(timeout: 10)
                        await viewModel.checklatestQuestion()
                    }
                }) {
                    HStack {
                        if viewModel.isLoading { ProgressView() }
                        Text("問題を生成")
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: {
                    Task {
                        adManager.presentWhenReady(timeout: 10)
                        await viewModel.fetchQuestions()
                    }
                }) {
                    HStack {
                        if viewModel.isLoading { ProgressView() }
                        Text("AI問題を生成")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private var contentSection: some View {
        Group {
            if let error = viewModel.errorMessage {
                Text(error).foregroundColor(.red)
            } else if viewModel.isLoading {
                ProgressView("生成中…")
            } else if let q = viewModel.currentQuestion {
                SinglePracticeView(
                    question: q,
                    onSelect: {isCorrect,selectIndex in
                        viewModel.selectChoice(selectIndex)
                    })
                Button(action: { viewModel.goNext() }) {
                    Text(viewModel.isLastQuestion ? "終了" : "次へ")
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("上のボタンから問題を生成してください")
            }
        }
    }
}

#Preview {
    ToeicPart5View()
}
