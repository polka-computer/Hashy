import Foundation
import os.log

/// Installs the Claude Code skill directory and session hook into the vault
/// so users running `claude` inside their vault get Hashy-aware helpers.
///
/// Installed layout:
/// ```
/// .claude/
/// ├── settings.local.json          ← SessionStart hook (sources vault-search.sh)
/// └── skills/hashy/
///     ├── SKILL.md
///     └── scripts/
///         └── vault-search.sh
/// ```
///
/// Files are **always overwritten** on every app launch so that updates
/// shipped in new app versions are picked up immediately.
public enum VaultSkillInstaller {

    private static let logger = Logger(
        subsystem: "ca.long.tail.labs.hashy",
        category: "VaultSkillInstaller"
    )

    /// Installs (or updates) the Claude Code skill and session hook in the vault.
    public static func installIfNeeded(in vaultDirectory: URL) {
        let claudeDir = vaultDirectory.appendingPathComponent(".claude")
        let skillDir = claudeDir
            .appendingPathComponent("skills")
            .appendingPathComponent("hashy")
        let scriptsDir = skillDir.appendingPathComponent("scripts")

        // --- Load resources from bundle ---

        guard let skillContent = loadBundleResource(name: "SKILL", ext: "md") else {
            logger.error("Failed to load SKILL.md from bundle resources")
            return
        }

        guard let scriptContent = loadBundleResource(name: "vault-search", ext: "sh", subdirectory: "Skills/scripts")
                ?? loadBundleResource(name: "vault-search", ext: "sh") else {
            logger.error("Failed to load vault-search.sh from bundle resources")
            return
        }

        // --- Write skill files (always overwrite) ---

        do {
            try FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
            try skillContent.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
            try scriptContent.write(to: scriptsDir.appendingPathComponent("vault-search.sh"), atomically: true, encoding: .utf8)
        } catch {
            logger.error("Failed to install skill files: \(error.localizedDescription)")
        }

        // --- Ensure SessionStart hook in settings.local.json ---

        installSessionHook(in: claudeDir)
    }

    // MARK: - Private

    private static func loadBundleResource(name: String, ext: String, subdirectory: String = "Skills") -> String? {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
                ?? Bundle.module.url(forResource: name, withExtension: ext) else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Ensures `.claude/settings.local.json` contains the SessionStart hook that
    /// sources `vault-search.sh` into `CLAUDE_ENV_FILE`.
    private static func installSessionHook(in claudeDir: URL) {
        let settingsFile = claudeDir.appendingPathComponent("settings.local.json")
        let hookCommand = "cat \"$CLAUDE_PROJECT_DIR\"/.claude/skills/hashy/scripts/vault-search.sh >> \"$CLAUDE_ENV_FILE\""

        // Read existing settings (or start fresh)
        var root: [String: Any]
        if let data = try? Data(contentsOf: settingsFile),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root = parsed
        } else {
            root = [:]
        }

        // Check if our hook is already present
        if let hooks = root["hooks"] as? [String: Any],
           let sessionStart = hooks["SessionStart"] as? [[String: Any]] {
            let alreadyInstalled = sessionStart.contains { group in
                guard let innerHooks = group["hooks"] as? [[String: Any]] else { return false }
                return innerHooks.contains { ($0["command"] as? String) == hookCommand }
            }
            if alreadyInstalled { return }
        }

        // Build the hook entry
        let hookEntry: [String: Any] = [
            "hooks": [[
                "type": "command",
                "command": hookCommand
            ]]
        ]

        // Merge into existing hooks
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        var sessionStartArray = hooks["SessionStart"] as? [[String: Any]] ?? []
        sessionStartArray.append(hookEntry)
        hooks["SessionStart"] = sessionStartArray
        root["hooks"] = hooks

        // Write back
        do {
            let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: settingsFile, options: .atomic)
        } catch {
            logger.error("Failed to install session hook: \(error.localizedDescription)")
        }
    }
}
