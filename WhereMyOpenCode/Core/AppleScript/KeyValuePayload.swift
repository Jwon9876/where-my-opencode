import Foundation

enum KeyValuePayload {
    static func parse(_ payload: String) -> [String: String] {
        payload
            .components(separatedBy: .newlines)
            .reduce(into: [String: String]()) { partialResult, line in
                guard let separatorIndex = line.firstIndex(of: "=") else {
                    return
                }

                let key = String(line[..<separatorIndex])
                let valueStartIndex = line.index(after: separatorIndex)
                partialResult[key] = String(line[valueStartIndex...])
            }
    }

    static func parseRecords(_ payload: String) -> [[String: String]] {
        var records: [[String]] = []
        var currentRecord: [String] = []

        for line in payload.components(separatedBy: .newlines) {
            if line.trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                records.append(currentRecord)
                currentRecord = []
            } else {
                currentRecord.append(line)
            }
        }

        records.append(currentRecord)

        return records.map { parse($0.joined(separator: "\n")) }
    }

    static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }

        return value
    }
}
