#!/bin/bash
# Hashy vault search utilities
# Source this file, then call the functions from within a vault directory.
# All commands use only macOS-standard tools (grep, awk, sed, sort, ls, python3).

# Generate a ULID filename for a new note (e.g. 01J5A3B9KP7QXYZ12345ABCDE.md).
#   hashy_ulid
hashy_ulid() {
  python3 -c "
import time, random
t = int(time.time() * 1000)
cs = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'
e = ''.join(cs[(t >> (45 - 5 * i)) & 31] for i in range(10))
r = ''.join(cs[random.randint(0, 31)] for _ in range(16))
print(e + r + '.md')
"
}

# Get the title from a note's YAML frontmatter.
#   _hashy_title "01ABC.md"  →  "My Note Title"
_hashy_title() {
  awk '/^---/{n++; next} n==1 && /^title:/{sub(/^title:[[:space:]]*/,""); print; exit}' "$1"
}

# List notes with titles, most recently modified first.
#   hashy_ls
hashy_ls() {
  ls -t *.md 2>/dev/null | while IFS= read -r f; do
    printf '%s\t%s\n' "$f" "$(_hashy_title "$f")"
  done
}

# Search notes by tag name (exact match inside frontmatter tags array).
#   hashy_tag "kubernetes"
hashy_tag() {
  local tag="${1:?usage: hashy_tag TAG}"
  grep -rl "^  - ${tag}$" *.md 2>/dev/null | while IFS= read -r f; do
    printf '%s\t%s\n' "$f" "$(_hashy_title "$f")"
  done
}

# List all tags across the vault with occurrence counts.
#   hashy_tags
hashy_tags() {
  awk '
    /^---/{ n++; next }
    n==1 && /^  - /{ gsub(/^  - /,""); tags[$0]++ }
    n==2{ n=0 }
    END{ for (t in tags) printf "%4d\t%s\n", tags[t], t }
  ' *.md 2>/dev/null | sort -rn
}

# List all tasks (open and completed) across all notes, prefixed with filename and title.
#   hashy_tasks
hashy_tasks() {
  for f in *.md; do
    [ -f "$f" ] || continue
    local t; t=$(_hashy_title "$f")
    grep -n '\- \[[ x]\]' "$f" | sed "s|^|$f ($t): |"
  done
}

# List open tasks (- [ ]) across all notes, prefixed with filename and title.
#   hashy_todo
hashy_todo() {
  for f in *.md; do
    [ -f "$f" ] || continue
    local t; t=$(_hashy_title "$f")
    grep -n '\- \[ \]' "$f" | sed "s|^|$f ($t): |"
  done
}

# List completed tasks (- [x]) across all notes, prefixed with filename and title.
#   hashy_done
hashy_done() {
  for f in *.md; do
    [ -f "$f" ] || continue
    local t; t=$(_hashy_title "$f")
    grep -n '\- \[x\]' "$f" | sed "s|^|$f ($t): |"
  done
}

# Full-text search across note bodies (skips YAML frontmatter, case-insensitive).
#   hashy_search "deployment strategy"
hashy_search() {
  local query="${1:?usage: hashy_search QUERY}"
  awk -v q="$query" '
    BEGIN{ IGNORECASE=1 }
    /^---/{ fm++; next }
    fm%2==1{ next }
    tolower($0) ~ tolower(q){ print FILENAME":"NR": "$0 }
  ' *.md
}

# Search notes by title pattern (case-insensitive).
#   hashy_find "meeting"
hashy_find() {
  local pattern="${1:?usage: hashy_find PATTERN}"
  awk -v p="$pattern" '
    BEGIN{ IGNORECASE=1 }
    /^---/{ n++; next }
    n==1 && /^title:/{ sub(/^title:[[:space:]]*/,""); if (tolower($0) ~ tolower(p)) print FILENAME"\t"$0; n++ }
  ' *.md
}

# ---------------------------------------------------------------------------
# Link & image utilities
# ---------------------------------------------------------------------------

# Extract all markdown links [text](url) and bare URLs from all notes.
# Output: filename (title) → link text → url
#   hashy_links
hashy_links() {
  for f in *.md; do
    [ -f "$f" ] || continue
    local t; t=$(_hashy_title "$f")
    # Markdown links (skip images which start with !)
    sed -n '/^---$/,/^---$/!p' "$f" | grep -on '[^!]\[([^]]*)\]([^)]*)' | \
      sed -E "s|^([0-9]+):.*\[([^]]*)\]\(([^)]*)\)|$f ($t):\1: [\2](\3)|"
    # Bare URLs
    sed -n '/^---$/,/^---$/!p' "$f" | grep -on 'https\?://[^[:space:]>)\"'"'"']*' | \
      sed "s|^|$f ($t):|"
  done
}

# Extract all image references ![alt](path) from all notes.
# Output: filename (title):line: ![alt](path)
#   hashy_images
hashy_images() {
  for f in *.md; do
    [ -f "$f" ] || continue
    local t; t=$(_hashy_title "$f")
    grep -n '!\[[^]]*\]([^)]*)' "$f" | sed "s|^|$f ($t): |"
  done
}

# ---------------------------------------------------------------------------
# Wiki-link graph utilities
# ---------------------------------------------------------------------------

