import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 设置：提醒 / 排卵模式 / 准备清单 / AI 服务 / 隐私 / 数据 / 关于
@MainActor
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var cycleStore: CycleStore
    @EnvironmentObject private var reportService: ReportService

    @State private var showLLMSettings = false
    @State private var showImportSheet = false
    @State private var showExportShare = false
    @State private var exportFileURL: URL?
    @State private var statusMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if let settings = appState.settings {
                    remindersSection(settings)
                    modeSection(settings)
                    checklistSection(settings)
                }
                aiSection
                privacySection
                dataSection
                aboutSection
            }
            .navigationTitle("设置")
            .fileImporter(isPresented: $showImportSheet, allowedContentTypes: [.json, .commaSeparatedText, .plainText]) { result in
                handleImport(result)
            }
            .fileExporter(isPresented: $showExportShare, document: JSONFileDocument(url: exportFileURL), contentType: .json, defaultFilename: "ylovel-backup") { result in
                if case .success = result {
                    statusMessage = "导出成功"
                }
            }
            .alert(statusMessage ?? "", isPresented: Binding(get: { statusMessage != nil }, set: { if !$0 { statusMessage = nil } })) {
                Button("好", role: .cancel) {}
            }
        }
    }

    // MARK: - 提醒

    @ViewBuilder
    private func remindersSection(_ settings: AppSettings) -> some View {
        Section("提醒") {
            Toggle("经期提醒", isOn: Binding(
                get: { settings.periodReminderEnabled },
                set: { newValue in
                    settings.periodReminderEnabled = newValue
                    settings.updatedAt = .now
                    try? modelContext.save()
                    Task {
                        await NotificationService.shared.refreshPeriodReminderIfNeeded(cycleStore: cycleStore, settings: settings)
                    }
                }
            ))
            Stepper("提前 \(settings.advanceNoticeDays) 天", value: Binding(
                get: { settings.advanceNoticeDays },
                set: { settings.advanceNoticeDays = $0; try? modelContext.save() }
            ), in: 1...7)
            Picker("提醒时间", selection: Binding(
                get: { settings.reminderHour },
                set: { settings.reminderHour = $0; try? modelContext.save() }
            )) {
                ForEach(5...10, id: \.self) { hour in
                    Text(String(format: "%02d:00", hour)).tag(hour)
                }
            }
            Toggle("每日体温提醒", isOn: Binding(
                get: { settings.temperatureReminderEnabled },
                set: { newValue in
                    settings.temperatureReminderEnabled = newValue
                    try? modelContext.save()
                    Task {
                        await NotificationService.shared.scheduleDailyReminder(
                            enabled: newValue,
                            hour: settings.reminderHour,
                            title: "桃桃，晨间体温时间 🌡️",
                            body: "醒来记得量一下基础体温哦，管家 Y 帮你记着",
                            identifier: NotificationService.temperatureReminderID
                        )
                    }
                }
            ))
            Toggle("主人语音铃声", isOn: Binding(
                get: { settings.customSoundEnabled },
                set: { newValue in
                    settings.customSoundEnabled = newValue
                    try? modelContext.save()
                    Task {
                        await NotificationService.shared.refreshPeriodReminderIfNeeded(cycleStore: cycleStore, settings: settings)
                    }
                }
            ))
            Toggle("睡前关怀", isOn: Binding(
                get: { settings.nightCareEnabled },
                set: { newValue in
                    settings.nightCareEnabled = newValue
                    try? modelContext.save()
                    Task {
                        await NotificationService.shared.scheduleNightCare(enabled: newValue, hour: settings.nightCareHour)
                    }
                }
            ))
            Picker("睡前关怀时间", selection: Binding(
                get: { settings.nightCareHour },
                set: { settings.nightCareHour = $0; try? modelContext.save() }
            )) {
                ForEach(20...23, id: \.self) { hour in
                    Text(String(format: "%02d:30", hour)).tag(hour)
                }
            }
            Toggle("用药提醒", isOn: Binding(
                get: { settings.medicationReminderEnabled },
                set: { newValue in
                    settings.medicationReminderEnabled = newValue
                    try? modelContext.save()
                    Task {
                        await NotificationService.shared.scheduleMedicationReminder(enabled: newValue, hour: settings.reminderHour)
                    }
                }
            ))
        }
    }

    // MARK: - 排卵期模式

    @ViewBuilder
    private func modeSection(_ settings: AppSettings) -> some View {
        Section {
            Picker("模式", selection: Binding(
                get: { settings.cycleMode },
                set: { newValue in
                    settings.cycleMode = newValue
                    settings.updatedAt = .now
                    try? modelContext.save()
                    Task {
                        await NotificationService.shared.refreshPeriodReminderIfNeeded(cycleStore: cycleStore, settings: settings)
                    }
                }
            )) {
                ForEach(CycleMode.allCases, id: \.rawValue) { mode in
                    Text(mode.displayName).tag(mode.rawValue)
                }
            }
        } header: {
            Text("排卵期模式")
        } footer: {
            Text("备孕模式会温柔提醒好时机；避孕模式会提醒做好防护。")
        }
    }

    // MARK: - 经期准备清单

    @ViewBuilder
    private func checklistSection(_ settings: AppSettings) -> some View {
        Section {
            NavigationLink {
                ChecklistEditorView(checklist: settings.checklist) { updated in
                    settings.checklist = updated
                    settings.updatedAt = .now
                    try? modelContext.save()
                    Task {
                        await NotificationService.shared.refreshPeriodReminderIfNeeded(cycleStore: cycleStore, settings: settings)
                    }
                }
            } label: {
                Label("经期准备清单", systemImage: "checklist")
            }
        } footer: {
            Text("经期前 3 天，管家 Y 会每天提醒你确认一项。")
        }
    }

    // MARK: - AI 服务

    private var aiSection: some View {
        Section {
            NavigationLink {
                LLMSettingsView()
            } label: {
                Label("AI 服务（DeepSeek 等）", systemImage: "brain")
            }
        } footer: {
            Text("配置后，语音记录理解更智能、周期报告关怀文案更个性化。不配置也能正常使用（内置离线解析与文案）。")
        }
    }

    // MARK: - 隐私

    @ViewBuilder
    private var privacySection: some View {
        Section("隐私") {
            if let settings = appState.settings {
                Toggle("App 锁", isOn: Binding(
                    get: { settings.appLockEnabled },
                    set: { settings.appLockEnabled = $0; settings.updatedAt = .now; try? modelContext.save() }
                ))
                Toggle("假密码（防窥）", isOn: Binding(
                    get: { settings.fakePINEnabled },
                    set: { settings.fakePINEnabled = $0; try? modelContext.save() }
                ))
                if settings.fakePINEnabled {
                    TextField("设置解锁密码（4-8 位数字）", text: Binding(
                        get: { settings.fakePIN ?? "" },
                        set: { settings.fakePIN = $0.isEmpty ? nil : $0; try? modelContext.save() }
                    ))
                    .keyboardType(.numberPad)
                }
            }
            Text("所有经期与健康数据默认仅保存在本机")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 数据

    private var dataSection: some View {
        Section {
            Button {
                showImportSheet = true
            } label: {
                Label("导入历史数据（drip / Flo / Clue）", systemImage: "square.and.arrow.down")
            }
            Button {
                exportData()
            } label: {
                Label("导出全部数据（JSON）", systemImage: "square.and.arrow.up")
            }
        } header: {
            Text("数据")
        } footer: {
            Text("支持从 drip、Flo、Clue 的导出文件导入历史经期记录，换 App 零成本。")
        }
    }

    // MARK: - 关于

    private var aboutSection: some View {
        Section("关于") {
            LabeledContent("版本", value: "1.0.0")
            NavigationLink {
                DisclaimerView(onAccept: {})
            } label: {
                Text("免责声明与隐私说明")
            }
        }
    }

    // MARK: - 导入导出

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else {
            statusMessage = "导入失败：无法读取文件"
            return
        }
        Task {
            do {
                let count = try await ImportService.importFile(at: url, cycleStore: cycleStore)
                statusMessage = "成功导入 \(count) 条记录 💗"
                YLTheme.hapticSuccess()
                await NotificationService.shared.refreshPeriodReminderIfNeeded(cycleStore: cycleStore)
            } catch {
                statusMessage = "导入失败：\(error.localizedDescription)"
            }
        }
    }

    private func exportData() {
        let days = cycleStore.cycleDays
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        let export = ExportData(cycleDays: days.map { ExportDay(date: $0.date, flow: $0.flow, symptoms: $0.symptoms, mood: $0.mood, mucus: $0.mucus, temperature: $0.temperature, note: $0.note, hasIntercourse: $0.hasIntercourse, contraception: $0.contraception) })
        guard let data = try? encoder.encode(export) else {
            statusMessage = "导出失败"
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ylovel-backup.json")
        try? data.write(to: url)
        exportFileURL = url
        showExportShare = true
    }
}

/// 导出文件文档
struct JSONFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var url: URL?

    init(url: URL?) {
        self.url = url
    }

    init(configuration: ReadConfiguration) throws {
        url = nil
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url else { return FileWrapper() }
        let data = try Data(contentsOf: url)
        return FileWrapper(regularFileWithContents: data)
    }
}

/// 导出结构（对应导入格式）
struct ExportData: Codable {
    var cycleDays: [ExportDay]
}

struct ExportDay: Codable {
    var date: Date
    var flow: Int
    var symptoms: [String]
    var mood: String?
    var mucus: String?
    var temperature: Double?
    var note: String?
    var hasIntercourse: Bool
    var contraception: String?
}
