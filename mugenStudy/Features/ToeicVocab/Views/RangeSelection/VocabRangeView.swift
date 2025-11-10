import SwiftUI
import GoogleMobileAds
import StoreKit

struct VocabRangeView: View {
    @StateObject private var vm: VocabRangeViewModel
    @State private var isHeaderExpanded: Bool = false
    @StateObject private var adManager = InterstitialAdManager(adUnitID: Bundle.main.object(forInfoDictionaryKey: "GAD_AT_CREATE_TOEIC5") as? String)
    @State private var hostViewController: UIViewController? = nil
    @ObservedObject private var subscriptionManager = StoreKitSubscriptionManager.shared
    @State private var showSubscriptionAlert: Bool = false

    init(type: NgslWordCategory, rangeLabel: VocabRange) {
        _vm = StateObject(wrappedValue: VocabRangeViewModel(type: type, item: rangeLabel))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            header
            
            wordList
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("Vocabulary Questions")
        .task {
            await vm.ensureInitialized()
            adManager.delegate = vm
        }
        .background(
            HostControllerReader { vc in
                self.hostViewController = vc
            }
            .frame(width: 0, height: 0)
        )
        // 画面下にフッターを固定表示（List の上に表示される）
        .safeAreaInset(edge: .bottom) {
            footer
                .padding(.horizontal)
        }
        .onChange(of: vm.shouldNavigateToSession) { isActive in
            if !isActive {
                adManager.reload()
            }
        }
        .onReceive(vm.sideEffects) { eff in
            switch eff {
            case .showInterstitial:
                if let vc = hostViewController {
                    adManager.presentWhenReady(from: vc, timeout: 10)
                }
            }
        }
    }
}

extension VocabRangeView {
    private var header: some View {
        DisclosureGroup(isExpanded: $isHeaderExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                // Expanded controls
                HStack {
                    Picker("出題対象", selection: $vm.filterMode) {
                        ForEach(RangeFilterMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Spacer()
                }
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "star")
                            .foregroundStyle(.blue)
                        if subscriptionManager.isSubscribed {
                            Toggle("", isOn: $vm.showFavoritesOnly)
                                .labelsHidden()
                        } else {
                            // 非会員は無効化＋タップで案内
                            HStack(spacing: 6) {
                                Toggle("", isOn: .constant(false))
                                    .labelsHidden()
                                    .disabled(true)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { showSubscriptionAlert = true }
                        }
                    }
                
                    HStack(spacing: 8) {
                        Image(systemName: "shuffle")
                            .foregroundStyle(.blue)
                        Toggle("", isOn: $vm.shuffleOn)
                            .labelsHidden()
                    }
                    Stepper(value: $vm.batchSize, in: 5...20, step: 5) {
                        Text("\(vm.batchSize)問")
                    }
                    .frame(maxWidth: 220)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("範囲選択").font(.subheadline).foregroundStyle(.secondary)
                        Text("範囲: \(vm.effectiveStart) - \(vm.effectiveEnd) / \(vm.selectedWords.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 12) {
                        Text("開始")
                        Slider(value: Binding<Double>(
                                get: { Double(vm.startIndex) },
                                set: { vm.startIndex = Int($0.rounded()); if vm.endIndex < vm.startIndex { vm.endIndex = vm.startIndex } }),
                               in: Double(1)...Double(max(vm.selectedWords.count, 1))
                        )
                        
                        Text("\(vm.startIndex)")
                            .frame(width: 44, alignment: .trailing)
                    }
                    
                    HStack(spacing: 12) {
                        Text("終了")
                        Slider(value: Binding<Double>(
                                get: { Double(vm.endIndex) },
                                set: { vm.endIndex = Int($0.rounded()); if vm.endIndex < vm.startIndex { vm.startIndex = vm.endIndex } }),
                               in: Double(1)...Double(max(vm.selectedWords.count, 1)),
                        )
                        Text("\(vm.endIndex)")
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                if vm.rangedWords.isEmpty {
                    Text("選択された条件に一致する問題がありません")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        } label: {
            // Collapsed summary
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("進捗")
                        .font(.headline)
                    let total = max(vm.progressTotal, 1)
                    ProgressView(value: total == 0 ? 0 : Double(vm.progressCorrect) / Double(total))
                    HStack(spacing: 12) {
                        Label("\(vm.progressCorrect) 正解", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                        Label("\(vm.progressIncorrect) 不正解", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Label("\(vm.progressUnlearned) 未学習", systemImage: "questionmark.circle")
                            .foregroundStyle(.gray)
                    }
                    .font(.caption)
                }
                Text("設定")
                    .font(.headline)
                
            }
            .padding(.vertical, 10)
        }
        .padding()
    }
    
    private var wordList: some View {
        List {
            ForEach(Array(vm.rangedWords.enumerated()), id: \.element.word) { index, word in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("\(index + vm.effectiveStart).")
                            .foregroundStyle(.secondary)
                        Text(word.word)
                            .font(.headline)
                        Spacer()
                        if let last = vm.lastResults[word.word] {
                            Image(systemName: last ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(last ? .blue : .red)
                                .help("前回の正誤")
                        } else {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.gray)
                        }
                        Button {
                            vm.toggleFavorite(word.word)
                        } label: {
                            Image(systemName: vm.favoriteWords.contains(word.word) ? "star.fill" : "star")
                                .foregroundStyle(vm.favoriteWords.contains(word.word) ? .yellow : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .alert("PLUS限定機能", isPresented: $showSubscriptionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("お気に入り機能はサブスク会員限定です。設定タブから加入できます。")
        }
    }
    
    private var footer: some View {
        VStack {
            Button {
                vm.onStartButtonTapped()
            } label: {
                Label("テストを開始", systemImage: "play.fill")
                    .padding(5)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.rangedWords.isEmpty)
            .background(Color.clear) // ボタン背後を透明に
            
            // ViewModelのフラグを監視し、遷移をトリガー
            NavigationLink(
                destination: VocabSessionView(words: vm.rangedWords, range: vm.batchSize),
                isActive: $vm.shouldNavigateToSession
            ) {
                EmptyView()
            }
            .hidden()
        }
        .padding()
    }
}

// 現在の UIViewController を解決するためのヘルパー
private struct HostControllerReader: UIViewControllerRepresentable {
    var onResolve: (UIViewController) -> Void
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        DispatchQueue.main.async { onResolve(vc) }
        return vc
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

#Preview {
    VocabRangeView(type: .essential, rangeLabel: .init(start: 0, end: 200))
}
