import Foundation

@MainActor
final class SkillStore: ObservableObject {
    @Published private(set) var skills: [SkillItem] = []
    @Published private(set) var directories: [String] = SkillDefaults.directories
    @Published private(set) var isScanning = false
    @Published private(set) var lastScanDate: Date?
    @Published private(set) var scanSummary = "尚未扫描"

    var onSave: (() -> Void)?

    var favoriteSkills: [SkillItem] { skills.filter(\.isFavorite) }

    func setState(skills: [SkillItem], directories: [String], lastScanDate: Date?) {
        self.skills = skills
        self.directories = directories.isEmpty ? SkillDefaults.directories : directories
        self.lastScanDate = lastScanDate
        if let lastScanDate {
            scanSummary = "已索引 \(skills.count) 个 Skill · \(lastScanDate.formatted(date: .abbreviated, time: .shortened))"
        }
    }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        scanSummary = "正在扫描..."
        let roots = directories
        let existing = skills
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = SkillScanner.scan(directories: roots, existing: existing)
            DispatchQueue.main.async {
                guard let self else { return }
                self.skills = result.skills
                self.lastScanDate = Date()
                self.isScanning = false
                self.scanSummary = "发现 \(result.filesFound) 份，去重后 \(result.skills.count) 个，合并 \(result.duplicateCount) 份重复"
                if result.unreadableCount > 0 {
                    self.scanSummary += "，\(result.unreadableCount) 份无法解析"
                }
                self.onSave?()
            }
        }
    }

    func toggleFavorite(_ skill: SkillItem) {
        guard let index = skills.firstIndex(where: { $0.id == skill.id }) else { return }
        skills[index].isFavorite.toggle()
        sortSkills()
        onSave?()
    }

    func setCategory(skillID: String, category: String) {
        guard let index = skills.firstIndex(where: { $0.id == skillID }) else { return }
        skills[index].category = category
        onSave?()
    }

    func addDirectory(_ path: String) {
        let normalized = NSString(string: path.trimmingCharacters(in: .whitespacesAndNewlines)).expandingTildeInPath
        guard !normalized.isEmpty, !directories.contains(normalized) else { return }
        directories.append(normalized)
        onSave?()
    }

    func removeDirectory(_ path: String) {
        directories.removeAll { $0 == path }
        onSave?()
    }

    func matching(query: String, category: String? = nil, favoritesOnly: Bool = false, limit: Int = 60) -> [SkillItem] {
        let candidates = skills.filter { skill in
            (!favoritesOnly || skill.isFavorite) && (category == nil || skill.category == category)
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return Array(candidates.prefix(limit)) }
        return candidates
            .map { ($0, searchScore(skill: $0, query: trimmed)) }
            .filter { $0.1 > 0 }
            .sorted {
                if $0.1 != $1.1 { return $0.1 > $1.1 }
                if $0.0.isFavorite != $1.0.isFavorite { return $0.0.isFavorite }
                return $0.0.name.localizedStandardCompare($1.0.name) == .orderedAscending
            }
            .prefix(limit)
            .map(\.0)
    }

    func recommendations(for taskTitle: String, limit: Int = 3) -> [SkillItem] {
        Array(matching(query: taskTitle, limit: limit))
    }

    private func searchScore(skill: SkillItem, query: String) -> Int {
        let haystack = "\(skill.name) \(skill.summary) \(skill.category)".lowercased()
        let needle = query.lowercased()
        var score = 0
        if skill.name.lowercased() == needle { score += 300 }
        if skill.name.lowercased().contains(needle) { score += 140 }
        if skill.summary.lowercased().contains(needle) { score += 100 }
        if skill.category.lowercased().contains(needle) { score += 60 }

        let tokens = searchTokens(from: needle)
        for token in tokens where haystack.contains(token) {
            score += token.count >= 4 ? 24 : 12
        }
        if skill.isFavorite { score += 4 }
        return score
    }

    private func searchTokens(from query: String) -> Set<String> {
        let separators = CharacterSet.alphanumerics.inverted
        var tokens = Set(query.components(separatedBy: separators).filter { $0.count >= 2 })
        let chinese = query.unicodeScalars.filter { (0x4E00...0x9FFF).contains(Int($0.value)) }.map(String.init).joined()
        let chars = Array(chinese)
        if chars.count >= 2 {
            for length in 2...min(4, chars.count) {
                for start in 0...(chars.count - length) {
                    tokens.insert(String(chars[start..<(start + length)]))
                }
            }
        }
        return tokens
    }

    private func sortSkills() {
        skills.sort {
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite && !$1.isFavorite }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}
