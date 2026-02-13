import './App.css'
import { LINKS, MODELS, TOOLS, FEATURES } from './constants'

function Nav() {
  return (
    <nav className="nav">
      <div className="nav-inner">
        <a href="#" className="nav-logo">
          <img src="/icon.jpg" alt="Hashy" className="nav-icon" />
          <span className="nav-name">Hashy</span>
        </a>
        <div className="nav-links">
          <a href="#features">Features</a>
          <a href="#shortcuts">Shortcuts</a>
          <a href="#ai">AI</a>
          <a href="#claude-code">Claude Code</a>
          <a href={LINKS.github} target="_blank" rel="noopener">GitHub</a>
          <a href={LINKS.discord} target="_blank" rel="noopener">Discord</a>
          <a href="#download" className="btn btn-sm">
            Download
          </a>
        </div>
      </div>
    </nav>
  )
}

function Hero() {
  return (
    <section className="hero">
      <div className="hero-glow" />
      <div className="hero-content">
        <div className="hero-badge">
          <span className="badge-dot" />
          Open Source &middot; v0.1.25
        </div>
        <h1 className="hero-title">
          The markdown editor
          <br />
          that <span className="hero-highlight">thinks</span> with you
        </h1>
        <p className="hero-subtitle">
          A native macOS & iOS markdown editor with built-in AI chat,
          any OpenRouter model, iCloud sync, and Claude Code integration.
          <br />
          <span className="hero-dim">Your markdown. Your models. Your rules.</span>
        </p>
        <div className="hero-actions">
          <a href={LINKS.releases} className="btn btn-lg" target="_blank" rel="noopener">
            <span className="btn-icon">↓</span>
            Download for Mac
          </a>
          <a href={LINKS.appStore} className="btn btn-lg" target="_blank" rel="noopener">
            <span className="btn-icon">↓</span>
            Download for iOS
          </a>
          <a href={LINKS.github} className="btn btn-lg btn-outline" target="_blank" rel="noopener">
            View on GitHub
          </a>
        </div>
        <div className="hero-platforms">
          macOS 14+ &middot; iOS 17+ &middot; Apple Silicon native
        </div>
      </div>
      <div className="hero-visual">
        {/* macOS Window */}
        <div className="hero-window hero-mac">
          <div className="window-bar">
            <span className="window-dot red" />
            <span className="window-dot yellow" />
            <span className="window-dot green" />
            <span className="window-title">Hashy</span>
          </div>
          <div className="window-body">
            <div className="mock-sidebar">
              <div className="mock-search">
                <span className="mock-search-icon">🔍</span>
                <span className="mock-search-text">Search notes...</span>
              </div>
              <div className="mock-note">
                <span>📝</span> Project Ideas
              </div>
              <div className="mock-note active">
                <span>🚀</span> Launch Checklist
              </div>
              <div className="mock-note">
                <span>💡</span> AI Prompts
              </div>
              <div className="mock-note">
                <span>📖</span> Reading List
              </div>
              <div className="mock-note">
                <span>🔧</span> Dev Notes
              </div>
            </div>
            <div className="mock-editor">
              <div className="mock-frontmatter">
                <span className="mock-delim">---</span>
                <br />
                <span className="mock-key">title:</span>{' '}
                <span className="mock-val">Launch Checklist</span>
                <br />
                <span className="mock-key">tags:</span>
                <br />
                <span className="mock-tag">  - launch</span>
                <br />
                <span className="mock-tag">  - tasks</span>
                <br />
                <span className="mock-key">icon:</span>{' '}
                <span className="mock-val">"🚀"</span>
                <br />
                <span className="mock-delim">---</span>
              </div>
              <div className="mock-content">
                <span className="mock-h1"># Launch Checklist</span>
                <br /><br />
                <span className="mock-text">Ship the markdown editor. See</span>
                <br />
                <span className="mock-text"><span className="mock-wikilink">@API Design Decisions</span> for context.</span>
                <br /><br />
                <span className="mock-h2">## Tasks</span>
                <br /><br />
                <span className="mock-task done"><span className="mock-checkbox checked">&#x2611;</span> <s>Set up iCloud sync</s></span>
                <br />
                <span className="mock-task done"><span className="mock-checkbox checked">&#x2611;</span> <s>Add AI chat panel</s></span>
                <br />
                <span className="mock-task done"><span className="mock-checkbox checked">&#x2611;</span> <s>Wiki-link autocomplete</s></span>
                <br />
                <span className="mock-task"><span className="mock-checkbox">&#x2610;</span> Publish to App Store</span>
                <br />
                <span className="mock-task highlight"><span className="mock-checkbox">&#x2610;</span> Write launch post</span>
                <br />
                <span className="mock-cursor" />
              </div>
            </div>
            <div className="mock-chat">
              <div className="mock-chat-header">
                <span>🤖</span> AI Chat
              </div>
              <div className="mock-chat-messages">
                <div className="mock-msg user">
                  Organize my notes by topic and add tags
                </div>
                <div className="mock-msg ai">
                  Done! I've tagged 12 notes across 4 topics:
                  <span className="mock-tag-inline">#projects</span>
                  <span className="mock-tag-inline">#research</span>
                  <span className="mock-tag-inline">#personal</span>
                  <span className="mock-tag-inline">#ideas</span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Sync indicator */}
        <div className="hero-sync">
          <div className="sync-icon">
            <svg viewBox="0 0 24 24" fill="none" className="sync-svg">
              <path d="M7.5 21.5C4.46 21.5 2 19.04 2 16C2 13.36 3.86 11.15 6.34 10.62C6.12 10.12 6 9.57 6 9C6 6.79 7.79 5 10 5C10.72 5 11.39 5.19 11.97 5.52C13.07 3.42 15.27 2 17.78 2C21.45 2 22 5.13 22 8C22 8.2 22 8.4 21.98 8.59C23.22 9.31 24 10.62 24 12.11V12.11" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
              <path d="M14.5 16L17 13.5L19.5 16" stroke="var(--green)" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="sync-arrow-up" />
              <path d="M17 14V20" stroke="var(--green)" strokeWidth="1.5" strokeLinecap="round" className="sync-arrow-up" />
              <path d="M10.5 20L8 22.5L5.5 20" stroke="var(--green)" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" className="sync-arrow-down" />
              <path d="M8 22V16" stroke="var(--green)" strokeWidth="1.5" strokeLinecap="round" className="sync-arrow-down" />
            </svg>
          </div>
          <span className="sync-label">iCloud Sync</span>
        </div>

        {/* iOS Phone */}
        <div className="hero-phone">
          <div className="phone-frame">
            <div className="phone-notch" />
            <div className="phone-screen">
              <div className="phone-status-bar">
                <span>9:41</span>
                <span className="phone-status-right">
                  <span className="phone-signal">●●●●○</span>
                  <span className="phone-battery">🔋</span>
                </span>
              </div>
              <div className="phone-nav-bar">
                <span className="phone-back">‹</span>
                <span className="phone-nav-title">🚀 Launch Checklist</span>
                <span className="phone-dots">···</span>
              </div>
              <div className="phone-content">
                <div className="phone-tags">
                  <span className="phone-tag">#launch</span>
                  <span className="phone-tag">#tasks</span>
                </div>
                <div className="phone-md">
                  <span className="phone-h1"># Launch Checklist</span>
                  <br /><br />
                  <span className="phone-h2">## Tasks</span>
                  <br /><br />
                  <span className="phone-task done">&#x2611; <s>Set up iCloud sync</s></span>
                  <br />
                  <span className="phone-task done">&#x2611; <s>Add AI chat panel</s></span>
                  <br />
                  <span className="phone-task">&#x2610; Publish to App Store</span>
                  <br />
                  <span className="phone-task phone-li-hl">&#x2610; Write launch post</span>
                </div>
              </div>
              <div className="phone-toolbar">
                <span>📋</span>
                <span>🤖</span>
                <span className="phone-toolbar-active">✏️</span>
                <span>🔍</span>
                <span>⚙️</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

function Features() {
  return (
    <section className="section" id="features">
      <div className="section-inner">
        <div className="section-header">
          <span className="section-label">Features</span>
          <h2 className="section-title">Everything you need. Nothing you don't.</h2>
          <p className="section-subtitle">
            No plugin ecosystem to configure. No 47-step setup guide. Just open it and write.
          </p>
        </div>
        <div className="features-grid">
          {FEATURES.map((f, i) => (
            <div className="feature-card" key={i}>
              <div className="feature-icon">{f.icon}</div>
              <h3 className="feature-title">{f.title}</h3>
              <p className="feature-desc">{f.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

const SHORTCUTS = [
  { keys: ['⌘', 'Return'], label: 'Toggle task', desc: 'Check/uncheck a todo on the current line' },
  { keys: ['⌃', 'L'], label: 'AI Chat', desc: 'Open the AI chat panel' },
  { keys: ['⇧', '⌘', 'F'], label: 'Full screen', desc: 'Toggle full screen mode' },
  { keys: ['⌘', 'K'], label: 'Search notes', desc: 'Quick search across all your notes' },
  { keys: ['⌃', '↑ ↓'], label: 'Navigate notes', desc: 'Jump to the previous or next note in the list' },
  { keys: ['@'], label: 'Link note', desc: 'Type @ to mention and link to another note, like Obsidian' },
]

function Shortcuts() {
  return (
    <section className="section section-dark" id="shortcuts">
      <div className="section-inner">
        <div className="section-header">
          <span className="section-label">Keyboard Shortcuts</span>
          <h2 className="section-title">Designed for your keyboard</h2>
          <p className="section-subtitle">
            Fast shortcuts for everything you do. Toggle tasks, format text, and navigate - all without leaving the keyboard.
          </p>
        </div>
        <div className="shortcuts-grid">
          {SHORTCUTS.map((s, i) => (
            <div className="shortcut-card" key={i}>
              <div className="shortcut-keys">
                {s.keys.map((k, j) => (
                  <span key={j}>
                    <kbd className="shortcut-key">{k}</kbd>
                    {j < s.keys.length - 1 && <span className="shortcut-plus">+</span>}
                  </span>
                ))}
              </div>
              <div className="shortcut-info">
                <div className="shortcut-label">{s.label}</div>
                <div className="shortcut-desc">{s.desc}</div>
              </div>
            </div>
          ))}
        </div>
        <p className="shortcuts-note">
          iOS keyboard accessory bar provides quick access to headings, tasks, code blocks, bold, and inline code.
        </p>
      </div>
    </section>
  )
}

function AISection() {
  return (
    <section className="section section-dark" id="ai">
      <div className="section-inner">
        <div className="section-header">
          <span className="section-label">AI Integration</span>
          <h2 className="section-title">
            Any model. 11 tools.
            <br />
            <span className="highlight-text">One ridiculously smart editor.</span>
          </h2>
          <p className="section-subtitle">
            Use any model on OpenRouter. Bring your own API key and pick your favorite.
            Claude, Gemini, DeepSeek, Grok - switch anytime.
          </p>
        </div>

        <div className="ai-layout">
          <div className="ai-models">
            <h3 className="ai-section-title">Models</h3>
            <div className="model-list">
              {MODELS.map((m, i) => (
                <div className="model-chip" key={i}>
                  <span className="model-provider">{m.provider}</span>
                  <span className="model-name">{m.name}</span>
                </div>
              ))}
              <div className="model-chip model-custom">
                <span className="model-provider">+</span>
                <span className="model-name">Any OpenRouter model</span>
              </div>
            </div>
          </div>

          <div className="ai-tools">
            <h3 className="ai-section-title">AI Tools</h3>
            <p className="ai-tools-desc">
              The AI doesn't just chat - it <em>acts</em>. With 11 specialized tools,
              it can autonomously manage your entire vault.
            </p>
            <div className="tools-grid">
              {TOOLS.map((t, i) => (
                <div className="tool-card" key={i}>
                  <span className="tool-icon">{t.icon}</span>
                  <div>
                    <div className="tool-name">{t.name}</div>
                    <div className="tool-desc">{t.desc}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

function ClaudeCode() {
  return (
    <section className="section" id="claude-code">
      <div className="section-inner">
        <div className="claude-layout">
          <div className="claude-info">
            <span className="section-label">Claude Code Integration</span>
            <h2 className="section-title">
              Your vault meets
              <br />
              the terminal
            </h2>
            <p className="claude-desc">
              Hashy automatically installs a Claude Code skill into your vault.
              When you use Claude Code in your notes directory, it knows the file format,
              frontmatter structure, and naming conventions.
            </p>
            <p className="claude-desc">
              AI agents can create, read, and organize your notes directly from the command line.
              Your vault becomes a living workspace that both you and your AI tools can use.
            </p>
            <div className="claude-features">
              <div className="claude-feature">
                <span className="cf-check">✓</span>
                Auto-installed skill in <code>.claude/skills/</code>
              </div>
              <div className="claude-feature">
                <span className="cf-check">✓</span>
                Understands ULID filenames & YAML frontmatter
              </div>
              <div className="claude-feature">
                <span className="cf-check">✓</span>
                Works with any Claude Code workflow
              </div>
            </div>
          </div>
          <div className="claude-terminal">
            <div className="terminal-bar">
              <span className="window-dot red" />
              <span className="window-dot yellow" />
              <span className="window-dot green" />
              <span className="terminal-title">~/notes</span>
            </div>
            <div className="terminal-body">
              <div className="term-line">
                <span className="term-prompt">$</span> claude
              </div>
              <div className="term-line dim">
                <span className="term-info">╭</span> Skill loaded: hashy
              </div>
              <div className="term-line dim">
                <span className="term-info">╰</span> Vault: 47 notes, 12 tags
              </div>
              <div className="term-line">
                <span className="term-prompt">{'>'}</span> Create a new note about our API
              </div>
              <div className="term-line dim">&nbsp;&nbsp;design decisions with relevant tags</div>
              <div className="term-line">
                <span className="term-ai">◆</span> Created{' '}
                <span className="term-file">01JQ3K.md</span>
              </div>
              <div className="term-line dim">
                &nbsp;&nbsp;title: "API Design Decisions"
              </div>
              <div className="term-line dim">
                &nbsp;&nbsp;tags: #architecture #api #decisions
              </div>
              <div className="term-line">
                <span className="term-ai">◆</span>{' '}
                <span className="term-success">Note synced to iCloud ☁️</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

function OpenSource() {
  return (
    <section className="section section-dark" id="open-source">
      <div className="section-inner section-center">
        <div className="oss-hash">#</div>
        <h2 className="section-title">Open source. Open files. Open mind.</h2>
        <p className="section-subtitle">
          Hashy is fully open source under MIT. Your notes are plain markdown files -
          no proprietary format, no database, no lock-in.
          Fork it, extend it, make it yours.
        </p>
        <div className="oss-stats">
          <div className="oss-stat">
            <div className="oss-stat-value">Swift 6.2</div>
            <div className="oss-stat-label">Modern Swift</div>
          </div>
          <div className="oss-stat">
            <div className="oss-stat-value">SwiftUI + TCA</div>
            <div className="oss-stat-label">Architecture</div>
          </div>
          <div className="oss-stat">
            <div className="oss-stat-value">.md</div>
            <div className="oss-stat-label">Plain files</div>
          </div>
          <div className="oss-stat">
            <div className="oss-stat-value">MIT</div>
            <div className="oss-stat-label">License</div>
          </div>
        </div>
      </div>
    </section>
  )
}

function Download() {
  return (
    <section className="section" id="download">
      <div className="section-inner section-center">
        <h2 className="section-title">Ready to write?</h2>
        <p className="section-subtitle">
          Download Hashy for free. Bring your OpenRouter key and start writing with AI in seconds.
        </p>
        <div className="download-buttons">
          <a href={LINKS.releases} className="btn btn-xl" target="_blank" rel="noopener">
            <span className="btn-icon">↓</span>
            Download for macOS
          </a>
          <a href={LINKS.appStore} className="btn btn-xl btn-outline" target="_blank" rel="noopener">
            Download for iOS
          </a>
        </div>
        <p className="download-note">
          macOS 14+ &middot; iOS 17+ &middot; Apple Silicon native &middot; Free forever
        </p>
        <a href={LINKS.discord} className="discord-cta" target="_blank" rel="noopener">
          Join the Discord
        </a>
      </div>
    </section>
  )
}

function Footer() {
  return (
    <footer className="footer">
      <div className="footer-inner">
        <div className="footer-brand">
          <img src="/icon.jpg" alt="Hashy" className="footer-icon" />
          <span>Hashy</span>
        </div>
        <div className="footer-links">
          <a href={LINKS.github} target="_blank" rel="noopener">GitHub</a>
          <a href={LINKS.discord} target="_blank" rel="noopener">Discord</a>
          <a href={LINKS.issues} target="_blank" rel="noopener">Issues</a>
          <a href={LINKS.openRouter} target="_blank" rel="noopener">OpenRouter</a>
        </div>
        <div className="footer-copy">
          Built with 🤖 by <a href={LINKS.twitter} target="_blank" rel="noopener">@Jonovono</a>
        </div>
      </div>
    </footer>
  )
}

export default function App() {
  return (
    <>
      <Nav />
      <Hero />
      <Features />
      <Shortcuts />
      <AISection />
      <ClaudeCode />
      <OpenSource />
      <Download />
      <Footer />
    </>
  )
}
