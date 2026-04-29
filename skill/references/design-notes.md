# Design Notes

Reference material supporting `SKILL.md`. Load on demand.

## Why no embeddings?

For single-user IDE scope with < 1000 memory entries per project, keyword search via `rg` has sub-millisecond latency and zero dependencies. Embeddings would add:
- Python env or remote API dependency
- Index build cost on every write
- Opacity — user cannot read vector DB directly

See PRD §4.2 for full rationale.

## Why Markdown not YAML/JSON?

- Human-readable and -editable (user can manually curate)
- Naturally tolerates free-form summaries
- Integrates with every existing tool (Cursor file viewer, `rg`, `cat`)
- Trivial to diff, version, and migrate

## Why two-level index (global + project)?

Following RAPTOR's "collapsed tree" insight (§4.2 of PRD): a flattened index works as well as recursive tree traversal for modest corpora, and is dramatically simpler to implement/debug. Three levels would be overkill for a single-user IDE scope.

## Conflict resolution ordering

If user makes contradictory statements across turns:
1. Most recent `★ CURRENT` entry wins
2. Strikethrough entries are kept for audit but not applied
3. If unsure which is current, ask the user — do NOT silently pick

## Why compress at 50% context not 70%?

HumanLayer team's empirical finding (see Claude Code best practices): Agent performance noticeably degrades past 60-70% context ("dumb zone"). Compressing at 50% leaves headroom for the compression operation itself and avoids entering the dumb zone.

## Why independent memory root?

Storing memories in `~/.cursor/session-memory/memory/` (instead of co-locating with any other system) gives:
- Complete autonomy — not tied to any other skill's lifecycle
- Easy backup/migration — one directory to copy
- Clear .gitignore boundary — one self-contained `.gitignore` file
