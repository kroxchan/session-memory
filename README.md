# session-memory

Project-scoped persistent memory for Cursor Agent. Prevents context loss in long conversations and across windows. Based on hierarchical indexing (INDEX → CORE → DETAIL) inspired by RAPTOR (ICLR 2024) and HippoRAG (NeurIPS 2024), adapted for single-user IDE use with pure Markdown + filesystem.

## Quick start

```bash
bash install.sh
```

Then restart Cursor. The skill loads automatically and runs every turn.

## Layout

```
session-memory-skill/
├── README.md                    # this file
├── install.sh                   # symlink skill/ into ~/.cursor/skills/
├── docs/
│   └── PRD.md                   # product & design doc (theory, decisions)
└── skill/
    ├── SKILL.md                 # skill entrypoint (loaded by Cursor)
    ├── scripts/
    │   ├── sm-project-key.sh    # basename@md5(path)[:8]
    │   ├── sm-bootstrap.sh      # init dirs + print CORE/INDEX at session start
    │   ├── sm-write.sh          # atomic append + INDEX sync
    │   ├── sm-recall.sh         # rg-based keyword search
    │   ├── sm-compress.sh       # write long-session summary to sessions/
    │   └── sm-status.sh         # inspect memory size per project
    └── references/
        ├── design-notes.md
        └── templates/
            ├── INDEX.md.tpl
            ├── CORE.md.tpl
            ├── global-INDEX.md.tpl
            └── global-CORE.md.tpl
```

## Memory storage

`$MEMORY_ROOT/sessions/` (default: `/Users/vivx/cursor/digital-human/skills/SKILLFORGE/memory/sessions/`)

- `_global/` — cross-project user-level memory
- `projects/<basename>@<md5-8>/` — per-project memory

Memory is **gitignored by default**. Never write secrets.

## Commands (via Agent)

- `/remember <text>` — append to project CORE
- `/recall <query>` — keyword search memory
- `/memory-status` — sizes, last updated
- `/memory-scrub <regex>` — remove matching entries (for accidentally captured PII)

## Uninstall

```bash
bash install.sh --uninstall
# Optional: purge memory data
# rm -rf /Users/vivx/cursor/digital-human/skills/SKILLFORGE/memory/sessions
```

## Theory

See `docs/PRD.md` for full design rationale including:

- Lost in the Middle (Liu et al. 2023) — U-shaped attention, primacy/recency bias
- MemGPT/Letta (Packer et al. 2023) — OS-style tiered memory
- RAPTOR (Sarthi et al. 2024) — collapsed-tree index retrieval
- HippoRAG (Gutiérrez et al. 2024/2025) — index-content separation
- Claude Code best practices — 60/200-line limits, 50% compaction
