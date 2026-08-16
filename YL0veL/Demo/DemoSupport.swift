import Foundation
import SwiftData

/// 模拟器演示数据（仅通过启动参数 -seedDemoData 触发，用于 CI 截图与开发调试）
enum DemoDataSeeder {

    /// 填充约 5 个完整周期 + 1 个进行中周期（28 天规律周期，含症状/情绪）
    @MainActor
    static func seed(_ context: ModelContext) {
        // 幂等：已有数据则跳过
        let existing = try? context.fetch(FetchDescriptor<CycleDay>(fetchLimit: 1))
        if let existing, !existing.isEmpty { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let cycleStarts: [Int] = [-144, -116, -88, -60, -32, -4]

        for startOffset in cycleStarts {
            guard let start = calendar.date(byAdding: .day, value: startOffset, to: today) else { continue }
            for dayIndex in 0..<6 {
                guard let date = calendar.date(byAdding: .day, value: dayIndex, to: start) else { continue }
                if date > today { continue }

                var flow = 0
                var symptoms: [String] = []
                switch dayIndex {
                case 0, 1:
                    flow = FlowLevel.medium.rawValue
                    symptoms = ["cramps", "fatigue"]
                case 2, 3:
                    flow = FlowLevel.light.rawValue
                    symptoms = ["cramps"]
                case 4:
                    flow = FlowLevel.light.rawValue
                default:
                    flow = 0
                }

                var mood: String?
                if dayIndex == 0 { mood = "tired" }
                if dayIndex == 3 { mood = "calm" }

                let day = CycleDay(
                    date: date,
                    flow: flow,
                    symptoms: symptoms,
                    mood: mood,
                    temperature: dayIndex == 3 ? 36.5 : nil,
                    note: dayIndex == 0 ? "第一天，多喝热水" : nil
                )
                context.insert(day)
            }
        }
        try? context.save()
    }
}

/// 启动参数（CI 截图用；DEBUG 构建才生效）
enum LaunchArguments {

    static func contains(_ flag: String) -> Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains(flag)
        #else
        return false
        #endif
    }

    static func value(forPrefix prefix: String) -> String? {
        #if DEBUG
        return ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix(prefix) })?
            .replacingOccurrences(of: prefix, with: "")
        #else
        return nil
        #endif
    }
}
