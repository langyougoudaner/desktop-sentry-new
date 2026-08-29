import Foundation

@main
struct PrivacyDefaultsSmoke {
    static func main() throws {
        let freshInstall = AppData.default

        precondition(freshInstall.tasks.isEmpty, "fresh install must not contain tasks")
        precondition(freshInstall.prompts.isEmpty, "fresh install must not contain prompts")
        precondition(freshInstall.quickMenuPromptIDs.isEmpty,
                     "fresh install must not reference prompt IDs")
        precondition(freshInstall.copyHistory.isEmpty,
                     "fresh install must not contain clipboard history")
        precondition(freshInstall.skills.isEmpty, "fresh install must not contain scanned Skills")
        precondition(freshInstall.titleCustomText.isEmpty,
                     "fresh install must not contain a personal menu-bar title")

        let encoded = try JSONEncoder().encode(freshInstall)
        let decoded = try JSONDecoder().decode(AppData.self, from: encoded)
        precondition(decoded.prompts.isEmpty && decoded.tasks.isEmpty && decoded.skills.isEmpty)

        print("privacy-fresh-install-empty=passed")
    }
}
