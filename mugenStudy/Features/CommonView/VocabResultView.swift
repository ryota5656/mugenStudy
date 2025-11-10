import SwiftUI

struct VocabResultView: View {
    let total: Int
    let correct: Int
    var onRestart: () -> Void
    var onContinue: (() -> Void)? = nil
    var onExit: (() -> Void)? = nil
    @State private var progressValue: Double = 0
    @State private var appear: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Result")
                .font(.largeTitle.bold())
            Text("\(correct)/\(total) 正解")
                .font(.title3)
                .foregroundStyle(.secondary)

            ProgressView(value: progressValue, total: Double(total))
                .tint(.baseColor)

            Button(action: onRestart) {
                Text("もう一度挑戦する")
                    .bold()
            }
            .buttonStyle(.borderedProminent)
            .tint(.baseColor)
            .padding(.top, 8)

            if let onContinue {
                Button(action: onContinue) {
                    Text("続けて挑戦する")
                        .bold()
                }
                .buttonStyle(.bordered)
            }

            if let onExit {
                Button(action: onExit) {
                    Text("終了")
                        .bold()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
        .opacity(appear ? 1 : 0)
        .scaleEffect(appear ? 1 : 0.98)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                appear = true
            }
            withAnimation(.easeOut(duration: 3.0)) {
                progressValue = Double(correct)
            }
        }
    }
}

#Preview {
    VocabResultView(total: 10, correct: 5, onRestart: {}, onContinue: {}, onExit: {})
}


