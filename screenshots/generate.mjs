import puppeteer from 'puppeteer'
import { mkdirSync } from 'fs'
import { join, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirname = dirname(fileURLToPath(import.meta.url))

const SIZES = {
  'iphone-6.7': { w: 1284, h: 2778 },  // iPhone 14 Pro Max, 15 Pro Max
  'ipad-13':    { w: 2064, h: 2752 },
}

// ─── SHARED STYLES ───

const FONTS = `@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&family=Inter:wght@400;500;600;700;800;900&display=swap');`

const BASE = `
  * { margin: 0; padding: 0; box-sizing: border-box; }
  ${FONTS}
  :root {
    --green: #b4ff00;
    --green-dim: rgba(180,255,0,0.15);
    --green-glow: rgba(180,255,0,0.25);
    --bg: #0a0a0a;
    --bg2: #141414;
    --bg3: #1a1a1a;
    --border: #262626;
    --text: #f0f0f0;
    --text-mid: #bbb;
    --text-dim: #888;
    --blue: #7aa2f7;
    --purple: #bb9af7;
  }
  body {
    background: var(--bg);
    color: var(--text);
    font-family: 'Inter', -apple-system, sans-serif;
    -webkit-font-smoothing: antialiased;
    overflow: hidden;
  }
  .mono { font-family: 'JetBrains Mono', monospace; }
  .tag { display: inline-block; padding: 4px 14px; border-radius: 8px; background: var(--green-dim); color: var(--green); font-family: 'JetBrains Mono', monospace; }
`

// ─── MARKETING WRAPPER ───

function marketingPhone(headline, sub, appHTML, { w, h }) {
  const f = w / 1260
  // Centered phone with full rounded frame
  const phoneW = Math.round(820 * f)
  const phoneH = Math.round(1780 * f)
  const phoneR = Math.round(56 * f)
  const phoneBorder = Math.round(6 * f)
  const notchW = Math.round(180 * f)
  const notchH = Math.round(34 * f)

  return `<!DOCTYPE html><html><head><style>
    ${BASE}
    .wrapper {
      width: ${w}px; height: ${h}px;
      display: flex; flex-direction: column; align-items: center;
      justify-content: center;
      background: var(--bg);
      position: relative; overflow: hidden;
    }
    .glow {
      position: absolute;
      top: 0; left: 50%; transform: translateX(-50%);
      width: ${Math.round(1000*f)}px; height: ${Math.round(600*f)}px;
      background: radial-gradient(ellipse, var(--green-glow) 0%, transparent 65%);
      pointer-events: none; z-index: 0;
    }
    .text-area {
      position: relative; z-index: 1;
      text-align: center;
      margin-bottom: ${Math.round(40*f)}px;
    }
    .headline {
      font-size: ${Math.round(80*f)}px;
      font-weight: 900;
      line-height: 1.08;
      letter-spacing: -0.03em;
      margin-bottom: ${Math.round(14*f)}px;
    }
    .headline .hl {
      background: linear-gradient(135deg, var(--green), #80ff00);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .sub {
      font-size: ${Math.round(28*f)}px;
      color: var(--text-dim);
      max-width: ${Math.round(600*f)}px;
      margin: 0 auto;
      line-height: 1.5;
    }
    .phone-outer {
      position: relative; z-index: 1;
      width: ${phoneW}px; height: ${phoneH}px;
      border-radius: ${phoneR}px;
      border: ${phoneBorder}px solid #333;
      background: var(--bg2);
      overflow: hidden;
      box-shadow: 0 ${Math.round(10*f)}px ${Math.round(80*f)}px rgba(0,0,0,0.5),
                  0 0 ${Math.round(80*f)}px rgba(180,255,0,0.12);
      flex-shrink: 0;
    }
    .phone-notch {
      position: absolute; top: 0; left: 50%; transform: translateX(-50%);
      width: ${notchW}px; height: ${notchH}px;
      background: #000; border-radius: 0 0 ${Math.round(20*f)}px ${Math.round(20*f)}px;
      z-index: 10;
    }
    .phone-screen {
      width: 100%; height: 100%;
      display: flex; flex-direction: column;
      background: var(--bg);
      font-size: ${Math.round(16*f)}px;
    }
    .status-bar {
      display: flex; justify-content: space-between; align-items: center;
      padding: ${Math.round(8*f)}px ${Math.round(28*f)}px;
      font-size: ${Math.round(18*f)}px; font-weight: 600;
      min-height: ${Math.round(44*f)}px;
    }
    .status-right { display: flex; gap: ${Math.round(8*f)}px; align-items: center; font-size: ${Math.round(13*f)}px; }
  </style></head><body>
    <div class="wrapper">
      <div class="glow"></div>
      <div class="text-area">
        <div class="headline">${headline}</div>
        <div class="sub">${sub}</div>
      </div>
      <div class="phone-outer">
        <div class="phone-notch"></div>
        <div class="phone-screen">
          <div class="status-bar">
            <span>9:41</span>
            <span class="status-right"><span style="letter-spacing:-2px">●●●●○</span> 🔋</span>
          </div>
          ${appHTML}
        </div>
      </div>
    </div>
  </body></html>`
}

function marketingIPad(headline, sub, appHTML, { w, h }) {
  const f = w / 2064
  const padW = Math.round(1980 * f)
  const padH = Math.round(2800 * f)  // very tall - bottom clipped by viewport
  const padR = Math.round(32 * f)
  const padBorder = Math.round(4 * f)

  return `<!DOCTYPE html><html><head><style>
    ${BASE}
    .wrapper {
      width: ${w}px; height: ${h}px;
      display: flex; flex-direction: column; align-items: center;
      background: var(--bg);
      position: relative; overflow: hidden;
    }
    .glow {
      position: absolute; top: -${Math.round(60*f)}px; left: 50%; transform: translateX(-50%);
      width: ${Math.round(1600*f)}px; height: ${Math.round(400*f)}px;
      background: radial-gradient(ellipse, var(--green-glow) 0%, transparent 65%);
      pointer-events: none; z-index: 0;
    }
    .text-area {
      position: relative; z-index: 1;
      text-align: center;
      padding-top: ${Math.round(70*f)}px;
      margin-bottom: ${Math.round(30*f)}px;
    }
    .headline {
      font-size: ${Math.round(88*f)}px;
      font-weight: 900; line-height: 1.08;
      letter-spacing: -0.03em;
      margin-bottom: ${Math.round(12*f)}px;
    }
    .headline .hl {
      background: linear-gradient(135deg, var(--green), #80ff00);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .sub {
      font-size: ${Math.round(30*f)}px;
      color: var(--text-dim);
      max-width: ${Math.round(800*f)}px;
      margin: 0 auto; line-height: 1.5;
    }
    .pad-outer {
      position: relative; z-index: 1;
      width: ${padW}px; height: ${padH}px;
      border-radius: ${padR}px ${padR}px 0 0;
      border: ${padBorder}px solid #333;
      border-bottom: none;
      background: var(--bg2);
      overflow: hidden;
      box-shadow: 0 -${Math.round(10*f)}px ${Math.round(80*f)}px rgba(0,0,0,0.5),
                  0 0 ${Math.round(80*f)}px rgba(180,255,0,0.1);
      flex-shrink: 0;
    }
    .pad-screen {
      width: 100%; height: 100%;
      display: flex; flex-direction: column;
      background: var(--bg);
    }
    .status-bar {
      display: flex; justify-content: space-between; align-items: center;
      padding: ${Math.round(8*f)}px ${Math.round(28*f)}px;
      font-size: ${Math.round(18*f)}px; font-weight: 600;
      min-height: ${Math.round(44*f)}px;
    }
    .status-right { display: flex; gap: ${Math.round(8*f)}px; align-items: center; font-size: ${Math.round(13*f)}px; }
    .app-content { flex: 1; display: flex; overflow: hidden; }
  </style></head><body>
    <div class="wrapper">
      <div class="glow"></div>
      <div class="text-area">
        <div class="headline">${headline}</div>
        <div class="sub">${sub}</div>
      </div>
      <div class="pad-outer">
        <div class="pad-screen">
          <div class="status-bar">
            <span>9:41</span>
            <span class="status-right"><span style="letter-spacing:-2px">●●●●○</span> 🔋</span>
          </div>
          <div class="app-content">${appHTML}</div>
        </div>
      </div>
    </div>
  </body></html>`
}

// ─── APP UI FRAGMENTS ───

function phoneEditorUI(f) {
  return `
  <style>
    .nav { display: flex; align-items: center; justify-content: space-between; padding: ${10*f}px ${18*f}px; border-bottom: 1px solid var(--border); }
    .nav-back { font-size: ${26*f}px; color: var(--green); font-weight: 300; }
    .nav-title { font-size: ${17*f}px; font-weight: 700; }
    .nav-dots { color: var(--green); font-size: ${17*f}px; font-weight: 700; letter-spacing: 2px; }
    .tags-row { display: flex; gap: ${6*f}px; padding: ${10*f}px ${18*f}px; }
    .tag { font-size: ${11*f}px; padding: ${3*f}px ${10*f}px; }
    .editor { flex: 1; padding: ${10*f}px ${18*f}px; font-family: 'JetBrains Mono', monospace; font-size: ${13*f}px; line-height: 1.8; overflow: hidden; }
    .fm { opacity: 0.6; font-size: ${11*f}px; line-height: 1.8; margin-bottom: ${10*f}px; }
    .fm-delim { color: var(--text-dim); } .fm-key { color: var(--blue); } .fm-val { color: var(--green); } .fm-tag { color: var(--purple); }
    .h1 { font-size: ${18*f}px; font-weight: 700; color: var(--text); }
    .h2 { font-size: ${15*f}px; font-weight: 600; color: var(--text); margin-top: ${6*f}px; }
    .txt { color: var(--text-mid); } .hl-line { color: var(--green); }
    .cursor { display: inline-block; width: 2px; height: ${15*f}px; background: var(--green); vertical-align: middle; }
    .toolbar { display: flex; justify-content: space-around; align-items: center; padding: ${12*f}px; border-top: 1px solid var(--border); background: #111; font-size: ${18*f}px; }
    .tb-active { position: relative; }
    .tb-active::after { content: ''; position: absolute; bottom: -${5*f}px; left: 50%; transform: translateX(-50%); width: ${4*f}px; height: ${4*f}px; border-radius: 50%; background: var(--green); }
  </style>
  <div class="nav"><span class="nav-back">‹</span><span class="nav-title">📝 Project Ideas</span><span class="nav-dots">···</span></div>
  <div class="tags-row"><span class="tag">#projects</span><span class="tag">#brainstorm</span></div>
  <div class="editor">
    <div class="fm"><span class="fm-delim">---</span><br><span class="fm-key">title:</span> <span class="fm-val">Project Ideas</span><br><span class="fm-key">tags:</span><br><span class="fm-tag">&nbsp;&nbsp;- projects</span><br><span class="fm-tag">&nbsp;&nbsp;- brainstorm</span><br><span class="fm-key">icon:</span> <span class="fm-val">"📝"</span><br><span class="fm-delim">---</span></div>
    <span class="h1"># Next big thing</span><br><br>
    <span class="txt">Build an AI-powered markdown editor that actually respects your files.</span><br><br>
    <span class="h2">## Requirements</span><br><br>
    <span class="txt">- Native macOS & iOS</span><br>
    <span class="txt">- iCloud sync across all devices</span><br>
    <span class="hl-line">- AI with real tools, not just chat</span><br>
    <span class="txt">- Open source, MIT licensed</span><br>
    <span class="txt">- Claude Code skill integration</span><br>
    <span class="txt">- Plain markdown files, no lock-in</span><br><br>
    <span class="h2">## Architecture</span><br><br>
    <span class="txt">- SwiftUI + TCA for state</span><br>
    <span class="txt">- ULID filenames for ordering</span><br>
    <span class="hl-line">- YAML frontmatter metadata</span><br>
    <span class="txt">- OpenRouter for model access</span><br>
    <span class="txt">- 11 AI tools for vault ops</span><br><span class="cursor"></span><br><br>
    <span class="h2">## Models</span><br><br>
    <span class="txt">- Claude Sonnet 4.5</span><br>
    <span class="txt">- Gemini 2.5 Flash</span><br>
    <span class="txt">- DeepSeek V3</span><br>
    <span class="txt">- Grok, Kimi, MiniMax</span><br>
  </div>
  <div class="toolbar"><span>📋</span><span>🤖</span><span class="tb-active">✏️</span><span>🔍</span><span>⚙️</span></div>`
}

function phoneAIChatUI(f) {
  return `
  <style>
    .nav { display: flex; align-items: center; justify-content: space-between; padding: ${10*f}px ${18*f}px; border-bottom: 1px solid var(--border); }
    .nav-back { font-size: ${26*f}px; color: var(--green); font-weight: 300; }
    .nav-title { font-size: ${17*f}px; font-weight: 700; }
    .nav-dots { color: var(--green); font-size: ${17*f}px; font-weight: 700; letter-spacing: 2px; }
    .chat { flex: 1; padding: ${14*f}px ${18*f}px; display: flex; flex-direction: column; gap: ${14*f}px; overflow: hidden; }
    .msg { padding: ${12*f}px ${14*f}px; border-radius: ${14*f}px; font-size: ${13*f}px; line-height: 1.6; max-width: 88%; }
    .msg-user { background: #1e1e2e; color: var(--text-mid); align-self: flex-end; border-bottom-right-radius: ${3*f}px; }
    .msg-ai { background: #111; border: 1px solid var(--border); color: var(--text-mid); align-self: flex-start; border-bottom-left-radius: ${3*f}px; }
    .msg-label { color: var(--green); font-weight: 600; font-size: ${11*f}px; margin-bottom: ${6*f}px; font-family: 'JetBrains Mono', monospace; }
    .tag { font-size: ${10*f}px; padding: ${2*f}px ${8*f}px; margin: ${2*f}px; }
    .tool { display: flex; align-items: center; gap: ${6*f}px; padding: ${8*f}px ${10*f}px; background: var(--bg); border-radius: ${8*f}px; margin: ${6*f}px 0; font-family: 'JetBrains Mono', monospace; font-size: ${10*f}px; border: 1px solid var(--border); }
    .tool-icon { color: var(--green); }
    .input-bar { display: flex; align-items: center; gap: ${8*f}px; padding: ${12*f}px ${18*f}px; border-top: 1px solid var(--border); background: #111; }
    .input-field { flex: 1; background: var(--bg3); border: 1px solid var(--border); border-radius: ${12*f}px; padding: ${10*f}px ${14*f}px; color: var(--text-dim); font-size: ${12*f}px; }
    .send-btn { width: ${28*f}px; height: ${28*f}px; border-radius: 50%; background: var(--green); display: flex; align-items: center; justify-content: center; font-size: ${14*f}px; color: #000; }
    .toolbar { display: flex; justify-content: space-around; align-items: center; padding: ${12*f}px; border-top: 1px solid var(--border); background: #111; font-size: ${18*f}px; }
    .tb-active { position: relative; }
    .tb-active::after { content: ''; position: absolute; bottom: -${5*f}px; left: 50%; transform: translateX(-50%); width: ${4*f}px; height: ${4*f}px; border-radius: 50%; background: var(--green); }
  </style>
  <div class="nav"><span class="nav-back">‹</span><span class="nav-title">🤖 AI Chat</span><span class="nav-dots">···</span></div>
  <div class="chat">
    <div class="msg msg-user">Organize all my notes by topic and add tags to everything</div>
    <div class="msg msg-ai">
      <div class="msg-label">◆ Assistant</div>
      I'll scan your vault and organize everything.
      <div class="tool"><span class="tool-icon">⚡</span> list_notes</div>
      <div class="tool"><span class="tool-icon">⚡</span> search_notes</div>
    </div>
    <div class="msg msg-ai">
      <div class="msg-label">◆ Assistant</div>
      Done! Organized 23 notes into 5 topics:<br><br>
      <span class="tag">#projects</span><span class="tag">#research</span><span class="tag">#personal</span><span class="tag">#ideas</span><span class="tag">#work</span>
      <br><br>Renamed 4 untitled notes and added emoji icons.
    </div>
    <div class="msg msg-user">Create a summary of my project ideas</div>
    <div class="msg msg-ai">
      <div class="msg-label">◆ Assistant</div>
      <div class="tool"><span class="tool-icon">⚡</span> read_note → 📝 Project Ideas</div>
      <div class="tool"><span class="tool-icon">⚡</span> full_text_search → "project"</div>
      <div class="tool"><span class="tool-icon">⚡</span> create_note → 📋 Project Summary</div>
      Created <span style="color:var(--green)">📋 Project Summary</span> with all 8 project ideas grouped by status and priority.
    </div>
    <div class="msg msg-user">Add a #priority tag to the top 3</div>
    <div class="msg msg-ai">
      <div class="msg-label">◆ Assistant</div>
      <div class="tool"><span class="tool-icon">⚡</span> update_note_metadata × 3</div>
      Done! Added <span class="tag">#priority</span> to your top 3 projects.
    </div>
  </div>
  <div class="input-bar"><div class="input-field">Ask anything...</div><div class="send-btn">↑</div></div>
  <div class="toolbar"><span>📋</span><span class="tb-active">🤖</span><span>✏️</span><span>🔍</span><span>⚙️</span></div>`
}

function phoneNoteListUI(f) {
  const notes = [
    { icon: '📝', title: 'Project Ideas', tags: ['#projects', '#brainstorm'], time: 'Just now' },
    { icon: '🚀', title: 'Launch Checklist', tags: ['#projects', '#launch'], time: '2m ago' },
    { icon: '💡', title: 'AI Prompts Collection', tags: ['#ai', '#reference'], time: '15m ago' },
    { icon: '📖', title: 'Reading List 2025', tags: ['#personal', '#books'], time: '1h ago' },
    { icon: '🔧', title: 'Dev Environment Setup', tags: ['#work', '#dev'], time: '3h ago' },
    { icon: '🎯', title: 'Q1 Goals', tags: ['#work', '#goals'], time: 'Yesterday' },
    { icon: '📋', title: 'Meeting Notes', tags: ['#work', '#meetings'], time: 'Yesterday' },
    { icon: '🧪', title: 'API Design Decisions', tags: ['#architecture'], time: '2d ago' },
    { icon: '🌍', title: 'Travel Planning', tags: ['#personal', '#travel'], time: '3d ago' },
    { icon: '🎨', title: 'Design System Notes', tags: ['#design'], time: '5d ago' },
    { icon: '💰', title: 'Budget Tracker', tags: ['#personal'], time: '1w ago' },
    { icon: '🏋️', title: 'Workout Log', tags: ['#health', '#daily'], time: '1w ago' },
    { icon: '🧠', title: 'Learning Rust', tags: ['#dev', '#learning'], time: '2w ago' },
    { icon: '🎵', title: 'Playlist Ideas', tags: ['#personal', '#music'], time: '2w ago' },
    { icon: '📊', title: 'Analytics Dashboard', tags: ['#work', '#data'], time: '3w ago' },
    { icon: '🔑', title: 'Auth Flow Design', tags: ['#architecture'], time: '1mo ago' },
  ]
  return `
  <style>
    .header { padding: ${16*f}px ${18*f}px ${10*f}px; }
    .header-row { display: flex; align-items: center; gap: ${8*f}px; margin-bottom: ${10*f}px; }
    .header-title { font-size: ${24*f}px; font-weight: 800; }
    .sync-badge { display: inline-flex; align-items: center; gap: ${4*f}px; padding: ${3*f}px ${10*f}px; border-radius: 100px; background: var(--green-dim); color: var(--green); font-size: ${10*f}px; font-family: 'JetBrains Mono', monospace; }
    .sync-dot { width: ${5*f}px; height: ${5*f}px; border-radius: 50%; background: var(--green); }
    .search { display: flex; align-items: center; gap: ${6*f}px; padding: ${8*f}px ${12*f}px; background: var(--bg3); border-radius: ${8*f}px; font-size: ${13*f}px; color: var(--text-dim); }
    .note-list { flex: 1; overflow: hidden; }
    .note { display: flex; align-items: flex-start; gap: ${10*f}px; padding: ${10*f}px ${18*f}px; border-bottom: 1px solid #1a1a1a; }
    .note-active { background: var(--green-dim); }
    .note-icon { font-size: ${17*f}px; margin-top: ${2*f}px; }
    .note-body { flex: 1; }
    .note-title { font-size: ${14*f}px; font-weight: 600; margin-bottom: ${3*f}px; }
    .note-meta { display: flex; align-items: center; gap: ${4*f}px; flex-wrap: wrap; }
    .tag { font-size: ${9*f}px; padding: ${2*f}px ${6*f}px; border-radius: 4px; }
    .note-time { font-size: ${10*f}px; color: var(--text-dim); margin-left: auto; white-space: nowrap; }
    .toolbar { display: flex; justify-content: space-around; align-items: center; padding: ${12*f}px; border-top: 1px solid var(--border); background: #111; font-size: ${18*f}px; }
    .tb-active { position: relative; }
    .tb-active::after { content: ''; position: absolute; bottom: -${5*f}px; left: 50%; transform: translateX(-50%); width: ${4*f}px; height: ${4*f}px; border-radius: 50%; background: var(--green); }
  </style>
  <div class="header">
    <div class="header-row"><span class="header-title">Hashy</span><span class="sync-badge"><span class="sync-dot"></span> Synced</span></div>
    <div class="search">🔍 Search notes...</div>
  </div>
  <div class="note-list">
    ${notes.map((n,i) => `<div class="note ${i===0?'note-active':''}"><span class="note-icon">${n.icon}</span><div class="note-body"><div class="note-title">${n.title}</div><div class="note-meta">${n.tags.map(t=>`<span class="tag">${t}</span>`).join('')}<span class="note-time">${n.time}</span></div></div></div>`).join('')}
  </div>
  <div class="toolbar"><span class="tb-active">📋</span><span>🤖</span><span>✏️</span><span>🔍</span><span>⚙️</span></div>`
}

// ─── IPAD UI FRAGMENTS ───

function ipadFullUI(f) {
  const notes = ['📝 Project Ideas','🚀 Launch Checklist','💡 AI Prompts','📖 Reading List','🔧 Dev Setup','🎯 Q1 Goals','📋 Meeting Notes','🧪 API Decisions','🌍 Travel Plans','🎨 Design System','💰 Budget','🏋️ Workout Log']
  return `
  <style>
    .sidebar { width: ${280*f}px; border-right: 1px solid var(--border); background: var(--bg2); display: flex; flex-direction: column; }
    .sb-header { padding: ${20*f}px ${18*f}px ${12*f}px; }
    .sb-title { font-size: ${24*f}px; font-weight: 800; margin-bottom: ${10*f}px; }
    .sb-search { display: flex; align-items: center; gap: ${6*f}px; padding: ${8*f}px ${12*f}px; background: var(--bg); border-radius: ${8*f}px; font-size: ${14*f}px; color: var(--text-dim); }
    .sb-notes { flex: 1; padding: ${4*f}px ${8*f}px; overflow: hidden; }
    .sb-note { display: flex; align-items: center; gap: ${8*f}px; padding: ${8*f}px ${10*f}px; border-radius: ${8*f}px; font-size: ${15*f}px; color: var(--text-mid); margin-bottom: 1px; }
    .sb-note.active { background: var(--green-dim); color: var(--green); }
    .sync-badge { display: inline-flex; align-items: center; gap: ${4*f}px; padding: ${3*f}px ${8*f}px; border-radius: 100px; background: var(--green-dim); color: var(--green); font-size: ${11*f}px; font-family: 'JetBrains Mono', monospace; margin-left: ${8*f}px; }
    .sync-dot { width: ${5*f}px; height: ${5*f}px; border-radius: 50%; background: var(--green); }

    .editor-area { flex: 1; display: flex; flex-direction: column; }
    .ed-nav { display: flex; align-items: center; padding: ${12*f}px ${24*f}px; border-bottom: 1px solid var(--border); font-size: ${18*f}px; font-weight: 700; }
    .ed-tags { display: flex; gap: ${6*f}px; padding: ${10*f}px ${24*f}px; }
    .tag { font-size: ${12*f}px; padding: ${3*f}px ${10*f}px; }
    .ed-body { flex: 1; padding: ${12*f}px ${24*f}px; font-family: 'JetBrains Mono', monospace; font-size: ${15*f}px; line-height: 1.9; overflow: hidden; }
    .fm { opacity: 0.6; font-size: ${13*f}px; line-height: 1.8; margin-bottom: ${12*f}px; }
    .fm-delim { color: var(--text-dim); } .fm-key { color: var(--blue); } .fm-val { color: var(--green); } .fm-tag { color: var(--purple); }
    .h1 { font-size: ${20*f}px; font-weight: 700; } .h2 { font-size: ${17*f}px; font-weight: 600; }
    .txt { color: var(--text-mid); } .hl-line { color: var(--green); }
    .cursor { display: inline-block; width: 2px; height: ${17*f}px; background: var(--green); vertical-align: middle; }

    .chat-panel { width: ${340*f}px; border-left: 1px solid var(--border); display: flex; flex-direction: column; }
    .ch-header { display: flex; align-items: center; gap: ${8*f}px; padding: ${14*f}px ${18*f}px; border-bottom: 1px solid var(--border); font-size: ${16*f}px; font-weight: 700; }
    .ch-msgs { flex: 1; padding: ${14*f}px; display: flex; flex-direction: column; gap: ${12*f}px; overflow: hidden; }
    .msg { padding: ${12*f}px ${14*f}px; border-radius: ${14*f}px; font-size: ${13*f}px; line-height: 1.6; }
    .msg-user { background: #1e1e2e; color: var(--text-mid); align-self: flex-end; max-width: 85%; border-bottom-right-radius: ${3*f}px; }
    .msg-ai { background: var(--bg2); border: 1px solid var(--border); color: var(--text-mid); max-width: 90%; border-bottom-left-radius: ${3*f}px; }
    .msg-label { color: var(--green); font-weight: 600; font-size: ${11*f}px; margin-bottom: ${4*f}px; font-family: 'JetBrains Mono', monospace; }
    .ch-input { display: flex; gap: ${8*f}px; padding: ${12*f}px ${14*f}px; border-top: 1px solid var(--border); }
    .ch-field { flex: 1; background: var(--bg3); border: 1px solid var(--border); border-radius: ${10*f}px; padding: ${8*f}px ${12*f}px; color: var(--text-dim); font-size: ${13*f}px; }
    .ch-send { width: ${28*f}px; height: ${28*f}px; border-radius: 50%; background: var(--green); display: flex; align-items: center; justify-content: center; font-size: ${14*f}px; color: #000; }
  </style>
  <div class="sidebar">
    <div class="sb-header">
      <div style="display:flex;align-items:center"><span class="sb-title">Hashy</span><span class="sync-badge"><span class="sync-dot"></span> Synced</span></div>
      <div class="sb-search">🔍 Search notes...</div>
    </div>
    <div class="sb-notes">
      ${notes.map((n,i) => `<div class="sb-note ${i===0?'active':''}">${n}</div>`).join('')}
    </div>
  </div>
  <div class="editor-area">
    <div class="ed-nav">📝 Project Ideas</div>
    <div class="ed-tags"><span class="tag">#projects</span><span class="tag">#brainstorm</span></div>
    <div class="ed-body">
      <div class="fm"><span class="fm-delim">---</span><br><span class="fm-key">title:</span> <span class="fm-val">Project Ideas</span><br><span class="fm-key">tags:</span><br><span class="fm-tag">&nbsp;&nbsp;- projects</span><br><span class="fm-tag">&nbsp;&nbsp;- brainstorm</span><br><span class="fm-key">icon:</span> <span class="fm-val">"📝"</span><br><span class="fm-delim">---</span></div>
      <span class="h1"># Next big thing</span><br><br>
      <span class="txt">Build an AI-powered markdown editor that actually respects your files.</span><br><br>
      <span class="h2">## Requirements</span><br><br>
      <span class="txt">- Native macOS & iOS</span><br><span class="txt">- iCloud sync</span><br><span class="hl-line">- AI with real tools, not just chat</span><br><span class="txt">- Open source</span><br><span class="cursor"></span>
    </div>
  </div>
  <div class="chat-panel">
    <div class="ch-header">🤖 AI Chat</div>
    <div class="ch-msgs">
      <div class="msg msg-user">Organize my notes by topic</div>
      <div class="msg msg-ai"><div class="msg-label">◆ Assistant</div>Done! Tagged 12 notes across 4 topics:<br><br><span class="tag">#projects</span> <span class="tag">#research</span> <span class="tag">#personal</span> <span class="tag">#ideas</span></div>
      <div class="msg msg-user">Create a project summary</div>
      <div class="msg msg-ai"><div class="msg-label">◆ Assistant</div>Created <span style="color:var(--green)">📋 Project Summary</span> with all 8 project ideas.</div>
    </div>
    <div class="ch-input"><div class="ch-field">Ask anything...</div><div class="ch-send">↑</div></div>
  </div>`
}

function ipadAIChatUI(f) {
  const notes = ['📝 Project Ideas','🚀 Launch Checklist','💡 AI Prompts','📖 Reading List','🔧 Dev Setup','🎯 Q1 Goals','📋 Meeting Notes','🧪 API Decisions','🌍 Travel Plans','🎨 Design System','💰 Budget','🏋️ Workout Log']
  return `
  <style>
    .sidebar { width: ${280*f}px; border-right: 1px solid var(--border); background: var(--bg2); display: flex; flex-direction: column; }
    .sb-header { padding: ${20*f}px ${18*f}px ${12*f}px; }
    .sb-title { font-size: ${24*f}px; font-weight: 800; }
    .sb-search { display: flex; align-items: center; gap: ${6*f}px; padding: ${8*f}px ${12*f}px; background: var(--bg); border-radius: ${8*f}px; font-size: ${14*f}px; color: var(--text-dim); margin-top: ${10*f}px; }
    .sb-notes { flex: 1; padding: ${4*f}px ${8*f}px; overflow: hidden; }
    .sb-note { display: flex; align-items: center; gap: ${8*f}px; padding: ${8*f}px ${10*f}px; border-radius: ${8*f}px; font-size: ${15*f}px; color: var(--text-mid); margin-bottom: 1px; }
    .sb-note.active { background: var(--green-dim); color: var(--green); }

    .chat-area { flex: 1; display: flex; flex-direction: column; }
    .ch-header { display: flex; align-items: center; gap: ${8*f}px; padding: ${14*f}px ${28*f}px; border-bottom: 1px solid var(--border); font-size: ${18*f}px; font-weight: 700; }
    .ch-mention { font-weight: 400; color: var(--text-dim); font-size: ${15*f}px; }
    .ch-msgs { flex: 1; padding: ${20*f}px ${28*f}px; display: flex; flex-direction: column; gap: ${16*f}px; overflow: hidden; }
    .msg { padding: ${16*f}px ${20*f}px; border-radius: ${16*f}px; font-size: ${16*f}px; line-height: 1.65; max-width: 75%; }
    .msg-user { background: #1e1e2e; color: var(--text-mid); align-self: flex-end; border-bottom-right-radius: ${4*f}px; }
    .msg-ai { background: var(--bg2); border: 1px solid var(--border); color: var(--text-mid); border-bottom-left-radius: ${4*f}px; }
    .msg-label { color: var(--green); font-weight: 600; font-size: ${13*f}px; margin-bottom: ${8*f}px; font-family: 'JetBrains Mono', monospace; }
    .tag { font-size: ${13*f}px; padding: ${4*f}px ${10*f}px; margin: ${3*f}px; }
    .tool { display: flex; align-items: center; gap: ${8*f}px; padding: ${10*f}px ${14*f}px; background: var(--bg); border-radius: ${8*f}px; margin: ${8*f}px 0; font-family: 'JetBrains Mono', monospace; font-size: ${13*f}px; border: 1px solid var(--border); }
    .tool-icon { color: var(--green); }
    .ch-input { display: flex; gap: ${10*f}px; padding: ${16*f}px ${28*f}px; border-top: 1px solid var(--border); }
    .ch-field { flex: 1; background: var(--bg3); border: 1px solid var(--border); border-radius: ${12*f}px; padding: ${12*f}px ${16*f}px; color: var(--text-dim); font-size: ${16*f}px; }
    .ch-send { width: ${36*f}px; height: ${36*f}px; border-radius: 50%; background: var(--green); display: flex; align-items: center; justify-content: center; font-size: ${16*f}px; color: #000; }
  </style>
  <div class="sidebar">
    <div class="sb-header"><div class="sb-title">Hashy</div><div class="sb-search">🔍 Search notes...</div></div>
    <div class="sb-notes">${notes.map((n,i) => `<div class="sb-note ${i===0?'active':''}">${n}</div>`).join('')}</div>
  </div>
  <div class="chat-area">
    <div class="ch-header">🤖 AI Chat <span class="ch-mention">&middot; @Project Ideas</span></div>
    <div class="ch-msgs">
      <div class="msg msg-user">Organize all my notes by topic and add tags to everything</div>
      <div class="msg msg-ai">
        <div class="msg-label">◆ Assistant</div>
        I'll scan your vault and organize everything.
        <div class="tool"><span class="tool-icon">⚡</span> list_notes → 23 notes found</div>
        <div class="tool"><span class="tool-icon">⚡</span> full_text_search → scanning content</div>
      </div>
      <div class="msg msg-ai">
        <div class="msg-label">◆ Assistant</div>
        Done! Organized 23 notes into 5 topics:<br><br>
        <span class="tag">#projects</span><span class="tag">#research</span><span class="tag">#personal</span><span class="tag">#ideas</span><span class="tag">#work</span>
        <br><br>Renamed 4 untitled notes and added emoji icons.
      </div>
      <div class="msg msg-user">Create a summary note of all my project ideas</div>
      <div class="msg msg-ai">
        <div class="msg-label">◆ Assistant</div>
        <div class="tool"><span class="tool-icon">⚡</span> create_note → 📋 Project Summary</div>
        Created <span style="color:var(--green)">📋 Project Summary</span> with all 8 project ideas, grouped by status and priority.
      </div>
    </div>
    <div class="ch-input"><div class="ch-field">Ask anything about your notes...</div><div class="ch-send">↑</div></div>
  </div>`
}

// ─── SCREEN DEFINITIONS ───

const PHONE_SCREENS = [
  {
    name: 'editor',
    headline: 'Write in <span class="hl">markdown</span>.<br>Stay in flow.',
    sub: 'Native editor with syntax highlighting, frontmatter, and YAML metadata.',
    ui: phoneEditorUI,
  },
  {
    name: 'ai-chat',
    headline: 'Create, update &<br><span class="hl">manage</span> your notes.',
    sub: '11 AI tools that organize, search, and edit your entire vault.',
    ui: phoneAIChatUI,
  },
  {
    name: 'note-list',
    headline: 'Your notes.<br><span class="hl">Everywhere.</span>',
    sub: 'iCloud sync keeps everything in sync across Mac, iPhone, and iPad.',
    ui: phoneNoteListUI,
  },
]

const IPAD_SCREENS = [
  {
    name: 'full-layout',
    headline: 'Notes. Editor. AI.<br><span class="hl">All at once.</span>',
    sub: 'Full three-panel layout with sidebar, markdown editor, and AI chat.',
    ui: ipadFullUI,
  },
  {
    name: 'ai-chat',
    headline: 'Create, update &<br><span class="hl">manage</span> your notes.',
    sub: '11 AI tools that organize, search, and edit your entire vault.',
    ui: ipadAIChatUI,
  },
]

// ─── GENERATE ───

async function main() {
  const outDir = join(__dirname, 'output')
  mkdirSync(outDir, { recursive: true })

  const browser = await puppeteer.launch({ headless: true })

  for (const [sizeKey, size] of Object.entries(SIZES)) {
    const isPhone = sizeKey.startsWith('iphone')
    const screens = isPhone ? PHONE_SCREENS : IPAD_SCREENS
    const dir = join(outDir, sizeKey)
    mkdirSync(dir, { recursive: true })

    for (const screen of screens) {
      // UI scale factor: based on device size inside the frame
      const f = isPhone ? (size.w * 0.65) / 540 : (size.w * 0.96) / 900
      const appHTML = screen.ui(f)
      const html = isPhone
        ? marketingPhone(screen.headline, screen.sub, appHTML, size)
        : marketingIPad(screen.headline, screen.sub, appHTML, size)
      const page = await browser.newPage()
      await page.setViewport({ width: size.w, height: size.h, deviceScaleFactor: 1 })
      await page.setContent(html, { waitUntil: 'networkidle0' })
      await new Promise(r => setTimeout(r, 2000))
      const path = join(dir, `${screen.name}.png`)
      await page.screenshot({ path, type: 'png' })
      await page.close()
      console.log(`✓ ${sizeKey}/${screen.name}.png (${size.w}x${size.h})`)
    }
  }

  await browser.close()
  console.log('\nDone! Screenshots saved to screenshots/output/')
}

main().catch(console.error)
