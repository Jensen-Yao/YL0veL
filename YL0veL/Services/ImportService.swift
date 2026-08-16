import Foundation

/// 数据导入服务（借鉴 Mooneva 的 drip/Flo/Clue 导入思路）
/// 支持：
/// 1. YL0veL 自身 JSON 备份（ExportData）
/// 2. drip CSV（列：date, bleeding.value, pain.cramps, ... 见 references/drip/lib/import-export）
/// 3. Flo / Clue CSV（启发式：识别日期列与周期/经期相关列）
enum ImportService {

    struct ImportedDay {
        var date: Date
        var flow: Int
        var symptoms: [String]
        var note: String?
    }

    enum ImportError: Error, LocalizedError {
        case unrecognizedFormat
        case noRecords

        var errorDescription: String? {
            switch self {
            case .unrecognizedFormat: return "无法识别的文件格式（支持 YL0veL JSON、drip/Flo/Clue CSV）"
            case .noRecords: return "文件中没有找到经期记录"
            }
        }
    }

    @MainActor
    static func importFile(at url: URL, cycleStore: CycleStore) async throws -> Int {
        let data = try Data(contentsOf: url)
        let imported: [ImportedDay]

        if let text = String(data: data, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
                // JSON（YL0veL 备份）
                imported = try parseYL0veLJSON(data)
            } else {
                // CSV（drip / Flo / Clue）
                imported = try parseCSV(trimmed)
            }
        } else {
            throw ImportError.unrecognizedFormat
        }

        guard !imported.isEmpty else { throw ImportError.noRecords }

        var count = 0
        for item in imported {
            let day = cycleStore.day(for: item.date) ?? CycleDay(date: item.date)
            if item.flow > 0 {
                day.flow = item.flow
            }
            for code in item.symptoms where !day.symptoms.contains(code) {
                day.symptoms.append(code)
            }
            if let note = item.note, !note.isEmpty, day.note == nil {
                day.note = note
            }
            try await cycleStore.upsert(day)
            count += 1
        }
        return count
    }

    // MARK: - YL0veL JSON

    private static func parseYL0veLJSON(_ data: Data) throws -> [ImportedDay] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(ExportData.self, from: data)
        return export.cycleDays.map { day in
            ImportedDay(date: day.date, flow: day.flow, symptoms: day.symptoms, note: day.note)
        }
    }

    // MARK: - CSV 解析

    private static func parseCSV(_ text: String) throws -> [ImportedDay] {
        let table = CSVParser.parse(text)
        guard table.count >= 2 else { throw ImportError.noRecords }

        let header = table[0].map { normalizeHeader($0) }
        let rows = Array(table.dropFirst())

        // 识别关键列
        let dateColumn = header.firstIndex { $0.contains("date") && ($0.contains("start") || $0 == "date") }
            ?? header.firstIndex { $0.contains("日期") }
        let flowColumn = header.firstIndex { $0.contains("bleeding") || $0.contains("flow") || $0.contains("经血") || $0.contains("流量") }
        let periodLengthColumn = header.firstIndex { $0.contains("period") && $0.contains("length") }
        let crampsColumn = header.firstIndex { $0.contains("cramps") || $0.contains("痛经") }
        let headacheColumn = header.firstIndex { $0.contains("headache") || $0.contains("头痛") }

        // drip 风格：date 列 + bleeding.value 列，逐日导入
        if let dateColumn {
            return parseDailyRows(rows: rows, dateColumn: dateColumn, flowColumn: flowColumn,
                                  crampsColumn: crampsColumn, headacheColumn: headacheColumn)
        }

        // Flo/Clue 风格：周期起始行
        if let periodLengthColumn {
            return parseCycleRows(rows: rows, periodLengthColumn: periodLengthColumn, header: header)
        }

        throw ImportError.unrecognizedFormat
    }

    /// drip：一行一天；flow 由 bleeding 列判断
    private static func parseDailyRows(
        rows: [[String]],
        dateColumn: Int,
        flowColumn: Int?,
        crampsColumn: Int?,
        headacheColumn: Int?
    ) -> [ImportedDay] {
        var result: [ImportedDay] = []
        for row in rows {
            guard row.count > dateColumn, let date = parseDate(row[dateColumn]) else { continue }
            var flow = 0
            if let flowColumn, row.count > flowColumn {
                flow = importedFlowValue(row[flowColumn])
            }
            var symptoms: [String] = []
            if let crampsColumn, row.count > crampsColumn, parseBool(row[crampsColumn]) { symptoms.append("cramps") }
            if let headacheColumn, row.count > headacheColumn, parseBool(row[headacheColumn]) { symptoms.append("headache") }
            if flow > 0 || !symptoms.isEmpty {
                result.append(ImportedDay(date: date, flow: flow, symptoms: symptoms, note: nil))
            }
        }
        return result
    }

    /// Flo/Clue：一行一个周期开始日（无逐日流量 → 默认中等流量；经期长度列可展开）
    private static func parseCycleRows(rows: [[String]], periodLengthColumn: Int, header: [String]) -> [ImportedDay] {
        let dateColumn = header.firstIndex { $0.contains("start") } ?? 0
        var result: [ImportedDay] = []
        for row in rows {
            guard row.count > dateColumn, let date = parseDate(row[dateColumn]) else { continue }
            let periodLength = row.count > periodLengthColumn ? Int(row[periodLengthColumn].filter(\.isNumber)) ?? 4 : 4
            // 展开为逐日记录（默认中等流量）
            let calendar = Calendar.current
            for offset in 0..<min(periodLength, 14) {
                if let dayDate = calendar.date(byAdding: .day, value: offset, to: date) {
                    result.append(ImportedDay(date: dayDate, flow: FlowLevel.medium.rawValue, symptoms: [], note: nil))
                }
            }
        }
        return result
    }

    // MARK: - Helpers

    private static func normalizeHeader(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
            .lowercased()
    }

    private static func parseDate(_ raw: String) -> Date? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
        let formatters: [DateFormatter] = {
            let candidates = ["yyyy-MM-dd", "yyyy/MM/dd", "MM/dd/yyyy", "dd.MM.yyyy", "yyyy-MM-dd HH:mm:ss"]
            return candidates.map { format in
                let f = DateFormatter()
                f.dateFormat = format
                f.locale = Locale(identifier: "en_US_POSIX")
                f.timeZone = TimeZone.current
                return f
            }
        }()
        for formatter in formatters {
            if let date = formatter.date(from: cleaned) {
                return Calendar.current.startOfDay(for: date)
            }
        }
        return nil
    }

    static func importedFlowValue(_ raw: String) -> Int {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let number = Int(cleaned) {
            return min(3, max(0, number))
        }
        switch cleaned {
        case "heavy", "large", "strong": return FlowLevel.heavy.rawValue
        case "medium", "normal", "middle": return FlowLevel.medium.rawValue
        case "light", "weak", "little": return FlowLevel.light.rawValue
        case "none", "no", "0", "false", "": return 0
        default: return FlowLevel.medium.rawValue
        }
    }

    private static func parseBool(_ raw: String) -> Bool {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return ["1", "true", "yes", "y", "x", "heavy", "light", "medium"].contains(cleaned)
    }
}

