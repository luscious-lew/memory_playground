import SwiftUI

struct RemixTile: View {
    let title: String
    let subtitle: String
    let gradient: LinearGradient
    let icon: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(gradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.35)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
                )
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .semibold))
                    .padding(14)
                    .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Spacer()
                Text(title)
                    .font(.system(size: 26, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(28)
        }
        .frame(height: 220)
        .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 16)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
