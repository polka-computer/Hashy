---
name: hashy
description: How to work with this Hashy notes vault. Loaded when searching, reading, or creating notes.
user-invocable: false
---

<!-- hashy-skill-v2 -->

# Hashy Vault

This directory is a Hashy knowledge base. Files here sync across devices and appear in the Hashy app.

## Reading & searching notes

Use your normal tools to explore:

- `Grep` to search note content (e.g. find all notes mentioning "kubernetes")
- `Glob` to find files by pattern (e.g. `*.md`)
- `Read` to read a note's content

## Creating notes

Create new notes as markdown files in the **root of this directory**. Do NOT create subdirectories.

**Filename**: Use a ULID (time-ordered unique ID) with `.md` extension. Generate one with `hashy_ulid`:

```bash
hashy_ulid   # → 01J5A3B9KP7QXYZ12345ABCDE.md
```

**Frontmatter**: Every note MUST start with YAML frontmatter containing at least a `title`:

```markdown
---
title: My Note Title
tags:
  - example
  - reference
icon: "\U0001F4DD"
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

## Supported markdown

Hashy renders the following markdown syntax with live highlighting. Use these freely in note content.

### Text formatting

| Syntax | Renders as |
|--------|-----------|
| `**bold**` | **bold** |
| `*italic*` | *italic* |
| `` `inline code` `` | `inline code` |
| `> blockquote` | Blockquote (dimmed text) |

### Headings

`# H1` through `###### H6` — each level gets progressively smaller/lighter styling.

### Lists

Bullet lists with `-` or `*`:

```markdown
- First item
- Second item
  - Nested (indent 2 spaces)
```

List continuation is automatic — pressing Enter continues the list prefix.

### Task lists (interactive)

Tasks are clickable checkboxes in the app. Completed tasks render with strikethrough.

```markdown
- [ ] Open task
- [x] Completed task
```

Toggle a task by clicking its checkbox, or use `Cmd+Return` on a line to cycle between plain list item → open task → completed task.

### Links

Standard markdown links render inline — the URL portion is hidden, showing only the link text:

```markdown
[Link text](https://example.com)
```

Bare URLs are auto-linked:

```markdown
https://example.com
```

### Wiki-links (cross-references between notes)

Reference other notes using wiki-link syntax. The note ID is the filename without `.md`:

```markdown
[[NOTE_ID|Display Name]]
[[NOTE_ID]]
```

Examples:

```markdown
See [[01J5A3B9KP7QXYZ12345ABCDE|Project Alpha]] for details.
Related: [[01J5A3B9KP7QXYZ12345ABCDE]]
```

Wiki-links render as styled chips in the editor. The `|Display Name` part is optional — if omitted, the app resolves the title from the linked note's frontmatter.

When creating wiki-links programmatically, always use `[[id|title]]` format so the link text is readable even outside the app.

### Images

Images are embedded with standard markdown syntax:

```markdown
![Alt text](path/to/image.png)
```

Images are stored in a `_assets/` subdirectory relative to the vault root. When adding images, save the file to `_assets/` and reference it with a relative path:

```markdown
![Screenshot](_assets/screenshot.png)
```

Remote images (`https://...`) are also supported and fetched on demand.

## Vault search utilities

Bash helper functions for querying the vault are bundled in [scripts/vault-search.sh](scripts/vault-search.sh). They are **auto-sourced on session start** via a `SessionStart` hook — just call them directly. All use only macOS-standard tools (`grep`, `awk`, `sed`, `sort`, `ls`).

### Notes & search

| Function | Description | Example |
|----------|-------------|---------|
| `hashy_ulid` | Generate a ULID filename for a new note | `hashy_ulid` |
| `hashy_ls` | List notes with titles (most recent first) | `hashy_ls` |
| `hashy_tag TAG` | Find notes with a specific tag | `hashy_tag "kubernetes"` |
| `hashy_tags` | List all tags with occurrence counts | `hashy_tags` |
| `hashy_search QUERY` | Full-text search (skips frontmatter, case-insensitive) | `hashy_search "deployment"` |
| `hashy_find PATTERN` | Search notes by title pattern | `hashy_find "meeting"` |

### Tasks

| Function | Description | Example |
|----------|-------------|---------|
| `hashy_tasks` | List all tasks (open and completed) | `hashy_tasks` |
| `hashy_todo` | List open tasks (`- [ ]`) only | `hashy_todo` |
| `hashy_done` | List completed tasks (`- [x]`) only | `hashy_done` |

### Links & images

| Function | Description | Example |
|----------|-------------|---------|
| `hashy_links` | Extract all markdown links and bare URLs | `hashy_links` |
| `hashy_images` | Extract all image references (`![alt](path)`) | `hashy_images` |

### Wiki-link graph

| Function | Description | Example |
|----------|-------------|---------|
| `hashy_wikilinks` | List all wiki-link connections (source → target) | `hashy_wikilinks` |
| `hashy_backlinks ID` | Find all notes that link to a specific note | `hashy_backlinks "01J5A3..."` |
| `hashy_graph` | Full connection map (adjacency list per note) | `hashy_graph` |
| `hashy_orphans` | Find notes with no incoming wiki-links | `hashy_orphans` |
| `hashy_broken` | Find wiki-links pointing to non-existent notes | `hashy_broken` |

### Frontmatter quality

| Function | Description | Example |
|----------|-------------|---------|
| `hashy_notitle` | Find notes missing a title | `hashy_notitle` |
| `hashy_notags` | Find notes missing tags | `hashy_notags` |
| `hashy_noicon` | Find notes missing an icon emoji | `hashy_noicon` |
| `hashy_incomplete` | Find notes missing any field (shows which) | `hashy_incomplete` |

For implementation details, read [scripts/vault-search.sh](scripts/vault-search.sh).