# Extract all wiki-links from all notes.
# Output: source_file (source_title) → target_id (target_title)
#   hashy_wikilinks
hashy_wikilinks() {
  for f in *.md; do
    [ -f "$f" ] || continue
    local src_title; src_title=$(_hashy_title "$f")
    grep -o '\[\[[^]]*\]\]' "$f" | while IFS= read -r link; do
      # Parse [[id|name]] or [[id]]
      local target_id; target_id=$(echo "$link" | sed -E 's/\[\[([^]|]*).*/\1/')
      local target_file="${target_id}.md"
      local target_title=""
      if [ -f "$target_file" ]; then
        target_title=$(_hashy_title "$target_file")
      fi
      printf '%s (%s) → %s (%s)\n' "$f" "$src_title" "$target_id" "${target_title:-<missing>}"
    done
  done
}

# Find all notes that link TO a specific note via wiki-links.
# Argument: note ID (filename without .md) or full filename.
#   hashy_backlinks "01J5A3B9KP7QXYZ12345ABCDE"
#   hashy_backlinks "01J5A3B9KP7QXYZ12345ABCDE.md"
hashy_backlinks() {
  local target="${1:?usage: hashy_backlinks NOTE_ID}"
  target="${target%.md}"  # strip .md if provided
  grep -rl "\[\[${target}" *.md 2>/dev/null | while IFS= read -r f; do
    printf '%s\t%s\n' "$f" "$(_hashy_title "$f")"
  done
}

# Build a full graph of wiki-link connections (adjacency list).
# Output: one line per note showing outgoing connections.
#   hashy_graph
hashy_graph() {
  for f in *.md; do
    [ -f "$f" ] || continue
    local src_title; src_title=$(_hashy_title "$f")
    local targets; targets=$(grep -o '\[\[[^]|]*' "$f" 2>/dev/null | sed 's/\[\[//' | sort -u | tr '\n' ', ' | sed 's/,$//')
    if [ -n "$targets" ]; then
      printf '%s (%s) → %s\n' "$f" "$src_title" "$targets"
    else
      printf '%s (%s) → (no links)\n' "$f" "$src_title"
    fi
  done
}

# Find orphan notes — notes that no other note links to.
#   hashy_orphans
hashy_orphans() {
  # Collect all note IDs that are wiki-link targets
  local linked; linked=$(grep -oh '\[\[[^]|]*' *.md 2>/dev/null | sed 's/\[\[//' | sort -u)
  for f in *.md; do
    [ -f "$f" ] || continue
    local id="${f%.md}"
    if ! echo "$linked" | grep -qx "$id"; then
      printf '%s\t%s\n' "$f" "$(_hashy_title "$f")"
    fi
  done
}

# Find broken wiki-links — links pointing to notes that don't exist.
#   hashy_broken
hashy_broken() {
  for f in *.md; do
    [ -f "$f" ] || continue
    local src_title; src_title=$(_hashy_title "$f")
    grep -o '\[\[[^]|]*' "$f" 2>/dev/null | sed 's/\[\[//' | while IFS= read -r target_id; do
      if [ ! -f "${target_id}.md" ]; then
        printf '%s (%s) → %s (NOT FOUND)\n' "$f" "$src_title" "$target_id"
      fi
    done
  done
}

# ---------------------------------------------------------------------------
# Frontmatter quality / incomplete notes
# ---------------------------------------------------------------------------

# Find notes missing a title in frontmatter.
#   hashy_notitle
hashy_notitle() {
  for f in *.md; do
    [ -f "$f" ] || continue
    local t; t=$(_hashy_title "$f")
    if [ -z "$t" ]; then
      printf '%s\n' "$f"
    fi
  done
}

# Find notes missing tags in frontmatter.
#   hashy_notags
hashy_notags() {
  for f in *.md; do
    [ -f "$f" ] || continue
    local has_tags; has_tags=$(awk '/^---/{n++; next} n==1 && /^tags:/{print "yes"; exit} n==2{exit}' "$f")
    if [ -z "$has_tags" ]; then
      printf '%s\t%s\n' "$f" "$(_hashy_title "$f")"
    fi
  done
}

# Find notes missing an icon in frontmatter.
#   hashy_noicon
hashy_noicon() {
  for f in *.md; do
    [ -f "$f" ] || continue
    local has_icon; has_icon=$(awk '/^---/{n++; next} n==1 && /^icon:/{print "yes"; exit} n==2{exit}' "$f")
    if [ -z "$has_icon" ]; then
      printf '%s\t%s\n' "$f" "$(_hashy_title "$f")"
    fi
  done
}

# Find notes with incomplete frontmatter (missing any of: title, tags, icon).
# Shows which fields are missing for each note.
#   hashy_incomplete
hashy_incomplete() {
  for f in *.md; do
    [ -f "$f" ] || continue
    local missing=""
    local t; t=$(_hashy_title "$f")
    [ -z "$t" ] && missing="${missing} title"
    local has_tags; has_tags=$(awk '/^---/{n++; next} n==1 && /^tags:/{print "yes"; exit} n==2{exit}' "$f")
    [ -z "$has_tags" ] && missing="${missing} tags"
    local has_icon; has_icon=$(awk '/^---/{n++; next} n==1 && /^icon:/{print "yes"; exit} n==2{exit}' "$f")
    [ -z "$has_icon" ] && missing="${missing} icon"
    if [ -n "$missing" ]; then
      printf '%s\t%s\tmissing:%s\n' "$f" "${t:-<untitled>}" "$missing"
    fi
  done
}
