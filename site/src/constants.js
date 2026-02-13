export const VERSION = '0.1.31'

export const LINKS = {
  github: 'https://github.com/polka-computer/Hashy',
  issues: 'https://github.com/polka-computer/Hashy/issues',
  releases: `https://github.com/polka-computer/Hashy/releases/download/${VERSION}/hashy-${VERSION}-mac-aarch64.zip`,
  appStore: 'https://apps.apple.com/us/app/hashy-markdown-notes/id6759118041',
  openRouter: 'https://openrouter.ai',
  discord: 'https://discord.gg/zwpnkxETJ3',
  twitter: 'https://x.com/Jonovono',
}

export const MODELS = {
  openRouter: [
    { name: 'Claude Sonnet 4.5', provider: 'Anthropic' },
    { name: 'Claude Opus 4.5', provider: 'Anthropic' },
    { name: 'Gemini 3 Flash', provider: 'Google' },
    { name: 'Gemini 2.5 Flash', provider: 'Google' },
    { name: 'Gemini 2.5 Flash Lite', provider: 'Google' },
    { name: 'DeepSeek V3.2', provider: 'DeepSeek' },
    { name: 'Kimi K2.5', provider: 'Moonshot' },
    { name: 'MiniMax M2.1', provider: 'MiniMax' },
    { name: 'Grok 4.1 Fast', provider: 'xAI' },
    { name: 'GLM-5', provider: 'Z-AI' },
  ],
  openAI: [
    { name: 'GPT-5.2', provider: 'OpenAI' },
    { name: 'GPT-5.1', provider: 'OpenAI' },
    { name: 'GPT-5 Mini', provider: 'OpenAI' },
    { name: 'GPT-5 Nano', provider: 'OpenAI' },
    { name: 'GPT-4.1', provider: 'OpenAI' },
  ],
  anthropic: [
    { name: 'Claude Opus 4.6', provider: 'Anthropic' },
    { name: 'Claude Sonnet 4.5', provider: 'Anthropic' },
    { name: 'Claude Haiku 4.5', provider: 'Anthropic' },
    { name: 'Claude Sonnet 4', provider: 'Anthropic' },
  ],
}

export const TOOLS = [
  { icon: '📝', name: 'Create notes', desc: 'Generate new notes with titles, tags, and content' },
  { icon: '🔍', name: 'Search vault', desc: 'Full-text search across your entire vault' },
  { icon: '✏️', name: 'Edit notes', desc: 'Update content, metadata, tags, and titles' },
  { icon: '🗂️', name: 'Organize', desc: 'Rename, tag, and restructure your notes' },
  { icon: '📋', name: 'List & filter', desc: 'Browse all notes with tag-based filtering' },
  { icon: '🗑️', name: 'Clean up', desc: 'Remove outdated notes and duplicates' },
]

export const FEATURES = [
  {
    icon: '🍎',
    title: 'Native to the bone',
    desc: 'Built with SwiftUI and TCA. Not an Electron wrapper. Not a web view. A real, fast, native app for macOS and iOS.',
  },
  {
    icon: '☁️',
    title: 'iCloud sync, just works',
    desc: 'Your notes live in iCloud Drive. Open on Mac, continue on iPhone. Conflict detection handles the rest.',
  },
  {
    icon: '🤖',
    title: 'AI that does things',
    desc: '11 tools let AI create, edit, search, and organize your notes. Not just a chatbot - an autonomous assistant.',
  },
  {
    icon: '🔓',
    title: 'Open source, open files',
    desc: 'Plain markdown files with YAML frontmatter. Your notes are yours. Read them anywhere, forever.',
  },
  {
    icon: '⌨️',
    title: 'Built for Claude Code',
    desc: 'Ships with a Claude Code skill. AI agents can read and write your vault directly from the terminal.',
  },
  {
    icon: '💸',
    title: 'No subscription',
    desc: 'Bring your own API key — OpenRouter, OpenAI, or Anthropic. Pay per use. No monthly fee, no vendor lock-in.',
  },
]
