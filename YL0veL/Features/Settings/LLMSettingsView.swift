import SwiftUI
import SwiftData

/// LLM 设置：DeepSeek/通义/自定义（OpenAI 兼容），key 存 Keychain，最小化传输选项
struct LLMSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var configs: [LLMConfig]

    @State private var provider: String
    @State private var baseURL: String
    @State private var model: String
    @State private var apiKey: String
    @State private var enabled: Bool
    @State private var includeCycleContext: Bool
    @State private var testing = false
    @State private var testResult: String?

    private let presets: [(name: String, baseURL: String, model: String)] = [
        ("DeepSeek", "https://api.deepseek.com/v1", "deepseek-chat"),
        ("通义千问", "https://dashscope.aliyuncs.com/compatible-mode/v1", "qwen-plus"),
        ("自定义", "", ""),
    ]

    init() {
        // 初始化占位，onAppear 时从数据库载入
        _provider = State(initialValue: "DeepSeek")
        _baseURL = State(initialValue: "https://api.deepseek.com/v1")
        _model = State(initialValue: "deepseek-chat")
        _apiKey = State(initialValue: "")
        _enabled = State(initialValue: false)
        _includeCycleContext = State(initialValue: false)
    }

    private var currentConfig: LLMConfig? {
        configs.first
    }

    var body: some View {
        Form {
            Section("服务商") {
                Picker("服务商", selection: $provider) {
                    ForEach(presets, id: \.name) { preset in
                        Text(preset.name).tag(preset.name)
                    }
                }
                .onChange(of: provider) { _, newValue in
                    if let preset = presets.first(where: { $0.name == newValue }) {
                        baseURL = preset.baseURL
                        model = preset.model
                    }
                }

                TextField("API 地址 (base URL)", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("模型名称", text: $model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("API Key") {
                SecureField("sk-...", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text("Key 仅保存在本机 Keychain 中，不会出现在任何日志或备份里。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("启用 AI 增强", isOn: $enabled)
                Toggle("允许附带周期上下文", isOn: $includeCycleContext)
            } header: {
                Text("使用")
            } footer: {
                Text("默认仅把你当前说的这句话发给 AI。开启「周期上下文」后，会额外附带周期天数等最小化信息，帮助 AI 更准确地理解（如「上周三」的换算）。健康数据默认不外传。")
            }

            Section {
                Button {
                    testConnection()
                } label: {
                    HStack {
                        Text("测试连接")
                        Spacer()
                        if testing {
                            ProgressView()
                        }
                    }
                }
                .disabled(testing || apiKey.isEmpty)

                if let testResult {
                    Text(testResult)
                        .font(.footnote)
                        .foregroundStyle(testResult == "连接成功 ✅" ? .green : .red)
                }
            }

            Section {
                Button("保存") {
                    save()
                }
                .frame(maxWidth: .infinity)
                .fontWeight(.semibold)
                .disabled(apiKey.isEmpty || baseURL.isEmpty || model.isEmpty)
            }
        }
        .navigationTitle("AI 服务")
        .onAppear(perform: load)
    }

    private func load() {
        guard let config = currentConfig else { return }
        provider = config.providerName
        baseURL = config.baseURL
        model = config.model
        enabled = config.enabled
        includeCycleContext = config.includeCycleContext
        if let key = KeychainService.read(key: config.apiKeyRef) {
            apiKey = key
        }
    }

    private func save() {
        let config = currentConfig ?? LLMConfig(providerName: provider, baseURL: baseURL, model: model)
        config.providerName = provider
        config.baseURL = baseURL
        config.model = model
        config.enabled = enabled
        config.includeCycleContext = includeCycleContext
        config.updatedAt = .now
        if config.apiKeyRef.isEmpty {
            config.apiKeyRef = "llm-\(UUID().uuidString)"
        }
        try? KeychainService.save(key: config.apiKeyRef, value: apiKey)
        if currentConfig == nil {
            modelContext.insert(config)
        }
        try? modelContext.save()
        YLTheme.hapticSuccess()
        testResult = "已保存 ✅"
    }

    private func testConnection() {
        testing = true
        testResult = nil
        let config = LLMConfig(providerName: provider, baseURL: baseURL, model: model)
        Task {
            do {
                _ = try await LLMService.testConnection(config: config, apiKey: apiKey)
                testResult = "连接成功 ✅"
                YLTheme.hapticSuccess()
            } catch {
                testResult = "连接失败：\(error.localizedDescription)"
            }
            testing = false
        }
    }
}
