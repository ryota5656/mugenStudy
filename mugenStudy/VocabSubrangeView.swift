import SwiftUI

struct VocabSubrangeView: View {
    let rangeLabel: String // 例: "0-200"

    private var subranges: [String] {
        // 10語ごとに分割したラベルを生成: 1-10, 11-20, ...
        let parts = rangeLabel.split(separator: "-")
        guard parts.count == 2, let upper = Int(parts[1]) else { return [] }
        let step = 10
        let count = max(upper / step, 0)
        return (0..<count).map { idx in
            let start = idx * step + 1
            let end = (idx + 1) * step
            return "\(start)-\(end)"
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(subranges, id: \.self) { label in
                    NavigationLink {
                        let range = parseRange(label)
                        ToeicVocabularyView(range: range)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(label)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("この範囲の単語から出題")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            ZStack(alignment: .topTrailing) {
                                Color.baseColor
                                Circle().fill(Color.white.opacity(0.22)).frame(width: 72).offset(x: 16, y: -24)
                                Circle().fill(Color.white.opacity(0.12)).frame(width: 120).offset(x: -8, y: -40)
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.baseColor.opacity(0.28), radius: 10, x: 0, y: 6)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .navigationTitle(rangeLabel)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private func parseRange(_ label: String) -> ClosedRange<Int> {
        let parts = label.split(separator: "-")
        guard parts.count == 2, let s = Int(parts[0]), let e = Int(parts[1]) else {
            return 1...10
        }
        return s...e
    }
}

#Preview {
    NavigationView { VocabSubrangeView(rangeLabel: "0-200") }
}


