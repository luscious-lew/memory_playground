import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct FutureYouView: View {
    let message: String
    let portraitData: Data?
    @State private var hueRotation: Angle = .degrees(0)

    var body: some View {
        VStack(spacing: 36) {
            portrait
            Text("Message From Future You")
                .font(.system(size: 44, weight: .bold, design: .default))
                .foregroundStyle(.white)
                .shadow(radius: 10)
            messageContent
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

    @ViewBuilder
    private var portrait: some View {
        if let portraitData, let image = makeImage(from: portraitData) {
            image
                .resizable()
                .scaledToFill()
                .frame(width: 220, height: 220)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 6))
                .shadow(radius: 18)
        }
    }

    private func makeImage(from data: Data) -> Image? {
#if canImport(AppKit)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
#elseif canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
#else
        return nil
#endif
    }
}

extension FutureYouView {
    private var normalizedMessage: String {
        message.replacingOccurrences(of: "•", with: "-")
    }

    private var adviceBullets: [String] {
        normalizedMessage
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap { line in
                guard line.hasPrefix("-") else { return nil }
                let trimmed = line.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
    }

    @ViewBuilder
    fileprivate var messageContent: some View {
        if message.isEmpty {
            Text(placeholder)
        } else if !adviceBullets.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(adviceBullets.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 12) {
                        Text("•")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                        Text(line)
                            .font(.system(size: 19, weight: .medium))
                    }
                }
            }
        } else {
            Text(message)
        }
    }
}
