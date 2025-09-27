import SwiftUI

struct ComicView: View {
    let panels: [ComicPanel]
    @State private var selection: Int = 0

    var body: some View {
        VStack(spacing: 26) {
            Text("Comic Generator")
                .font(.system(size: 42, weight: .bold, design: .default))
            Text("Swipe through the saga of your week.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
            TabView(selection: $selection) {
                ForEach(Array(panels.enumerated()), id: \.element.id) { index, panel in
                    comicPanel(panel)
                        .tag(index)
                }
            }
            .tabViewStyle(.automatic)
            .frame(height: 430)
        }
        .padding(44)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [.yellow.opacity(0.12), .orange.opacity(0.1)], startPoint: .top, endPoint: .bottom))
        .navigationTitle("Comic Generator")
    }

    private func comicPanel(_ panel: ComicPanel) -> some View {
        VStack(spacing: 18) {
            Text(panel.title)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.primary)
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(style: StrokeStyle(lineWidth: 5, dash: [14, 8]))
                            .foregroundStyle(Color.black.opacity(0.4))
                    )
                VStack(spacing: 18) {
                    Text(panel.illustrationPrompt)
                        .font(.system(size: 18, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
                    Text(panel.caption)
                        .font(.system(size: 18))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(34)
            }
            .frame(height: 310)
        }
        .padding()
    }
}
