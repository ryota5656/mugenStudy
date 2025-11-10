import SwiftUI

struct ToeicVocabularyMenuView: View {

    private let beginnerRanges: [VocabRange] = [
        .init(start: 0, end: 200), .init(start: 201, end: 400),
        .init(start: 401, end: 600), .init(start: 601, end: 800), .init(start: 801, end: 1000)
    ]
    
    private let frequentRanges: [VocabRange] = [
        .init(start: 0, end: 200), .init(start: 201, end: 400),
        .init(start: 401, end: 600), .init(start: 601, end: 800), .init(start: 801, end: 1000), .init(start: 1001, end: 1222)
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VocabSeriesCardView(
                    levelText: "初級",
                    titleText: "Beginner 1000",
                    descriptionText: "AIで生成された例文とともに英単語を学べる\nNGSL(TOEIC英単語92%に対応)をベースに\n基本単語約1000語収録",
                    color: .baseColor,
                    ranges: beginnerRanges,
                    rangeLabelBuilder: { range in "Beginner \(range.start)-\(range.end)" },
                    linkValueBuilder: { range in MainRoute.vocabRange(type: .essential, range: range) }
                )
                
                VocabSeriesCardView(
                    levelText: "中級/上級",
                    titleText: "Frequent Over1000",
                    descriptionText: "AIで生成された例文とともに英単語を学べる\nNGSL(TOEIC英単語92%に対応)をベースに\n頻出単語1000語以上収録",
                    color: .baseColor,
                    ranges: frequentRanges,
                    rangeLabelBuilder: { range in "Frequent \(range.start)-\(range.end)" },
                    linkValueBuilder: { range in MainRoute.vocabRange(type: .frequent1, range: range) }
                )
            }
        }
        .padding()
        .navigationTitle("Vocabulary Questions")
    }
}

struct VocabSeriesCardView: View {
    let levelText: String
    let titleText: String
    let descriptionText: String
    let color: Color
    let ranges: [VocabRange]
    let rangeLabelBuilder: (VocabRange) -> String
    let linkValueBuilder: (VocabRange) -> MainRoute

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            header
            
            if isExpanded && !ranges.isEmpty {
                rangeList
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            cardBackground(color)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color(hex: 0x7452FF).opacity(0.15), radius: 12, x: 0, y: 8)
    }
    
    private var rangeList: some View {
        VStack(spacing: 8) {
            ForEach(ranges, id: \.self) { range in
                NavigationLink(value: linkValueBuilder(range)) {
                    HStack {
                        Text(rangeLabelBuilder(range))
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .tint(.primary)
            }
        }
        .padding(.top, 8)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(levelText)
                        .font(.caption.bold())
                        .foregroundStyle(.black.opacity(0.6))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.white.opacity(0.65), in: Capsule())
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundStyle(.white.opacity(0.9))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
                }
                Label(titleText, systemImage: "pencil.tip")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text(descriptionText)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { isExpanded.toggle() } }
        .zIndex(1.0)
    }

    private func cardBackground(_ color: Color) -> some View {
        ZStack(alignment: .topTrailing) {
            color
            Circle().fill(Color.white.opacity(0.3)).frame(width: 90).offset(x: 24, y: -24)
            Circle().fill(Color.white.opacity(0.18)).frame(width: 140).offset(x: -10, y: -50)
        }
    }
}

#Preview {
    ToeicVocabularyMenuView()
}