/// 简单 CSV 解析器（支持引号转义、引号内换行、CRLF/LF）
enum CSVParser {
    static func parse(_ text: String) -> [[String]] {
        // 归一化换行
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        // 按行分割，并合并「引号未闭合」的续行（引号字段内换行）
        let rawLines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var logicalLines: [String] = []
        var pending = ""
        for line in rawLines {
            if pending.isEmpty {
                if quoteCount(in: line) % 2 == 1 {
                    pending = line
                } else {
                    logicalLines.append(line)
                }
            } else {
                pending += "\n" + line
                if quoteCount(in: line) % 2 == 1 {
                    logicalLines.append(pending)
                    pending = ""
                }
            }
        }
        if !pending.isEmpty {
            logicalLines.append(pending)
        }

        // 逐行解析字段
        var rows: [[String]] = []
        for line in logicalLines {
            let fields = parseLine(line)
            if fields.contains(where: { !$0.isEmpty }) {
                rows.append(fields)
            }
        }
        return rows
    }

    /// 行内双引号数量（判断引号字段是否闭合）
    private static func quoteCount(in line: String) -> Int {
        line.reduce(0) { $0 + ($1 == "\"" ? 1 : 0) }
    }

    private static func parseLine(_ line: String) -> [String] {
        var fields: [String] = []
        var field = ""
        var inQuotes = false
        var index = line.startIndex

        while index < line.endIndex {
            let char = line[index]
            if inQuotes {
                if char == "\"" {
                    let next = line.index(after: index)
                    if next < line.endIndex, line[next] == "\"" {
                        field.append("\"")
                        index = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                } else if char == "," {
                    fields.append(field)
                    field = ""
                } else {
                    field.append(char)
                }
            }
            index = line.index(after: index)
        }
        fields.append(field)
        return fields
    }
}
