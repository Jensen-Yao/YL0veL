import SwiftUI
import HealthKit

/// 健康数据授权引导（分步说明，讲清每项用途；授权后自动消失）
struct HealthAuthorizationPromptView: View {
    @EnvironmentObject private var healthKit: HealthKitService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(YLTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)

                Text("与「健康」连接")
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 14) {
                    permissionRow("🩸", "经期数据（读 + 写）", "你的记录会同步进 Apple 健康，也能读取历史经期记录")
                    permissionRow("🌡️", "手腕温度（只读）", "手表支持时，用夜间温度校准预测（无传感器设备自动跳过）")
                    permissionRow("❤️", "心率 / HRV / 睡眠（只读）", "用于健康趋势洞察与周期报告")
                }
                .ylCard()

                Text("所有数据仅保存在本机，YL0veL 不会上传任何健康数据。你随时可以在系统设置中撤销授权。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)

                Button {
                    Task {
                        try? await healthKit.requestAuthorization()
                        YLTheme.hapticSuccess()
                        dismiss()
                    }
                } label: {
                    Text("授权并继续")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(YLTheme.brandGradient, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Button("暂不授权（仅本地记录）") {
                    dismiss()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func permissionRow(_ emoji: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji).font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
