import SwiftUI
import FoundationModels

private enum MainRoute: Hashable {
    case vocab
    case part5
}

struct ToeicMainView: View {
    @State private var path: [MainRoute] = []
    var body: some View {
        NavigationStack(path: $path) {
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
                    dateText: "AIで生成された例文とともに英単語を学べる\nNGSL(TOEIC英単語92%に対応)をベースに\n基本単語1000語・頻出単語1222語を収録",
                    color: Color.baseColor,
                    onTap: { path.append(.vocab) }
                )
                .padding(.bottom, 16)
                
                PlanCard(
                    level: "Toeic",
                    title: "TOEIC Part5",
                    dateText: "TOEIC PART5風の問題をAIで生成\nA1-C1(toeic300-860)の範囲の問題に挑戦\n",
                    color: Color.baseColor,
                    onTap: { path.append(.part5) }
                )
                .padding(.bottom, 16)
                
                Spacer()
            }
            .padding()
            .background(
                ZStack(alignment: .bottomTrailing) {
                    Color.white
                    Image("kawaii1")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300)
                        .offset(x: 60, y: 100)
                        .padding()
                        .allowsHitTesting(false)
                }
            )
            .navigationDestination(for: MainRoute.self) { route in
                switch route {
                case .vocab:
                    ToeicVocabularyMenuView()
                case .part5:
                    ToeicPart5View()
                }
            }
        }
    }
}

private struct DateCarousel: View {
    @Binding var selectedIndex: Int
    let days: [String] = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<7, id: \.self) { idx in
                    VStack(spacing: 6) {
                        Text(days[idx])
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(11+idx)")
                            .font(.subheadline.bold())
                            .foregroundStyle(selectedIndex == idx ? .white : .primary)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(selectedIndex == idx ? Color.black : Color.clear)
                            )
                    }
                    .onTapGesture { selectedIndex = idx }
                }
            }
            .padding(.vertical, 8)
        }
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
                    // action icons can be added here if needed
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

struct CircleIcon: View {
    let system: String
    var body: some View {
        Image(systemName: system)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.black.opacity(0.7))
            .frame(width: 28, height: 28)
            .background(Color.white.opacity(0.7))
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    static var appBackground: Color { Color(hex: 0xF4F5F9) }
    static var baseColor: Color { Color(hex: 0x5A5AF2)}
}

extension UIImage {
    func resize(size _size: CGSize) -> UIImage? {
        let widthRatio = _size.width / size.width
        let heightRatio = _size.height / size.height
        let ratio = widthRatio < heightRatio ? widthRatio : heightRatio

        let resizedSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        UIGraphicsBeginImageContextWithOptions(resizedSize, false, 0.0)
        draw(in: CGRect(origin: .zero, size: resizedSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage
    }
}

#Preview {
    ToeicMainView()
}
