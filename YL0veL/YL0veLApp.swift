import SwiftUI
import SwiftData

@main
struct YL0veLApp: App {

    let container: ModelContainer
    @StateObject private var appState = AppState()

    init() {
        do {
            container = try ModelContainer(
                for: CycleDay.self, Cycle.self, CycleReport.self, LLMConfig.self, AppSettings.self
            )
        } catch {
            fatalError("无法初始化数据库: \(error)")
        }
        #if DEBUG
        if LaunchArguments.seedDemoData {
            DemoDataSeeder.seed(ModelContext(container))
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environmentObject(appState)
                .tint(YLTheme.primary)
        }
    }
}

/// 全局状态：设置单例、隐私锁、免责声明（仅限主线程使用）
final class AppState: ObservableObject {
    @Published var settings: AppSettings?
    @Published var isLocked = false
    @Published var showDisclaimer = true // 首次启动先展示免责声明

    @MainActor
    func ensureSettings(in context: ModelContext) {
        guard settings == nil else { return }
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor).first {
            settings = existing
        } else {
            let new = AppSettings()
            context.insert(new)
            try? context.save()
            settings = new
        }
        if let settings {
            isLocked = settings.appLockEnabled
            showDisclaimer = !settings.hasAcceptedDisclaimer
        }
    }
}

/// 根视图：免责声明 → App 锁 → 主界面
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if appState.showDisclaimer {
                DisclaimerView {
                    appState.settings?.hasAcceptedDisclaimer = true
                    try? modelContext.save()
                    withAnimation(.spring(duration: 0.4, bounce: 0)) {
                        appState.showDisclaimer = false
                    }
                }
            } else if appState.isLocked {
                AppLockView { success in
                    if success {
                        withAnimation(.spring(duration: 0.4, bounce: 0)) {
                            appState.isLocked = false
                        }
                    }
                }
            } else {
                ContentView()
            }
        }
        .onAppear {
            appState.ensureSettings(in: modelContext)
            #if DEBUG
            // CI 截图：跳过免责声明
            if LaunchArguments.skipDisclaimer {
                appState.settings?.hasAcceptedDisclaimer = true
                try? modelContext.save()
                appState.showDisclaimer = false
            }
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            // 切后台：若开启 App 锁则重新锁定（隐私）
            if phase == .background, appState.settings?.appLockEnabled == true {
                appState.isLocked = true
            }
        }
    }
}
