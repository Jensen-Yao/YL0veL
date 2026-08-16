import SwiftUI

/// 每日记录编辑：流量/症状/情绪/黏液/体温/性行为/备注（词表来自 drip 借鉴 + 中文本地化）
struct DayEditView: View {
    let day: CycleDay
    var onSave: (CycleDay) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var flow: Int
    @State private var symptoms: Set<String>
    @State private var mood: String?
    @State private var mucus: String?
    @State private var temperatureText: String
    @State private var note: String
    @State private var hasIntercourse: Bool
    @State private var contraception: String?

    init(day: CycleDay, onSave: @escaping (CycleDay) -> Void) {
        self.day = day
        self.onSave = onSave
        _flow = State(initialValue: day.flow)
        _symptoms = State(initialValue: Set(day.symptoms))
        _mood = State(initialValue: day.mood)
        _mucus = State(initialValue: day.mucus)
        _temperatureText = State(initialValue: day.temperature.map { String(format: "%.2f", $0) } ?? "")
        _note = State(initialValue: day.note ?? "")
        _hasIntercourse = State(initialValue: day.hasIntercourse)
        _contraception = State(initialValue: day.contraception)
    }

    private var dateTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 EEEE"
        formatter.locale = Locale(identifier: "zh-CN")
        return formatter.string(from: day.date)
    }

    var body: some View {
        NavigationStack {
            Form {
                // 流量
                Section("经血量 · \(dateTitle)") {
                    Picker("经血量", selection: $flow) {
                        ForEach(FlowLevel.allCases, id: \.rawValue) { level in
                            Text("\(level.emoji) \(level.displayName)").tag(level.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 症状（多选）
                Section("症状（可多选）") {
                    FlowLayout(spacing: 8) {
                        ForEach(SymptomCatalog.painSymptoms, id: \.code) { item in
                            chip(item.emoji + " " + item.name, code: item.code, isOn: symptoms.contains(item.code)) {
                                toggle(code: item.code, in: &symptoms)
                            }
                        }
                    }
                }

                // 情绪
                Section("情绪") {
                    FlowLayout(spacing: 8) {
                        ForEach(SymptomCatalog.moods, id: \.code) { item in
                            chip(item.emoji + " " + item.name, code: item.code, isOn: mood == item.code) {
                                mood = mood == item.code ? nil : item.code
                            }
                        }
                    }
                }

                // 黏液
                Section("宫颈黏液") {
                    Picker("宫颈黏液", selection: Binding(
                        get: { mucus ?? "" },
                        set: { mucus = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("未记录").tag("")
                        ForEach(SymptomCatalog.mucusTypes, id: \.code) { item in
                            Text(item.name).tag(item.code)
                        }
                    }
                }

                // 基础体温
                Section("基础体温") {
                    HStack {
                        TextField("36.50", text: $temperatureText)
                            .keyboardType(.decimalPad)
                        Text("℃")
                            .foregroundStyle(.secondary)
                    }
                }

                // 性行为
                Section("性行为") {
                    Toggle("有性生活", isOn: $hasIntercourse)
                    if hasIntercourse {
                        Picker("避孕方式", selection: Binding(
                            get: { contraception ?? "none" },
                            set: { contraception = $0 }
                        )) {
                            ForEach(SymptomCatalog.contraceptionMethods, id: \.code) { item in
                                Text(item.name).tag(item.code)
                            }
                        }
                    }
                }

                // 备注
                Section("备注") {
                    TextField("今天想说的话…", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func toggle(code: String, in set: inout Set<String>) {
        if set.contains(code) {
            set.remove(code)
        } else {
            set.insert(code)
        }
    }

    private func save() {
        day.flow = flow
        day.symptoms = symptoms.sorted()
        day.mood = mood
        day.mucus = mucus
        day.temperature = Double(temperatureText.replacingOccurrences(of: ",", with: "."))
        day.note = note.isEmpty ? nil : note
        day.hasIntercourse = hasIntercourse
        day.contraception = contraception
        YLTheme.hapticSuccess()
        onSave(day)
        dismiss()
    }

    private func chip(_ label: String, code: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            YLTheme.haptic(.light)
            withAnimation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0)) {
                action()
            }
        }) {
            Text(label)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isOn ? YLTheme.primary.opacity(0.18) : Color(.secondarySystemGroupedBackground), in: Capsule())
                .overlay(Capsule().stroke(isOn ? YLTheme.primary : .clear, lineWidth: 1))
                .foregroundStyle(isOn ? YLTheme.primary : .primary)
        }
        .buttonStyle(.plain)
    }
}

/// 简单流式布局（chip 排列）
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.maxY } + CGFloat(max(0, rows.count - 1)) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += row.maxY + spacing
        }
    }

    private struct RowItem {
        let index: Int
        let size: CGSize
    }

    private struct Row {
        var items: [RowItem] = []
        var width: CGFloat = 0
        var maxY: CGFloat = 0
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = []
        var current = Row()
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            let projected = current.width + size.width + (current.items.isEmpty ? 0 : spacing)
            if projected > maxWidth && !current.items.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.items.append(RowItem(index: index, size: size))
            current.width += size.width + (current.items.count > 1 ? spacing : 0)
            current.maxY = max(current.maxY, size.height)
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}
