import SwiftUI
import FoundationModels

// Route設定
enum MainRoute: Hashable {
    case vocab
    case vocabRange(type: NgslWordCategory, range: VocabRange)
    case vocabSession(words: [NgslWord], range: Int)
}
extension MainRoute {
    @ViewBuilder var destination: some View {
        switch self {
        case .vocab:
            ToeicVocabularyMenuView()
                .toolbar(.hidden, for: .tabBar)
        case .vocabRange(let type, let range):
            VocabRangeView(type: type, rangeLabel: range)
        case .vocabSession(let words, let range):
            VocabSessionView(words: words, range: range)
        }
    }
}

// MainView
struct ToeicMainView: View {
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            menues
            .navigationDestination(for: MainRoute.self) { $0.destination }
        }
    }
}

extension ToeicMainView {
    private var menues: some View {
        VStack(alignment: .leading) {
            Text("MUGEN STUDY")
                .font(.system(size: 50, weight: .black, design: .default))
                .bold()
                .padding(.bottom, -15)
            
            Text("AI-powered question generation app")
                .font(.system(.body, design: .serif))
                .bold()
                .padding(.bottom, 16)
            
            PlanCard(
                level: "Toeic",
                title: "TOEIC Vocabulary",
                dateText: "AIで生成された例文とともに英単語を学べる\nNGSL(TOEIC英単語92%に対応)をベースに\n基本単語1000語・頻出単語1223語を収録",
                color: Color.baseColor,
                onTap: { path.append(MainRoute.vocab) }
            )
            .padding(.bottom, 16)
            
            Spacer()
        }
        .padding()
    }
}

struct PlanCard: View {
    let level: String
    let title: String
    let dateText: String
    let color: Color
    let onTap: () -> Void

    init(level: String, title: String, dateText: String, color: Color, onTap: @escaping () -> Void = {}) {
        self.level = level
        self.title = title
        self.dateText = dateText
        self.color = color
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(level)
                        .font(.caption.bold())
                        .foregroundStyle(.black.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.65), in: Capsule())
                    Spacer()
                }

                Label(title, systemImage: "apple.intelligence")
                    .font(.title.bold())
                    .foregroundStyle(.white)

                Text(dateText)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.7))
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
            .shadow(color: Color(hex: 0x7452FF).opacity(0.4), radius: 12, x: 0, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PlanCardButtonStyle())
    }
}

private struct PlanCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

#Preview {
    ToeicMainView()
}
