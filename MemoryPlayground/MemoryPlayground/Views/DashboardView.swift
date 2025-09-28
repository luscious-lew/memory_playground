import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var path: [RemixDestination] = []
    private var needsSetup: Bool {
        let state = viewModel.onboardingState
        return !state.contains(.apiKeysConfigured)
    }

    private var shouldWarnAboutFullDiskAccess: Bool {
        !viewModel.onboardingState.contains(.fullDiskAccess)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                background
                if needsSetup {
                    SetupChecklistView()
                        .environmentObject(viewModel)
                        .padding()
                } else {
                    VStack(alignment: .leading, spacing: 32) {
                        header
                        diagnosticsPanel
                        remixGrid
                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 36)
                    .overlay(alignment: .bottom) {
                        if shouldWarnAboutFullDiskAccess {
                            fullDiskAccessWarning
                                .padding(.bottom, 12)
                        }
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if !needsSetup {
                    refreshBadge
                        .padding(32)
                }
            }
            .navigationTitle("")
            .navigationDestination(for: RemixDestination.self) { destination in
                RemixDetailContainer(path: $path, destination: destination)
            }
        }
        .onAppear { viewModel.refreshOnboarding() }
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
            Text("Turn your conversations into playful remixes powered by GPT-5.")
                .font(.system(size: 20, weight: .medium, design: .default))
                .foregroundStyle(.white.opacity(0.85))
            // Hidden: Full Disk Access warning
            // if shouldWarnAboutFullDiskAccess {
            //     Label("Full Disk Access not confirmed — reading iMessages may fail.", systemImage: "exclamationmark.triangle.fill")
            //         .padding(.horizontal, 18)
            //         .padding(.vertical, 10)
            //         .background(.orange.opacity(0.25), in: Capsule())
            //         .foregroundStyle(.white)
            //         .transition(.opacity)
            // }
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

    private var fullDiskAccessWarning: some View {
        Button {
            openFullDiskAccessSettings()
        } label: {
            Label("Grant Full Disk Access via System Settings for richer data.", systemImage: "folder.badge.person.crop")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    private var diagnosticsPanel: some View {
        let diagnostics = viewModel.ingestionDiagnostics
        print("🖥️ Dashboard diagnostics update: \(diagnostics.status)")
        return VStack(alignment: .leading, spacing: 12) {
            // Hidden: diagnostic messages
            // switch diagnostics.status {
            // case .idle:
            //     EmptyView()
            // case .failed(let message):
            //     diagnosticsRow(icon: "xmark.circle.fill", color: .red, title: "Ingestion failed", subtitle: message)
            // case .success(let count):
            //     diagnosticsRow(icon: "checkmark.seal.fill", color: .green, title: "Loaded \(count) messages", subtitle: "Showing first \(diagnostics.sampleMessages.count) below")
            //     samplesList(diagnostics.sampleMessages)
            // }
            EmptyView()
        }
    }

    @ViewBuilder
    private func diagnosticsRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    @ViewBuilder
    private func samplesList(_ samples: [ConversationItem]) -> some View {
        Group {
            if samples.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(samples.enumerated()), id: \.offset) { pair in
                        SampleMessageRow(index: pair.offset, item: pair.element)
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private struct SampleMessageRow: View {
        let index: Int
        let item: ConversationItem

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(index + 1). \(item.speaker)")
                    .font(.subheadline.weight(.semibold))
                Text(item.text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
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
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { refreshCurrentView() }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.plain)
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

    private func refreshCurrentView() {
        switch destination {
        case .newspaper:
            viewModel.regenerateNewspaper()
        case .roast:
            viewModel.regenerateRoast()
        case .trivia:
            viewModel.regenerateTrivia()
        case .comic:
            viewModel.regenerateComic()
        case .future:
            viewModel.regenerateFutureYou()
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
