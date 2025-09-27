import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var path: [RemixDestination] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                background
                VStack(alignment: .leading, spacing: 32) {
                    header
                    remixGrid
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 36)
            }
            .overlay(alignment: .topTrailing) {
                refreshBadge
                    .padding(32)
            }
            .navigationTitle("")
            .navigationDestination(for: RemixDestination.self) { destination in
                RemixDetailContainer(path: $path, destination: destination)
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [.black, .purple.opacity(0.5), .blue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            AngularGradient(colors: [.clear, .white.opacity(0.12), .clear, .white.opacity(0.08)], center: .center)
                .blur(radius: 160)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Memory Playground")
                .font(.system(size: 54, weight: .bold, design: .default))
                .foregroundStyle(.white)
            Text("Turn your conversations into playful remixes powered by GPT-5 and Omi.")
                .font(.system(size: 20, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.85))
            if viewModel.isDemoModeEnabled {
                Label("Demo mode active — load your iMessages + Omi transcripts to remix your life.", systemImage: "sparkles")
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.15), in: Capsule())
                    .foregroundStyle(.white)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(duration: 0.6), value: viewModel.isDemoModeEnabled)
    }

    private var remixGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return ScrollView {
            LazyVGrid(columns: columns, spacing: 28) {
                ForEach(RemixDestination.allCases, id: \.self) { destination in
                    Button {
                        navigate(to: destination)
                    } label: {
                        RemixTile(
                            title: destination.title,
                            subtitle: destination.subtitle,
                            gradient: destination.gradient,
                            icon: destination.iconName
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 20)
        }
    }

    private var refreshBadge: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Button(action: viewModel.refresh) {
                Label("Refresh", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.18), in: Capsule())
            }
            .buttonStyle(.plain)
            if case .loading = viewModel.loadingState {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
        }
        .foregroundStyle(.white)
    }

    private func navigate(to destination: RemixDestination) {
        path = [destination]
    }
}

enum RemixDestination: Hashable, CaseIterable {
    case newspaper
    case roast
    case trivia
    case comic
    case future

    var title: String {
        switch self {
        case .newspaper: return "Daily Newspaper"
        case .roast: return "Roast My Week"
        case .trivia: return "Context Trivia"
        case .comic: return "Comic Generator"
        case .future: return "Future You"
        }
    }

    var subtitle: String {
        switch self {
        case .newspaper: return "Front-page drama from your chats"
        case .roast: return "Comedy roast with kindness"
        case .trivia: return "Jeopardy from inside jokes"
        case .comic: return "Panels starring your crew"
        case .future: return "Advice from tomorrow"
        }
    }

    var iconName: String {
        switch self {
        case .newspaper: return "newspaper"
        case .roast: return "flame"
        case .trivia: return "questionmark.diamond.fill"
        case .comic: return "rectangle.3.offgrid.fill"
        case .future: return "sparkles"
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .newspaper:
            return LinearGradient(colors: [.indigo, .blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .roast:
            return LinearGradient(colors: [.pink, .red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .trivia:
            return LinearGradient(colors: [.purple, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .comic:
            return LinearGradient(colors: [.yellow, .orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .future:
            return LinearGradient(colors: [.teal, .blue, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var toolbarLabel: String {
        switch self {
        case .newspaper: return "Paper"
        case .roast: return "Roast"
        case .trivia: return "Trivia"
        case .comic: return "Comic"
        case .future: return "Future"
        }
    }
}

private struct RemixDetailContainer: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Binding var path: [RemixDestination]
    let destination: RemixDestination

    var body: some View {
        destinationView
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: { path = [] }) {
                        Label("Home", systemImage: "chevron.backward")
                    }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    ForEach(RemixDestination.allCases, id: \.self) { item in
                        quickLink(destination: item)
                    }
                }
            }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch destination {
        case .newspaper:
            NewspaperView(newspaper: viewModel.dailyNewspaper)
        case .roast:
            RoastView(roast: viewModel.roast)
        case .trivia:
            TriviaView(questions: viewModel.triviaQuestions)
        case .comic:
            ComicView(panels: viewModel.comicPanels)
        case .future:
            FutureYouView(message: viewModel.futureYou)
        }
    }

    private func quickLink(destination: RemixDestination) -> some View {
        Button {
            path = [destination]
        } label: {
            Label(destination.toolbarLabel, systemImage: destination.iconName)
                .font(.system(size: 13, weight: .semibold))
        }
        .buttonStyle(.plain)
        .disabled(destination == self.destination)
    }
}
