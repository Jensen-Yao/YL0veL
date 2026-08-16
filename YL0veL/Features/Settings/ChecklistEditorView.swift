import SwiftUI

/// 经期准备清单编辑器：桃桃自定义清单项
struct ChecklistEditorView: View {
    let checklist: [String]
    var onSave: ([String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var items: [String]
    @State private var newItem = ""

    init(checklist: [String], onSave: @escaping ([String]) -> Void) {
        self.checklist = checklist
        self.onSave = onSave
        _items = State(initialValue: checklist)
    }

    var body: some View {
        List {
            Section {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text("\(index + 1). \(item)")
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
                .onMove { from, to in
                    items.move(fromOffsets: from, toOffset: to)
                }

                HStack {
                    TextField("添加物品（如：暖宝宝）", text: $newItem)
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
                Text("清单（经期前 3 天逐项提醒前三项）")
            } footer: {
                Text("管家 Y 会在经期前 3 天，每天温柔提醒你准备一项 💗")
            }
        }
        .navigationTitle("经期准备清单")
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
