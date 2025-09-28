import SwiftUI

struct RoastView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let roast: String

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Text("Roast My Week")
                    .font(.system(size: 46, weight: .bold, design: .default))
                    .foregroundStyle(LinearGradient(colors: [.orange, .pink, .red], startPoint: .leading, endPoint: .trailing))
                    .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 12)
                roastContent
                    .font(.system(size: 20, weight: .regular, design: .default))
                    .lineSpacing(8)
                    .padding(36)
                    .frame(maxWidth: 720, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(.white.opacity(0.15), lineWidth: 1)
                    )
                Button(action: viewModel.regenerateRoast) {
                    if viewModel.isGeneratingRoast {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .frame(width: 24, height: 24)
                    } else {
                        Label("Hit me again", systemImage: "gobackward")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 26)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.18), in: Capsule())

            }
            .padding(.vertical, 60)
            .frame(maxWidth: .infinity)
        }
        .background(AnimatedGradient())
        .navigationTitle("Roast My Week")
    }

    private var placeholder: String {
        "GPT-5 is still sharpening its jokes. For now, imagine your future self teasing you about debugging at 3 AM."
    }

}

extension RoastView {
    private var normalizedRoast: String {
        roast.replacingOccurrences(of: "•", with: "-")
    }

    private var roastBullets: [String] {
        normalizedRoast
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap { line in
                guard line.hasPrefix("-") else { return nil }
                let trimmed = line.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
    }

    @ViewBuilder
    private var roastContent: some View {
        if roast.isEmpty {
            Text(placeholder)
        } else if !roastBullets.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(roastBullets.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 10) {
                        Text("•")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.orange)
                        Text(line)
                            .font(.system(size: 19, weight: .medium))
                    }
                }
            }
        } else {
            Text(roast)
        }
    }
}

private struct AnimatedGradient: View {
    @State private var animate = false

    var body: some View {
        LinearGradient(colors: [.black, .pink.opacity(0.8), .orange], startPoint: animate ? .bottomTrailing : .topLeading, endPoint: animate ? .topLeading : .bottomTrailing)
            .ignoresSafeArea()
            .task {
                withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                    animate.toggle()
                }
            }
    }
}
