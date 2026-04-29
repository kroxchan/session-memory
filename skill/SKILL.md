---
name: session-memory
description: Project-scoped persistent memory with hierarchical indexing. Use every turn — read INDEX.md first (mandatory, low-cost), drill down to detail files only when relevant. Auto-capture requirements/decisions mentioned by user, summarize long sessions, survive /clear and new windows. Works with Cursor, Codex, Claude Code, and any agentic coding tool.
---

# Session Memory

A lightweight project-scoped memory system that prevents context loss in long conversations and across windows. Built on hierarchical indexing (INDEX → CORE → DETAIL) inspired by RAPTOR (ICLR 2024) and HippoRAG (NeurIPS 2024), adapted for single-user IDE use with pure Markdown + filesystem (no embeddings).

## When to activate

**Always active.** This skill runs every turn. It is not optional.

## Storage layout

```
$MEMORY_ROOT/sessions/
├── _global/                        # cross-project user-level
│   ├── INDEX.md                    # L1 (≤30 lines)
│   ├── CORE.md                     # L2 (≤60 lines)
│   └── facts/                      # L3
└── projects/
    └── <basename>@<md5-8>/          # one folder per project
        ├── INDEX.md                 # L1 (≤50 lines, mandatory read every turn)
        ├── CORE.md                  # L2 (≤200 lines, always in context)
        ├── requirements.md          # L3: explicit user requirements
        ├── decisions.md             # L3: technical decisions
        ├── facts/                   # L3: topic-specific knowledge
        │   └── *.md
        └── sessions/                # L3: compressed conversation summaries
            └── YYYY-MM-DD-<topic>.md
```

`$MEMORY_ROOT` defaults to `~/.cursor/session-memory/memory`. Can be overridden with the `MEMORY_ROOT` env var to fit any tool's directory structure.

## Every turn — mandatory protocol

On every user message, **in this exact order**:

1. **Resolve project key** — run `scripts/sm-project-key.sh` with current workspace path
2. **Read indexes** (mandatory, low-cost):
   - `$MEMORY_ROOT/sessions/_global/INDEX.md`
   - `$MEMORY_ROOT/sessions/projects/<key>/INDEX.md`
3. **CORE is already in context** (loaded at session start) — keep honoring it
4. **Decide if detail drill-down needed**:
   - Trivial task (typo fix, file read, one-off question) → skip detail reads
   - Task touching project conventions/decisions → `Read` the specific L3 file pointed to by INDEX
5. **Proceed with the task**

**Cost budget**: two INDEX reads ≈ ≤400 tokens per turn. Detail reads only when relevant (~30% of turns).

## Session start — bootstrap

First turn of a new conversation:

1. Run `scripts/sm-bootstrap.sh <workspace_path>` — ensures project memory dirs exist, prints CORE.md + INDEX.md content
2. Inject the printed content at the top of reasoning context (primacy-bias zone per Liu et al. 2023)

If the project is new (no `projects/<key>/` folder), `sm-bootstrap.sh` creates it from templates and prints a minimal starter CORE.

## Memory capture — when to write

Write to memory **immediately** (not batched, not at end-of-turn) when user input matches:

| Signal | Target file | Example |
|--------|------------|---------|
| Explicit instruction ("记住 X", "remember X", "以后都 Y", "from now on Y") | `requirements.md` | "All handlers must log traceID" |
| Technical decision ("we'll use X instead of Y", "决定用 X") | `decisions.md` | "Use Redis, not Memcached, for session store" |
| Project convention stated by user | `facts/<topic>.md` | API route pattern, naming scheme |
| Long discussion that concluded something | `sessions/<date>-<topic>.md` | Compress at 50% context |
| User explicitly invokes `/remember <x>` | `CORE.md` (append) | — |

**Do not write** for:
- Ephemeral context (today's test run, scratch values)
- User's own code that's obviously captured in the codebase
- Duplicate info already in memory (check INDEX first)
- Credentials, tokens, PII — **never write secrets**

## How to write — atomic with index update

Always use `scripts/sm-write.sh` which:
1. Appends entry to target L3 file with timestamp + optional `★ CURRENT` marker
2. Atomically updates INDEX.md entry (create or replace line)
3. Uses tmp file + rename to prevent partial writes

```bash
# Multi-line body — use stdin (recommended)
echo "All HTTP handlers must log traceID to structured log." \
  | bash scripts/sm-write.sh \
      --project-key 7verse-ug@a3f2e1b9 \
      --file requirements.md \
      --title "All handlers log traceID" \
      --summary "每个 HTTP handler 入口记录 traceID" \
      --body-stdin

# Single-line body — use --body
bash scripts/sm-write.sh \
  --project-key 7verse-ug@a3f2e1b9 \
  --file decisions.md \
  --title "Use Redis not Memcached" \
  --summary "Session 存储选型 Redis" \
  --body "We use Redis instead of Memcached for session store." \
  --current
```

## Memory conflict resolution

When new decision contradicts old:
- **Append** new entry with `★ CURRENT` marker and timestamp
- **Strike** old entry with `~~...~~` + note reason: `<!-- superseded by 2026-04-23: 需求变更 -->`
- **Never delete** — audit trail matters

## Core overflow

If `CORE.md` > 200 lines after write:
1. Identify topic to evict (least recently referenced via INDEX lookup counts)
2. Move that section to `facts/<topic>.md`
3. Replace in CORE with a one-line pointer + add INDEX entry

## Lost-in-Middle mitigation

Following Liu et al. 2023:

- **Primacy zone (conversation start)**: CORE.md injected here — highest retention
- **Recency zone (latest turns)**: items tagged `[STICKY]` in CORE re-emitted every ~10 turns at end of Agent's reasoning
- **Middle zone**: original long messages get compressed at 50% context into `sessions/<date>.md` — don't rely on middle-of-conversation recall

## User commands

| Command | Action |
|---------|--------|
| `/remember <text>` | Append to project CORE.md |
| `/recall <query>` | Run `scripts/sm-recall.sh <query>` — rg-based search across sessions/ + facts/ |
| `/memory-scrub <pattern>` | Remove matching entries (for PII/secrets accidentally captured) |
| `/memory-status` | Show project key, file sizes, last updated times |

## Privacy

- `$MEMORY_ROOT/` has its own `.gitignore` (created by install.sh)
- Never write API keys, tokens, passwords even if user pastes them
- `/memory-scrub <regex>` provides on-demand cleanup

## References (deeper context — load on demand)

- `references/templates/INDEX.md.tpl` — new project index template
- `references/templates/CORE.md.tpl` — new project core template
- `references/design-notes.md` — design rationale

## Script reference

| Script | Purpose |
|--------|---------|
| `scripts/sm-project-key.sh` | Compute `basename@md5-8` from workspace path |
| `scripts/sm-bootstrap.sh` | Initialize project dirs; print CORE + INDEX |
| `scripts/sm-write.sh` | Atomic append + INDEX sync |
| `scripts/sm-recall.sh` | Keyword search across sessions/ + facts/ |
| `scripts/sm-compress.sh` | Save long-session summary to sessions/ |
| `scripts/sm-status.sh` | Show memory file sizes and timestamps |
