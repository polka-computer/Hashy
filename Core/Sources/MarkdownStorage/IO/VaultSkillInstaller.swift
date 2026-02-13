import Foundation

/// Installs a Claude Code skill into the vault directory so users
/// running `claude` inside their vault know how to work with it.
public enum VaultSkillInstaller {
    /// Ensures `.claude/skills/hashy/SKILL.md` exists in the given vault directory.
    /// Only writes if the file is missing or outdated.
    public static func installIfNeeded(in vaultDirectory: URL) {
        let skillDir = vaultDirectory
            .appendingPathComponent(".claude")
            .appendingPathComponent("skills")
            .appendingPathComponent("hashy")
        let skillFile = skillDir.appendingPathComponent("SKILL.md")

        // Check if current version already installed
        if let existing = try? String(contentsOf: skillFile, encoding: .utf8),
           existing.contains(versionMarker) {
            return
        }

        try? FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        try? skillContent.write(to: skillFile, atomically: true, encoding: .utf8)
    }

    // Bump this when skill content changes to trigger re-install
    private static let versionMarker = "hashy-skill-v1"

    private static let skillContent = """
---
name: hashy
description: How to work with this Hashy notes vault. Loaded when searching, reading, or creating notes.
user-invocable: false
---

<!-- hashy-skill-v1 -->

# Hashy Vault

This directory is a Hashy knowledge base. Files here sync across devices and appear in the Hashy app.

## Reading & searching notes

Use your normal tools to explore:

- `Grep` to search note content (e.g. find all notes mentioning "kubernetes")
- `Glob` to find files by pattern (e.g. `*.md`)
- `Read` to read a note's content

## Creating notes

Create new notes as markdown files in the **root of this directory**. Do NOT create subdirectories.

**Filename**: Use a ULID (time-ordered unique ID) with `.md` extension. Example: `01J5A3B9KP7QXYZ12345ABCDE.md`

Generate a ULID filename with:

```bash
python3 -c "import time,random; t=int(time.time()*1000); cs='0123456789ABCDEFGHJKMNPQRSTVWXYZ'; e=''.join(cs[(t>>(45-5*i))&31] for i in range(10)); r=''.join(cs[random.randint(0,31)] for _ in range(16)); print(e+r+'.md')"
```

**Frontmatter**: Every note MUST start with YAML frontmatter containing at least a `title`:

```markdown
---
title: My Note Title
tags:
  - example
  - reference
icon: "\u{1F4DD}"
---

Your note content here...
```

| Field | Required | Description |
|-------|----------|-------------|
| `title` | Yes | Display name shown in the app |
| `tags` | No | Array of tags for filtering |
| `icon` | No | Single emoji shown next to the title |

## Editing notes

Edit the markdown body below the frontmatter `---` delimiter. Preserve the frontmatter block.
To rename a note, change the `title` field in frontmatter (NOT the filename).

## What happens

- New/changed files appear in the Hashy app within seconds
- If iCloud is enabled, changes sync to all devices automatically
- The app reads frontmatter for display — no frontmatter means no title in the sidebar
"""
}
