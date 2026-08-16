# YL0veL（Y💗L）

经期预测与健康守护 iOS App（SwiftUI 原生，iPhone + Apple Watch + 小组件）。

为女朋友打造的温柔记录工具：及时采集经期与健康状况、语音对话记录、周期预测（预测区间而非单日）、每次经期后自动生成周期报告（App 内阅读）、支持自配 DeepSeek 等主流 LLM API key、Apple Watch 快捷记录 + 表盘复杂功能、手腕温度自适应（SE 3 / S8+ 有传感器时自动启用，旧款自动降级）。

## 技术栈

| 层 | 选型 |
|---|---|
| UI | SwiftUI + Swift Charts（apple-design 规范：动态字体、深色模式、触感反馈、降级动效） |
| 本地存储 | SwiftData（HealthKit 为经期数据真源，双向同步） |
| 预测引擎 | 自研 `YL0veLPredictionKit` 纯函数包：drip 式 mean±σ 预测窗口 + 黄体期规则 + Soumpasis 人群先验贝叶斯更新 + WMA + 手腕温度相位校准（自适应） |
| 语音 | SFSpeechRecognizer 中文（规则解析器离线兜底 → LLM JSON Schema 增强） |
| LLM | OpenAI 兼容协议（DeepSeek/通义/自定义 baseURL），Key 存 Keychain |
| Watch | watchOS 独立 App + WidgetKit complication + WCSession（App Group 共享） |
| 构建 | XcodeGen 生成工程 + GitHub Actions macOS CI |

## 目录结构

```
YL0veL/                 iOS App（SwiftUI）
YL0veLPredictionKit/    预测引擎（纯 Swift，可单测）
YL0veLWatch/            watchOS 独立 App
YL0veLWatchWidget/      watchOS 表盘复杂功能 extension
YL0veLWidget/           iPhone 小组件 extension
YL0veLShared/           iPhone/Watch 共享代码（消息、App Group）
Tests/                  XCTest（引擎/解析器/报告/CSV）
docs/                   调研报告与开发路线图
references/             drip / log28 参考源码（调研用，不参与构建）
project.yml             XcodeGen 工程定义
.github/workflows/ios.yml  CI（macOS 构建 + 测试）
```

## 构建与运行

### 前置条件
- macOS + Xcode 15+（本机 Windows 无法编译 iOS 代码，构建走 CI 或 Mac）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）

### 本地（Mac）
```bash
xcodegen generate
open YL0veL.xcodeproj
# 选择 YL0veL scheme，真机运行（需在 Signing 里选择你的开发者账号）
```

### CI（推荐，Windows 开发工作流）
1. 把本仓库推送到 GitHub：
```bash
git remote add origin https://github.com/<你的用户名>/YL0veL.git
git push -u origin main
```
2. GitHub Actions 自动在 macOS runner 上：安装 XcodeGen → 生成工程 → 构建（模拟器）→ 跑全部测试。
3. `.xcodeproj` 不入库（`xcodegen generate` 生成），改文件后直接提交，CI 重新生成。

## 安装到女友手机（免费开发者账号）

免费账号无 TestFlight，三条路：

| 方案 | 说明 | 重签 |
|---|---|---|
| Mac + Xcode 直连 | 用你的 Apple ID（免费账号）在 Signing 中选 Personal Team，真机运行安装 | 每 7 天重新插线装一次 |
| AltStore 侧载（Windows 可用） | 电脑装 [AltServer](https://altstore.io)，手机装 AltStore，导入 ipa 自动刷新签名（同一 Wi-Fi） | 自动续签（需同 Wi-Fi 每 7 天一次） |
| 升级付费账号（$99/年）★推荐 | 解锁 TestFlight：CI 签名后女友随时在线安装，90 天自动续期，代码零改动 | 无需 |

> 建议：先免费账号验证功能，体验 OK 后升级付费账号走 TestFlight，体验最好。

## 功能清单

- 📅 月历记录：经血流量分级、症状词表（痛经/头痛/腰酸…15 种）、情绪、宫颈黏液、基础体温、性行为与避孕、备注
- 🔮 周期预测：下次经期预测窗口（±1~2 天，带置信度与依据说明）、未来 3 周期、排卵窗口估计；周期不足时诚实降级
- 📋 周期报告：经期结束自动生成（手动/5 天无流量自动判定），周期概况、流量分布、症状情绪统计、心率/HRV/睡眠/温度趋势、上周期对比、规律性评分、关怀文案；可分享图片
- 🎙️ 语音记录：「今天来了，量少肚子疼」→ 离线规则解析 → 预览确认卡 → 写入；配 AI key 后复杂句走 LLM
- ⌚ Apple Watch：complication 一键记经期、表盘周期天数+预测倒计时、健康摘要卡；Siri 指令「记录经期」
- 🌡️ 手腕温度（自适应）：SE 3/S8+ 5 晚基线 + 黄体期升温检测校准预测；旧款自动跳过
- 🤖 AI 服务：DeepSeek/通义/自定义（OpenAI 兼容），Key 存 Keychain，最小化传输
- 🔒 隐私：App 锁（FaceID + 假 PIN 防窥）、后台模糊、数据默认本地
- 📥 导入：drip/Flo/Clue 导出文件（CSV/JSON）一键回填历史
- ♿ 无障碍：VoiceOver、动态字体、Reduce Motion 降级动效

## 医疗免责

本 App 的预测与报告基于统计模型与个人记录，仅供参考，不构成医疗建议。如有不适请咨询专业医生。

## 参考

算法与交互设计参考了开源经期追踪社区（drip、Mensinator、peri 等）与相关研究（Curry 2025《Human Reproduction》、Soumpasis 2020）。调研详情见 `docs/调研报告.md`。
