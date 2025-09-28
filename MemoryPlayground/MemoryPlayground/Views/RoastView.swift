import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

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
            VStack {
                Text(placeholder)
                    .font(.system(size: 18))
                    .padding(36)
            }
            .frame(maxWidth: 720)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        } else if !roastBullets.isEmpty {
            thematicRoastLayout(messages: Array(roastBullets.prefix(3)))
        } else {
            Text(roast)
        }
    }

    @ViewBuilder
    private func thematicRoastLayout(messages: [String]) -> some View {
        let roasts = paddedRoasts(messages)
        VStack {
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )

                GeometryReader { geo in
                    let width = geo.size.width
                    let height = geo.size.height
                    let topSpacing = height * 0.15
                    let bubbleWidth = min(width * 0.5, 360)

                    VStack(spacing: height * 0.2) {
                        HStack(alignment: .top, spacing: width * 0.16) {
                            RoastBubbleView(message: roasts[0], avatarColor: .pink)
                                .frame(width: bubbleWidth)
                            RoastBubbleView(message: roasts[1], avatarColor: .orange)
                                .frame(width: bubbleWidth)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                        RoastBubbleView(message: roasts[2], avatarColor: .purple)
                            .frame(width: min(width * 0.6, 420))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.top, topSpacing)
                    .padding(.horizontal, width * 0.12)

                    centralProfile
                        .frame(width: 170, height: 170)
                        .position(x: width / 2, y: height * 0.46)
                }
                .frame(height: 520)
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            }
            .frame(maxWidth: 900)
        }
    }

    private func paddedRoasts(_ roasts: [String]) -> [String] {
        if roasts.count >= 3 { return Array(roasts.prefix(3)) }
        var result = roasts
        while result.count < 3 {
            result.append("Waiting for more roast material…")
        }
        return result
    }

    @ViewBuilder
    private var centralProfile: some View {
        if let profileImage = platformProfileImage() {
            profileImage
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 6))
                .shadow(radius: 16)
        } else {
            ZStack {
                Circle().fill(Color.white.opacity(0.2))
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .padding(18)
            }
        }
    }

    private func platformProfileImage() -> Image? {
        #if os(macOS)
        if let nsImage = NSImage(named: "roast_profile") {
            return Image(nsImage: nsImage)
        }
        #else
        if let uiImage = UIImage(named: "roast_profile") {
            return Image(uiImage: uiImage)
        }
        #endif
        return nil
    }
}

private struct RoastBubbleView: View {
    let message: String
    let avatarColor: Color

    var body: some View {
        VStack(spacing: 12) {
            SpeechBubble()
                .fill(Color.white.opacity(0.95))
                .overlay(
                    Text(message)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                )
                .shadow(color: .black.opacity(0.1), radius: 6, y: 4)

            Circle()
                .fill(avatarColor.gradient)
                .frame(width: 58, height: 58)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 24, weight: .bold))
                )
                .shadow(radius: 5)
        }
    }
}

private struct SpeechBubble: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 18
        let tailWidth: CGFloat = 20
        let tailHeight: CGFloat = 14

        let bubbleRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tailHeight)
        path.addRoundedRect(in: bubbleRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))

        let tailStartX = bubbleRect.midX - tailWidth / 2
        path.move(to: CGPoint(x: tailStartX, y: bubbleRect.maxY))
        path.addLine(to: CGPoint(x: tailStartX + tailWidth / 2, y: bubbleRect.maxY + tailHeight))
        path.addLine(to: CGPoint(x: tailStartX + tailWidth, y: bubbleRect.maxY))
        path.closeSubpath()

        return path
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
