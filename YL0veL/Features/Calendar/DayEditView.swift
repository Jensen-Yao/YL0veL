import SwiftUI

/// 每日记录编辑：流量/症状/情绪/黏液/宫颈/欲望/体温/性行为/每日健康/心情日记
/// （词表参考 drip 全集 + 中文本地化）
struct DayEditView: View {
    let day: CycleDay
    var onSave: (CycleDay) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var flow: Int
    @State private var symptoms: Set<String>
    @State private var mood: String?
    @State private var mucus: String?
    @State private var mucusTexture: String?
    @State private var cervixOpening: String?
    @State private var cervixFirmness: String?
    @State private var cervixPosition: String?
    @State private var desire: String?
    @State private var temperatureText: String
    @State private var note: String
    @State private var hasIntercourse: Bool
    @State private var contraception: String?
    @State private var weightText: String
    @State private var exerciseMinutes: Int
    @State private var waterCups: Int
    @State private var sleepQuality: String?
    @State private var diary: String

    init(day: CycleDay, onSave: @escaping (CycleDay) -> Void) {
        self.day = day
        self.onSave = onSave
        _flow = State(initialValue: day.flow)
        _symptoms = State(initialValue: Set(day.symptoms))
        _mood = State(initialValue: day.mood)
        _mucus = State(initialValue: day.mucus)
        _mucusTexture = State(initialValue: day.mucusTexture)
        _cervixOpening = State(initialValue: day.cervixOpening)
        _cervixFirmness = State(initialValue: day.cervixFirmness)
        _cervixPosition = State(initialValue: day.cervixPosition)
        _desire = State(initialValue: day.desire)
        _temperatureText = State(initialValue: day.temperature.map { String(format: "%.2f", $0) } ?? "")
        _note = State(initialValue: day.note ?? "")
        _hasIntercourse = State(initialValue: day.hasIntercourse)
        _contraception = State(initialValue: day.contraception)
        _weightText = State(initialValue: day.weight.map { String(format: "%.1f", $0) } ?? "")
        _exerciseMinutes = State(initialValue: day.exerciseMinutes)
        _waterCups = State(initialValue: day.waterCups)
        _sleepQuality = State(initialValue: day.sleepQuality)
        _diary = State(initialValue: day.diary ?? "")
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
                    Picker("黏液感觉", selection: Binding(
                        get: { mucus ?? "" },
                        set: { mucus = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("未记录").tag("")
                        ForEach(SymptomCatalog.mucusTypes, id: \.code) { item in
                            Text(item.name).tag(item.code)
                        }
                    }
                    Picker("黏液质地", selection: Binding(
                        get: { mucusTexture ?? "" },
                        set: { mucusTexture = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("未记录").tag("")
                        ForEach(SymptomCatalog.mucusTextures, id: \.code) { item in
                            Text(item.name).tag(item.code)
                        }
                    }
                }

                // 宫颈
                Section("宫颈状态") {
                    Picker("开口", selection: Binding(
                        get: { cervixOpening ?? "" },
                        set: { cervixOpening = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("未记录").tag("")
                        ForEach(SymptomCatalog.cervixOpenings, id: \.code) { item in
                            Text(item.name).tag(item.code)
                        }
                    }
                    Picker("硬度", selection: Binding(
                        get: { cervixFirmness ?? "" },
                        set: { cervixFirmness = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("未记录").tag("")
                        ForEach(SymptomCatalog.cervixFirmnesses, id: \.code) { item in
                            Text(item.name).tag(item.code)
                        }
                    }
                    Picker("位置", selection: Binding(
                        get: { cervixPosition ?? "" },
                        set: { cervixPosition = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("未记录").tag("")
                        ForEach(SymptomCatalog.cervixPositions, id: \.code) { item in
                            Text(item.name).tag(item.code)
                        }
                    }
                }

                // 欲望
                Section("欲望") {
                    Picker("欲望", selection: Binding(
                        get: { desire ?? "" },
                        set: { desire = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("未记录").tag("")
                        ForEach(SymptomCatalog.desires, id: \.code) { item in
                            Text("\(item.emoji) \(item.name)").tag(item.code)
                        }
                    }
                    .pickerStyle(.segmented)
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

                // 每日健康
                Section("每日健康") {
                    HStack {
                        Text("体重")
                        Spacer()
                        TextField("50.0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                    Stepper("运动 \(exerciseMinutes) 分钟", value: $exerciseMinutes, in: 0...600, step: 10)
                    Stepper("饮水 \(waterCups) 杯", value: $waterCups, in: 0...20)
                    Picker("睡眠自评", selection: Binding(
                        get: { sleepQuality ?? "" },
                        set: { sleepQuality = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("未记录").tag("")
                        ForEach(SymptomCatalog.sleepQualities, id: \.code) { item in
                            Text("\(item.emoji) \(item.name)").tag(item.code)
                        }
                    }
                }

                // 心情日记
                Section("心情日记") {
                    TextField("今天的心情，说给管家 Y 听…", text: $diary, axis: .vertical)
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
        day.mucusTexture = mucusTexture
        day.cervixOpening = cervixOpening
        day.cervixFirmness = cervixFirmness
        day.cervixPosition = cervixPosition
        day.desire = desire
        day.temperature = Double(temperatureText.replacingOccurrences(of: ",", with: "."))
        day.note = note.isEmpty ? nil : note
        day.hasIntercourse = hasIntercourse
        day.contraception = contraception
        day.weight = Double(weightText.replacingOccurrences(of: ",", with: "."))
        day.exerciseMinutes = exerciseMinutes
        day.waterCups = waterCups
        day.sleepQuality = sleepQuality
        day.diary = diary.isEmpty ? nil : diary
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
