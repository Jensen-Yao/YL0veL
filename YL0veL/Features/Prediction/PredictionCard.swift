import SwiftUI
import YL0veLPredictionKit

/// 预测卡：下次经期预测窗口 + 排卵窗口 + 依据说明（诚实区间，不制造焦虑）
struct PredictionCard: View {
    let prediction: CyclePrediction?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(YLTheme.primary)
                Text("预测")
                    .font(.headline)
                Spacer()
                if let prediction {
                    confidenceBadge(prediction.confidence)
                }
            }

            if let prediction {
                // 下次经期
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("下次经期")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(windowText(prediction.nextMensesWindow))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(YLTheme.primary)
                }

                // 排卵窗口
                if let ovulation = prediction.estimatedOvulationWindow {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("排卵窗口")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(windowText(ovulation))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.cyan)
                    }
                }

                // 依据说明
                Text(prediction.basis)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // 未来预测
                if !prediction.futureWindows.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("之后两次")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(Array(prediction.futureWindows.enumerated()), id: \.offset) { _, window in
                            Text(windowText(window))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                // 数据积累中
                HStack(spacing: 10) {
                    Image(systemName: "hourglass")
                        .foregroundStyle(.secondary)
                    Text("再记录 2~3 个周期，我就能开始预测啦 🌱")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            }
        }
        .ylCard()
    }

    private func windowText(_ window: [Date]) -> String {
        guard let first = window.first, let last = window.last else { return "—" }
        return "\(dateFormatter.string(from: first)) ~ \(dateFormatter.string(from: last))"
    }

    @ViewBuilder
    private func confidenceBadge(_ confidence: CyclePrediction.Confidence) -> some View {
        let (text, color): (String, Color) = switch confidence {
        case .high: ("规律", .green)
        case .medium: ("参考", .orange)
        case .low: ("波动", .gray)
        }
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}
