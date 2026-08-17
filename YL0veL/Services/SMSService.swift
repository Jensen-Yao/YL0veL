import SwiftUI
import MessageUI

/// 短信草稿（快捷短信 sheet 数据）
struct SMSDraft: Identifiable {
    let id = UUID()
    var recipients: [String]
    var body: String
}

/// 短信服务：封装系统短信发送（iOS 要求用户手动确认发送，隐私合规）
enum SMSService {

    static func canSendText() -> Bool {
        MFMessageComposeViewController.canSendText()
    }

    /// 校验并归一化号码（去掉空格/横线）
    static func normalizedPhone(_ raw: String) -> String {
        raw.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    static func draft(to phone: String, body: String) -> SMSDraft? {
        let cleaned = normalizedPhone(phone)
        guard !cleaned.isEmpty, canSendText() else { return nil }
        return SMSDraft(recipients: [cleaned], body: body)
    }
}

/// 短信发送界面（MFMessageComposeViewController 包装）
struct SMSComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    var onComplete: (MessageComposeResult) -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.recipients = recipients
        controller.body = body
        controller.messageComposeDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onComplete: (MessageComposeResult) -> Void

        init(onComplete: @escaping (MessageComposeResult) -> Void) {
            self.onComplete = onComplete
        }

        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true) {
                self.onComplete(result)
            }
        }
    }
}
