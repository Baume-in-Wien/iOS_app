import SwiftUI
import CoreData

@main
struct baumkatasterApp: App {
    let persistenceController = PersistenceController.shared
    @State private var appState = AppState.shared
    @State private var selectedLoadingMode: LoadingMode?
    @State private var showModeSelection = false

    init() {

        registerHostGroteskAsDefault()

        LocationService.shared.requestAuthorization()

        configureLiquidGlassAppearance()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showModeSelection {
                    DataLoadingModeView(selectedMode: $selectedLoadingMode)
                        .onChange(of: selectedLoadingMode) { _, newMode in
                            if let mode = newMode {
                                handleModeSelection(mode)
                            }
                        }
                } else if appState.isInitialLoading {
                    InitialLoadingView()
                } else {
                    MainTabView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .preferredColorScheme(nil)
                }
            }
            .task {
                await checkAndLoadData()
            }
        }
    }

    private func handleModeSelection(_ mode: LoadingMode) {
        WFSService.shared.loadingMode = mode
        showModeSelection = false

        Task {
            switch mode {
            case .bulk:

                await MainActor.run {
                    appState.isInitialLoading = true
                    appState.loadingMessage = "Verbinde mit Server..."
                    appState.loadingProgress = 0.0
                }

                do {
                    try await WFSService.shared.loadDataWithProgress()
                    await MainActor.run {
                        appState.isInitialLoading = false
                        appState.isDataReady = true
                    }
                } catch {
                    print("Error loading data: \(error)")
                    await MainActor.run {
                        appState.loadingMessage = "Fehler: \(error.localizedDescription)"
                    }
                }

            case .onDemand:

                await MainActor.run {
                    appState.isInitialLoading = false
                    appState.isDataReady = true
                }
                WFSService.shared.startBackgroundLoading()
            }
        }
    }

    private func checkAndLoadData() async {

        if !WFSService.shared.hasChosenLoadingMode {
            await MainActor.run {
                showModeSelection = true
            }
            return
        }

        let context = TreeCachePersistence.shared.container.newBackgroundContext()
        var count = 0
        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "CachedTree")
            count = (try? context.count(for: request)) ?? 0
        }

        let mode = WFSService.shared.loadingMode ?? .bulk

        if mode == .onDemand || count >= 200000 {
            await MainActor.run {
                appState.isDataReady = true
            }

            if mode == .onDemand && count < 200000 {
                WFSService.shared.startBackgroundLoading()
            }
            return
        }

        await MainActor.run {
            appState.isInitialLoading = true
            appState.loadingMessage = "Verbinde mit Server..."
            appState.loadingProgress = 0.0
        }

        do {
            try await WFSService.shared.loadDataWithProgress()
            await MainActor.run {
                appState.isInitialLoading = false
                appState.isDataReady = true
            }
        } catch {
            print("Error loading data: \(error)")
            await MainActor.run {
                appState.loadingMessage = "Fehler: \(error.localizedDescription)"
            }
        }
    }

    private func configureLiquidGlassAppearance() {

        let accentColor = UIColor.systemGreen
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = accentColor

        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        navBarAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        navBarAppearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.1)
        navBarAppearance.shadowColor = .clear
        navBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.hostGrotesk(size: 17, weight: .semibold)
        ]
        navBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.hostGrotesk(size: 34, weight: .bold)
        ]

        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().tintColor = accentColor

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        tabBarAppearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.1)
        tabBarAppearance.shadowColor = .clear

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        UITabBar.appearance().tintColor = accentColor

        if #available(iOS 16.4, *) {

        }
    }
}
