import SwiftUI
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

struct ComicView: View {
    let panels: [ComicPanel]
    @State private var selection: Int = 0

    var body: some View {
        VStack(spacing: 28) {
            Text("Comic Generator")
                .font(.system(size: 42, weight: .bold, design: .default))
            Text("Tap through the illustrated saga of your chats.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
            TabView(selection: $selection) {
                ForEach(Array(panels.enumerated()), id: \.element.id) { index, panel in
                    comicPanel(panel, index: index)
                        .tag(index)
                        .padding(.horizontal)
                }
            }
#if os(macOS)
            .tabViewStyle(.automatic)
#else
            .tabViewStyle(.page(indexDisplayMode: .automatic))
#endif
            .frame(height: 520)
        }
        .padding(44)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [.yellow.opacity(0.12), .orange.opacity(0.1)], startPoint: .top, endPoint: .bottom))
        .navigationTitle("Comic Generator")
    }

    private func comicPanel(_ panel: ComicPanel, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(panel.title)
                .font(.system(size: 30, weight: .semibold))

            ZStack(alignment: .bottomLeading) {
                panelImage(for: panel)
                    .frame(height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(style: StrokeStyle(lineWidth: 4, dash: [14, 8]))
                            .foregroundStyle(Color.black.opacity(0.18))
                    )

                if !panel.dialogue.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(panel.dialogue, id: \.self) { line in
                            Text(line)
                                .font(.system(size: 16, weight: .medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                    .padding(20)
                }
            }

            Text(panel.caption)
                .font(.system(size: 19))
                .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private func panelImage(for panel: ComicPanel) -> some View {
        if let data = panel.imageData, let image = makeImage(from: data) {
            image
                .resizable()
                .scaledToFill()
        } else {
            VStack(spacing: 12) {
                Image(systemName: "square.fill.text.grid.1x2")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange)
                Text(panel.imagePrompt)
                    .font(.system(size: 17, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.9))
        }
    }

    private func makeImage(from data: Data) -> Image? {
        #if os(macOS)
        guard let nsImage = PlatformImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #else
        guard let uiImage = PlatformImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #endif
    }
}
