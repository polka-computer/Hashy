# AGENTS.md

## Project Overview

Hashy is an open source native macOS/iOS markdown editor with built-in AI chat, iCloud sync, and Claude Code integration. Built by LongTail Labs.

## Architecture

### Core (Swift Package)

The `Core/` directory is a Swift Package with 4 libraries:

- **MarkdownStorage** - File I/O, iCloud sync via iCloud Drive, conflict detection (hash-based), file watching, and security-scoped bookmarks for custom vault folders.
- **HashyEditor** - Advanced markdown text editor built on STTextView.
- **AIFeature** - AI client using OpenRouter via the Conduit library. Implements 11 tools (create/read/update/delete/search notes) with function calling. Supports 9+ models with custom model addition.
- **AppFeature** - Main application state management using The Composable Architecture (TCA). Handles navigation, settings sync via iCloud KVS, and UI state.

### Hashy (Xcode App)

The `Hashy/` directory contains the Xcode project targeting macOS 14+ and iOS 17+.

### Site (Landing Page)

The `site/` directory contains a Vite + React landing page. Run with `npm run dev` from the `site/` directory.

## Key Technical Details

- **Language:** Swift 6.2 with SwiftUI
- **State Management:** The Composable Architecture (TCA) with Swift Dependencies
- **File Format:** Plain `.md` files with YAML frontmatter (title, tags, icon)
- **Filenames:** ULID-based (e.g., `01JQ3K7M8N.md`) for time-ordered uniqueness
- **iCloud:** Uses iCloud Drive for file sync + iCloud KVS for settings sync
- **AI Provider:** OpenRouter API (`api.openrouter.ai`) with user-provided API key
- **Bundle ID:** `long.tail.labs.Hashy`

## Coding Conventions

- Swift 6.2 strict concurrency
- TCA reducer pattern with `@Reducer` macro
- Dependencies via `@Dependency` property wrapper
- OSLog logging with subsystem `ca.long.tail.labs.hashy`
- YAML frontmatter parsed with Yams library

## Vault Skill

Hashy auto-installs a Claude Code skill at `.claude/skills/hashy/SKILL.md` in the user's vault. This skill teaches Claude Code the note format, filename conventions, and frontmatter structure so it can create and edit notes correctly.

## Common Tasks

### Building
Open `Hashy/Hashy.xcodeproj` in Xcode. The `Core` Swift package resolves automatically.

### Running the Landing Page
```bash
cd site && npm run dev
```

### Adding a New AI Model
Models are defined in `Core/Sources/AIFeature/`. Add the model ID to the built-in list or users can add custom models via settings.

### Adding a New AI Tool
Tools are defined using the Conduit library's tool definition pattern in `Core/Sources/AIFeature/`. Each tool has a schema, description, and handler that operates on the vault.
