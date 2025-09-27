import SwiftUI

@main
struct MemoryPlaygroundApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(viewModel)
                .frame(minWidth: 1100, minHeight: 720)
                .onAppear {
                    if case .idle = viewModel.loadingState {
                        viewModel.load()
                    }
                }
        }
        .commands {
            CommandMenu("Memory Playground") {
                Button("Refresh Data", action: viewModel.refresh)
                    .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}
