import SwiftUI

struct Avatar: View {
    let login: String
    var hue: Double = 200
    var size: CGFloat = 16

    var body: some View {
        let initial = String(login.prefix(1)).uppercased()
        let top = Color(hue: hue / 360, saturation: 0.45, brightness: 0.78)
        let bottom = Color(hue: ((hue + 40).truncatingRemainder(dividingBy: 360)) / 360,
                           saturation: 0.55, brightness: 0.62)
        ZStack {
            LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(initial)
                .font(.system(size: size * 0.5, weight: .semibold, design: .default))
                .foregroundStyle(.white.opacity(0.95))
                .kerning(-0.2)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(.black.opacity(0.15), lineWidth: 0.5)
        )
    }
}

struct Chip: View {
    var systemImage: String? = nil
    let text: String

    var body: some View {
        HStack(spacing: 3) {
            if let s = systemImage {
                Image(systemName: s)
                    .font(.system(size: 8.5))
                    .foregroundStyle(.secondary)
            }
            Text(text)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 5)
        .frame(height: 16)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
        .frame(maxWidth: 120)
    }
}
