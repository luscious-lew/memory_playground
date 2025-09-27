import SwiftUI

struct FutureYouView: View {
    let message: String
    @State private var hueRotation: Angle = .degrees(0)

    var body: some View {
        VStack(spacing: 36) {
            Text("Message From Future You")
                .font(.system(size: 44, weight: .bold, design: .default))
                .foregroundStyle(.white)
                .shadow(radius: 10)
            Text(message.isEmpty ? placeholder : message)
                .font(.system(size: 20, weight: .regular, design: .default))
                .lineSpacing(10)
                .padding(38)
                .frame(maxWidth: 720)
                .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 34, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 10)
            Spacer()
        }
        .padding(64)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(radialBackground)
        .navigationTitle("Future You")
        .task {
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                hueRotation = .degrees(360)
            }
        }
    }

    private var radialBackground: some View {
        RadialGradient(colors: [.purple, .blue, .black], center: .center, startRadius: 60, endRadius: 620)
            .ignoresSafeArea()
            .hueRotation(hueRotation)
    }

    private var placeholder: String {
        "Dear present-me, remember: hydrate, celebrate small wins, and let GPT take the night shift."
    }
}
