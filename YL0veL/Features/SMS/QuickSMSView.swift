import SwiftUI
import SwiftData

/// 快捷短信：选择模板 → 系统短信界面发送给主人（iOS 需用户手动确认发送）
struct QuickSMSView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var smsDraft: SMSDraft?
    @State private var showSetupHint = false

    private var phone: String { appState.settings?.partnerPhone ?? "" }
    private var templates: [String] { appState.settings?.smsTemplates ?? [] }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(templates, id: \.self) { template in
                        Button {
                            send(template)
                        } label: {
                            HStack {
                                Image(systemName: "bubble.left.fill")
                                    .foregroundStyle(YLTheme.primary)
                                Text(template)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "paperplane")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("发给主人（\(phone.isEmpty ? "未设置号码" : phone)）")
                } footer: {
                    Text("点一下选择要说的话，确认后就会发给主人。号码可在「设置 → 短信」里修改。")
                }

                if phone.isEmpty {
                    Section {
                        Button {
                            showSetupHint = true
                            dismiss()
                        } label: {
                            Label("去设置主人号码", systemImage: "person.crop.circle.badge.plus")
                        }
                    }
                }
            }
            .navigationTitle("告诉主人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(item: $smsDraft) { draft in
                SMSComposeView(recipients: draft.recipients, body: draft.body) { result in
                    smsDraft = nil
                    if result == .sent {
                        YLTheme.hapticSuccess()
                    }
                }
                .ignoresSafeArea()
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func send(_ template: String) {
        guard let draft = SMSService.draft(to: phone, body: template) else {
            showSetupHint = true
            return
        }
        smsDraft = draft
    }
}

/// 短信模板编辑器
struct SMSTemplatesEditorView: View {
    let templates: [String]
    var onSave: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var items: [String]
    @State private var newItem = ""

    init(templates: [String], onSave: @escaping ([String]) -> Void) {
        self.templates = templates
        self.onSave = onSave
        _items = State(initialValue: templates)
    }

    var body: some View {
        List {
            Section {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text(item)
                        Spacer()
                        Button {
                            items.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack {
                    TextField("添加话术（如：我要一杯红糖水）", text: $newItem)
                        .submitLabel(.done)
                        .onSubmit {
                            addItem()
                        }
                    Button {
                        addItem()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(YLTheme.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("快捷话术")
            } footer: {
                Text("经期不舒服的时候，点一下就能告诉主人。")
            }
        }
        .navigationTitle("短信话术")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    onSave(items)
                    dismiss()
                }
            }
        }
        .onDisappear {
            onSave(items)
        }
    }

    private func addItem() {
        let text = newItem.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        items.append(text)
        newItem = ""
    }
}
