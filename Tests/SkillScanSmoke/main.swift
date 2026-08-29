import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
    exit(1)
}

let startedAt = Date()
let result = SkillScanner.scan(directories: SkillDefaults.directories, existing: [])
let elapsed = Date().timeIntervalSince(startedAt)

guard result.filesFound >= 150 else { fail("只找到 \(result.filesFound) 份 SKILL.md") }
guard result.skills.count >= 150 else { fail("去重后只剩 \(result.skills.count) 个 Skill") }
guard result.filesFound >= result.skills.count else { fail("文件数小于索引数") }
guard result.skills.allSatisfy({ !$0.name.isEmpty && !$0.sourcePaths.isEmpty }) else {
    fail("存在名称或来源为空的 Skill")
}
guard elapsed < 3 else { fail(String(format: "扫描耗时 %.3f 秒，超过 3 秒", elapsed)) }

let fixtureRoot = FileManager.default.temporaryDirectory
    .appendingPathComponent("DesktopSentrySkillSmoke-\(UUID().uuidString)", isDirectory: true)
defer { try? FileManager.default.removeItem(at: fixtureRoot) }
let first = fixtureRoot.appendingPathComponent("first", isDirectory: true)
let duplicate = fixtureRoot.appendingPathComponent("duplicate", isDirectory: true)
try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: duplicate, withIntermediateDirectories: true)
try Data("---\nname: Example-Skill\ndescription: |\n  analyze a local fixture\n  without network access\n---\n".utf8)
    .write(to: first.appendingPathComponent("SKILL.md"))
try Data("---\nname: example-skill\ndescription: duplicate\n---\n".utf8)
    .write(to: duplicate.appendingPathComponent("SKILL.md"))
let fixtureInitial = SkillScanner.scan(directories: [fixtureRoot.path], existing: [])
guard fixtureInitial.filesFound == 2, fixtureInitial.skills.count == 1,
      fixtureInitial.skills[0].sourcePaths.count == 2,
      fixtureInitial.skills[0].summary.contains("without network access") else {
    fail("同名去重、来源保留或多行描述解析失败")
}
try FileManager.default.removeItem(at: duplicate.appendingPathComponent("SKILL.md"))
let fixtureAfterDelete = SkillScanner.scan(directories: [fixtureRoot.path], existing: fixtureInitial.skills)
guard fixtureAfterDelete.filesFound == 1, fixtureAfterDelete.skills.count == 1,
      fixtureAfterDelete.skills[0].sourcePaths.count == 1 else {
    fail("删除 Skill 后重新扫描未更新")
}

let duplicateSources = result.skills.filter { $0.sourcePaths.count > 1 }.count
let described = result.skills.filter { !$0.summary.isEmpty }.count
guard var preservedSkill = result.skills.first else { fail("索引为空") }
preservedSkill.isFavorite = true
preservedSkill.category = "思考与决策"
let rescanned = SkillScanner.scan(directories: SkillDefaults.directories, existing: [preservedSkill])
guard let preserved = rescanned.skills.first(where: { $0.id == preservedSkill.id }),
      preserved.isFavorite, preserved.category == "思考与决策" else {
    fail("重新扫描后收藏或手动分类丢失")
}
guard preserved.invocation(task: "完成测试").contains("$\(preserved.id)"),
      preserved.invocation(task: "完成测试").contains("完成测试") else {
    fail("组合调用语缺少 Skill 名称或待办内容")
}
print("files=\(result.filesFound)")
print("unique=\(result.skills.count)")
print("duplicates=\(result.duplicateCount)")
print("multiSourceSkills=\(duplicateSources)")
print("unreadable=\(result.unreadableCount)")
print("described=\(described)")
print(String(format: "elapsed=%.3f", elapsed))

if CommandLine.arguments.count > 1 {
    let dataURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let data = try Data(contentsOf: dataURL)
    let appData = try JSONDecoder().decode(AppData.self, from: data)
    print("legacyTasks=\(appData.tasks.count)")
    print("legacyPrompts=\(appData.prompts.count)")
    print("legacySkills=\(appData.skills.count)")
}

Task { @MainActor in
    let store = SkillStore()
    store.setState(skills: result.skills, directories: SkillDefaults.directories, lastScanDate: Date())
    let queryStartedAt = Date()
    let matches = store.matching(query: "分析网页数据", limit: 20)
    let queryElapsed = Date().timeIntervalSince(queryStartedAt)
    guard !matches.isEmpty else { fail("自然语言用途搜索没有结果") }
    guard queryElapsed < 3 else { fail("搜索超过 3 秒") }
    print("queryMatches=\(matches.count)")
    print(String(format: "queryElapsed=%.6f", queryElapsed))
    exit(0)
}

RunLoop.main.run()
