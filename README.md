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
  <a href="https://github.com/nicktrienenern/Hashy/releases">Download</a> &middot;
  <a href="https://github.com/nicktrienenern/Hashy/issues">Issues</a> &middot;
  <a href="#features">Features</a>
</p>

---

## What is Hashy?

Hashy is a native macOS and iOS markdown editor with built-in AI chat, iCloud sync, and Claude Code integration. Your notes are plain `.md` files with YAML frontmatter - no proprietary formats, no lock-in.

Ask the AI to create, organize, search, and edit your notes using 11 specialized tools. Pick from 9+ models via OpenRouter, or add your own.

## Features

- **Native SwiftUI** - Built with Swift 6.2 and The Composable Architecture. Not Electron, not a web view.
- **iCloud Sync** - Notes sync across all your Apple devices via iCloud Drive. Conflict detection and resolution built in.
- **AI Chat with Tools** - 11 tools let AI autonomously create, edit, search, and organize your notes. Not just a chatbot.
- **9+ AI Models** - Claude, Gemini, DeepSeek, Grok, and more via OpenRouter. Bring your own API key.
- **Claude Code Skill** - Ships with a `.claude/skills/hashy/SKILL.md` that auto-installs into your vault. Claude Code understands your notes.
- **Plain Markdown** - YAML frontmatter for metadata (title, tags, icon). Standard `.md` files you can read anywhere.
- **No Subscription** - Pay-per-use via your own OpenRouter key. No monthly fee.

## Supported Models

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
- OpenRouter API key (for AI features)

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

**Key dependencies:** SwiftUI, TCA (Composable Architecture), STTextView, Conduit, Yams, ULID.swift

## License

MIT

## Credits

Built with 🤖 by [@Jonovono](https://x.com/Jonovono)
