import SwiftUI

extension Color {
    // フォントの色をhex値で適用できる（例：#F4F5F9 -> 0xF4F5F9）
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    static var appBackground: Color { Color(hex: 0xF4F5F9) }
//    static var baseColor: Color { Color(hex: 0x5A5AF2)}
    static var baseColor: Color { .blue}
}

struct ColorImageSample: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                Rectangle()
                    .fill(Color.appBackground)
                    .frame(width: 60, height: 60)
                Text("appBackground")
            }
            HStack(spacing: 20) {
                Rectangle()
                    .fill(Color.baseColor)
                    .frame(width: 60, height: 60)
                Text("appBackground")
            }
        }
    }
}

#Preview {
    ColorImageSample()
}
