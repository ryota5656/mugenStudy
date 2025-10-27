
import SwiftUI
import FoundationModels

struct ToeicVocabularyMenuView: View {
    private let vocabRanges: [String] = ["0-200", "200-400", "400-600", "600-800", "800-1000", "1000-1200"]
    private let part5Ranges: [String] = ["A1 (〜300)", "A2 (〜400)", "B1 (〜600)", "B2 (〜785)", "C1 (〜860)"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                PlanCard2(
                    level: "Toeic",
                    title: "TOEIC Vocabulary",
                    dateText: "AIで生成された例文とともに英単語を学べる\nNGSL(TOEIC英単語92%に対応)をベースに\n基本単語1000語・頻出単語1222語を収録",
                    color: Color.baseColor,
                    listItems: vocabRanges
                )
                .padding(.bottom, 16)

                PlanCard2(
                    level: "Toeic",
                    title: "TOEIC Part5",
                    dateText: "TOEIC PART5風の問題をAIで生成\nA1-C1(toeic300-860)の範囲の問題に挑戦\n",
                    color: Color.baseColor,
                    listItems: part5Ranges
                )
                .padding(.bottom, 16)

                Spacer()
            }
        }
        .padding()
        .navigationTitle("Vocabulary Questions")
    }
}

struct PlanCard2: View {
    let level: String
    let title: String
    let dateText: String
    let color: Color
    var listItems: [String] = []

    @State private var isExpanded: Bool = false

    init(level: String, title: String, dateText: String, color: Color, listItems: [String] = []) {
        self.level = level
        self.title = title
        self.dateText = dateText
        self.color = color
        self.listItems = listItems
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header area (tap to toggle)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(level)
                            .font(.caption.bold())
                            .foregroundStyle(.black.opacity(0.6))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.65), in: Capsule())
                        Spacer()
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .foregroundStyle(.white.opacity(0.9))
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
                    }
                    Label(title, systemImage: "pencil.tip")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text(dateText)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { isExpanded.toggle() } }
            .zIndex(1) // ヘッダーをリストより前面に

            // Expanded list panel
            if isExpanded && !listItems.isEmpty {
                VStack(spacing: 8) {
                    ForEach(listItems, id: \.self) { item in
                        NavigationLink {
                            if title == "TOEIC Vocabulary" {
                                VocabSubrangeView(rangeLabel: item)
                            } else {
                                EmptyView()
                            }
                        } label: {
                            HStack {
                                Text("TOEIC問題 \(item)")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding(.top, 8) // ヘッダーと重ならない余白
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity.combined(with: .move(edge: .bottom))
                ))
                .zIndex(0)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack(alignment: .topTrailing) {
                color
                Circle().fill(Color.white.opacity(0.3)).frame(width: 90).offset(x: 24, y: -24)
                Circle().fill(Color.white.opacity(0.18)).frame(width: 140).offset(x: -10, y: -50)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color(hex: 0x7452FF).opacity(0.15), radius: 12, x: 0, y: 8)
    }
}

#Preview {
    ToeicVocabularyMenuView()
}
