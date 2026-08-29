import Foundation

struct SkillScanResult: Sendable {
    var skills: [SkillItem]
    var filesFound: Int
    var duplicateCount: Int
    var unreadableCount: Int
}

enum SkillScanner {
    static func scan(directories: [String], existing: [SkillItem]) -> SkillScanResult {
        let previous = Dictionary(uniqueKeysWithValues: existing.map { ($0.normalizedName, $0) })
        var indexed: [String: SkillItem] = [:]
        var filesFound = 0
        var unreadableCount = 0

        for rawDirectory in directories {
            let expanded = NSString(string: rawDirectory).expandingTildeInPath
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }
            let root = URL(fileURLWithPath: expanded, isDirectory: true)
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
                options: [.skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else { continue }

            for case let url as URL in enumerator {
                if [".git", "build", ".build"].contains(url.lastPathComponent) {
                    enumerator.skipDescendants()
                    continue
                }
                guard url.lastPathComponent.caseInsensitiveCompare("SKILL.md") == .orderedSame else { continue }
                filesFound += 1
                guard let parsed = parse(url: url) else {
                    unreadableCount += 1
                    continue
                }

                let key = normalizedName(parsed.name)
                guard !key.isEmpty else {
                    unreadableCount += 1
                    continue
                }
                if var current = indexed[key] {
                    if !current.sourcePaths.contains(url.path) { current.sourcePaths.append(url.path) }
                    indexed[key] = current
                    continue
                }

                let old = previous[key]
                indexed[key] = SkillItem(
                    name: key,
                    summary: parsed.description,
                    category: old?.category ?? SkillCategories.inferred(for: key, summary: parsed.description),
                    sourcePaths: [url.path],
                    isFavorite: old?.isFavorite ?? false
                )
            }
        }

        let skills = indexed.values.sorted {
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite && !$1.isFavorite }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        return SkillScanResult(
            skills: skills,
            filesFound: filesFound,
            duplicateCount: max(0, filesFound - skills.count - unreadableCount),
            unreadableCount: unreadableCount
        )
    }

    private static func parse(url: URL) -> (name: String, description: String)? {
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let lines = raw.components(separatedBy: .newlines)
        var values: [String: String] = [:]
        var bodyStart = 0

        if lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
            var index = 1
            while index < lines.count {
                let line = lines[index]
                if line.trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                    bodyStart = index + 1
                    break
                }
                guard !line.hasPrefix(" "), let colon = line.firstIndex(of: ":") else {
                    index += 1
                    continue
                }
                let key = String(line[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                var value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if value == "|" || value == ">" {
                    var parts: [String] = []
                    index += 1
                    while index < lines.count {
                        let continuation = lines[index]
                        if continuation.trimmingCharacters(in: .whitespacesAndNewlines) == "---" { break }
                        if !continuation.isEmpty && !continuation.hasPrefix(" ") && continuation.contains(":") { break }
                        let part = continuation.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !part.isEmpty { parts.append(part) }
                        index += 1
                    }
                    value = parts.joined(separator: " ")
                    values[key] = clean(value)
                    continue
                }
                values[key] = clean(value)
                index += 1
            }
        }

        let fallbackName = url.deletingLastPathComponent().lastPathComponent
        let name = normalizedName(values["name"] ?? fallbackName)
        var description = clean(values["description"] ?? "")
        if description.isEmpty {
            description = fallbackDescription(lines: lines, startingAt: bodyStart)
        }
        return (name, description)
    }

    private static func fallbackDescription(lines: [String], startingAt start: Int) -> String {
        var paragraph: [String] = []
        for line in lines.dropFirst(start) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                if !paragraph.isEmpty { break }
                continue
            }
            if trimmed.hasPrefix("#") || trimmed.hasPrefix("```") { continue }
            paragraph.append(trimmed)
            if paragraph.joined(separator: " ").count >= 220 { break }
        }
        return clean(paragraph.joined(separator: " "))
    }

    private static func clean(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.count >= 2,
           (result.hasPrefix("\"") && result.hasSuffix("\"") || result.hasPrefix("'") && result.hasSuffix("'")) {
            result.removeFirst(); result.removeLast()
        }
        return result.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func normalizedName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "$"))
            .lowercased()
    }
}
