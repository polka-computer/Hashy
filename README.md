# Hashy

<p align="center">
  <img src="assets/icon.jpg" alt="Hashy" width="128" height="128" style="border-radius: 24px;" />
</p>

<p align="center">
  <strong>The AI-powered markdown editor for macOS & iOS</strong>
  <br />
  Native. Open source. Built for developers who think in markdown.
</p>

<p align="center">
  <a href="https://github.com/polka-computer/Hashy/releases/download/0.1.31/hashy-0.1.31-mac-aarch64.zip">Download for macOS</a> &middot;
  <a href="https://apps.apple.com/us/app/hashy-markdown-notes/id6759118041">Download for iOS</a> &middot;
  <a href="https://github.com/polka-computer/Hashy/issues">Issues</a> &middot;
  <a href="https://discord.gg/zwpnkxETJ3">Discord</a>
</p>

---

## What is Hashy?

Hashy is a native macOS and iOS markdown editor with built-in AI chat, iCloud sync, and Claude Code integration. Your notes are plain `.md` files with YAML frontmatter - no proprietary formats, no lock-in.

Ask the AI to create, organize, search, and edit your notes using 11 specialized tools. Bring your own OpenRouter, OpenAI, or Anthropic API key and pick from 20+ models.

## Features

- **Native SwiftUI** - Built with Swift 6.2 and The Composable Architecture. Not Electron, not a web view.
- **iCloud Sync** - Notes sync across all your Apple devices via iCloud Drive. Conflict detection and resolution built in.
- **AI Chat with Tools** - 11 tools let AI autonomously create, edit, search, and organize your notes. Not just a chatbot.
- **20+ AI Models** - Use OpenRouter, OpenAI, or Anthropic directly. Claude, GPT, Gemini, DeepSeek, Grok, and more. Bring your own API key.
- **Claude Code Skill** - Ships with a `.claude/skills/hashy/SKILL.md` that auto-installs into your vault. Claude Code understands your notes.
- **Plain Markdown** - YAML frontmatter for metadata (title, tags, icon). Standard `.md` files you can read anywhere.
- **No Subscription** - Pay-per-use via your own API key. No monthly fee.

## Supported Models

Three API providers, each unlocked by adding your key in Settings:

**OpenRouter** (default — access 100+ models)
| Provider | Model |
|----------|-------|
| Anthropic | Claude Sonnet 4.5 (default) |
| Anthropic | Claude Opus 4.5 |
| Google | Gemini 3 Flash Preview |
| Google | Gemini 2.5 Flash |
| Google | Gemini 2.5 Flash Lite |
| DeepSeek | DeepSeek V3.2 |
| Moonshot | Kimi K2.5 |
| MiniMax | MiniMax M2.1 |
| xAI | Grok 4.1 Fast |
| Z-AI | GLM-5 |

**OpenAI** (direct API)
| Model |
|-------|
| GPT-5.2 |
| GPT-5.1 |
| GPT-5 Mini |
| GPT-5 Nano |
| GPT-4.1 |

**Anthropic** (direct API)
| Model |
|-------|
| Claude Opus 4.6 |
| Claude Sonnet 4.5 |
| Claude Haiku 4.5 |
| Claude Sonnet 4 |

You can also add custom model identifiers via settings.

## AI Tools

The AI has access to 11 tools that operate directly on your vault:

- **create_note** - Create notes with title, tags, icon, and content
- **read_note** / **read_current_note** - Read any note or the active note
- **update_note_content** - Replace or append content
- **update_note_metadata** - Modify icon, title, or tags
- **delete_note** - Remove notes
- **search_notes** - Search by title or tag
- **full_text_search** - Search across all note content
- **rename_note** - Change a note's title
- **list_notes** - Get all notes with metadata
- **list_tags** - Get all unique tags

## Claude Code Integration

Hashy automatically installs a Claude Code skill into your vault at `.claude/skills/hashy/SKILL.md`. When you use Claude Code in your notes directory, it understands:

- ULID-based filename format
- YAML frontmatter structure (title, tags, icon)
- Vault folder organization
- How to create and modify notes correctly

> **[View the full skill →](Core/Sources/MarkdownStorage/Resources/Skills/SKILL.md)**

## Markdown Support

| Feature | Syntax | Status |
|---------|--------|--------|
| Heading 1 | `# Heading` | Supported |
| Heading 2 | `## Heading` | Supported |
| Heading 3-6 | `### Heading` | Supported |
| Bold | `**bold**` | Supported |
| Italic | `*italic*` | Supported |
| Inline code | `` `code` `` | Supported |
| Code blocks | ` ``` code ``` ` | Supported |
| Bullet lists | `- item` | Supported |
| Task lists | `- [ ] todo` / `- [x] done` | Supported (interactive) |
| Images | `![alt](path)` | Supported (drag & drop, paste, preview) |
| Links | `[text](url)` | Supported |
| Bare URLs | `https://...` | Supported (auto-linked) |
| Wiki-links | `[[noteId\|name]]` | Supported (with autocomplete) |
| Blockquotes | `> text` | Supported |
| Strikethrough | `~~text~~` | Not yet |
| Tables | `\| col \| col \|` | Not yet |
| Mermaid diagrams | ` ```mermaid ` | Not yet |
| Syntax highlighting | Language-specific highlighting | Not yet |
| HTML blocks | Raw HTML | Not yet |
| Footnotes | `[^1]` | Not yet |

## Note Format

```markdown
---
title: My Note Title
tags:
  - example
  - reference
icon: "📝"
---

Your note content here...
```

Files are named using ULIDs (e.g., `01JQ3K7M8N.md`) for time-ordered uniqueness.

## Requirements

- macOS 14.0+ or iOS 17.0+
- An API key from OpenRouter, OpenAI, or Anthropic (for AI features)

## Building from Source

1. Clone the repo
2. Open `Hashy/Hashy.xcodeproj` in Xcode
3. The `Core` Swift package resolves automatically
4. Build and run

## Architecture

```
Core/                          Swift Package
├── MarkdownStorage            File I/O, iCloud sync, conflict detection
├── HashyEditor                Advanced markdown editor
├── AIFeature                  AI client & tool integration
└── AppFeature                 Main UI + state management

Hashy/                         Xcode app target (macOS/iOS)
site/                          Landing page (Vite + React)
```

**Key dependencies:** SwiftUI, TCA (Composable Architecture), [STTextView](https://github.com/krzyzanowskim/STTextView), Conduit, Yams, ULID.swift

## License

MIT

## Credits

Built with 🤖 by [@Jonovono](https://x.com/Jonovono)
