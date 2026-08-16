import SwiftUI
import UIKit

/// Y💗L 品牌主题（Apple HIG：颜色随深浅色模式自适应、系统字体、Dynamic Type）
enum YLTheme {

    /// 品牌主色（玫瑰粉）
    static let primary = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.55, blue: 0.78, alpha: 1)
            : UIColor(red: 0.95, green: 0.33, blue: 0.60, alpha: 1)
    })

    /// 深一档强调色（渐变终点）
    static let primaryDeep = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.85, green: 0.42, blue: 0.75, alpha: 1)
            : UIColor(red: 0.80, green: 0.22, blue: 0.52, alpha: 1)
    })

    /// 品牌渐变（粉 → 紫）
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [primary, primaryDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 柔和背景（浅粉底）
    static let softBackground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.13, green: 0.10, blue: 0.14, alpha: 1)
            : UIColor(red: 1.00, green: 0.96, blue: 0.98, alpha: 1)
    })

    /// 流量分级色
    static func flowColor(_ level: FlowLevel) -> Color {
        switch level {
        case .none: return .secondary.opacity(0.5)
        case .light: return Color(uiColor: UIColor(red: 1.0, green: 0.72, blue: 0.80, alpha: 1))
        case .medium: return primary
        case .heavy: return primaryDeep
        }
    }

    /// 触感反馈（关键动作：记录保存/开关/预测卡出现）
    static func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// 成功反馈
    static func hapticSuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - 通用卡片样式

struct YLCardStyle: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension View {
    func ylCard(padding: CGFloat = 16) -> some View {
        modifier(YLCardStyle(padding: padding))
    }
}
