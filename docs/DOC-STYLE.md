# Documentation Style Standard

Rules for all files in `docs/`. Derived from the patterns in STYLE.md,
BUILD.md, and ARCHITECTURE.md (the gold-standard trio).

## 1. File naming

**ALLCAPS-KEBAB.md** for all docs. No lowercase, no mixed case.

```text
GOOD:  ARCHITECTURE.md, BUILD.md, SECURE-BOOT.md, STORAGE-STRATEGY.md
BAD:   INSTALLATION.md, MIGRATE-MBP-SDB.md, SECURE-BOOT.md
```

Exception: `options.json` (generated data, not authored prose).

## 2. Title line

Format: `# Topic Name`

- No filename in title (`# ARCHITECTURE.md` → `# Architecture`)
- No dates in title (dates go in frontmatter or footer)
- No version in title unless it's a versioned standard (REPO-STANDARD, STYLE)
- Short: 2-5 words

## 3. Opening block (first 5 lines after title)

Every doc opens with exactly:
1. One sentence stating what question this doc answers
2. One blank line
3. Cross-reference table (if part of core trio) OR "**See also:**" line

```markdown
# Topic Name

What this doc answers in one sentence.

**See also:** [RELATED.md](RELATED.md) for X, [OTHER.md](OTHER.md) for Y.
```

## 4. Voice

- **Imperative, direct.** Write commands, not descriptions.
- **No hedging.** "Do X" not "you might want to consider doing X"
- **No AI voice.** Ban: comprehensive, robust, leverage, utilize, ensure,
  facilitate, streamline, in order to, it's worth noting, here's how
- **No second person narration.** "Run `nrb`" not "you can run `nrb`"
- **RFC 2119** for rules: MUST, SHOULD, MAY (caps when precise)

## 5. Structure

- **Numbered sections** (`## 1. Topic`) for sequential/hierarchical docs
- **Named sections** (`## Topic`) for reference docs
- Tables over bullet lists when data has 2+ dimensions
- Code blocks over inline code for anything >1 token
- One blank line between sections, never two

## 6. Typography

- **Bold** for terms being defined or key constraints
- `Backticks` for code, paths, commands, option names
- *Italic* only for emphasis within a sentence (rare)
- Dash lists (`-`) exclusively, never `*` or `+`
- No trailing whitespace
- No HTML in markdown (except splice markers in READMEs)

## 7. Tables

- Use tables when comparing ≥3 items with ≥2 properties
- Left-align text, right-align numbers
- Keep cells short (wrap to next line if >60 chars)
- Header row: bold content words only if the table is large

## 8. Code blocks

- Always specify language: ````nix`, ````bash`, ````text`
- Commands use `bash`, output uses `text`
- Nix snippets: minimal — show only the relevant fragment
- No `$` prompt prefix (obvious from context)

## 9. Length

- **Target: 50-250 lines** per doc
- Over 300 lines → split into focused sub-docs or use collapsible sections
- Generated reference docs (OPTIONS.md) exempt from length limit
- Every section should justify its existence — cut freely

## 10. Staleness markers

Docs with time-sensitive content include a footer:

```markdown
---
*Last verified: 2026-05-05. Run `nix flake check` to validate.*
```

## 11. What stays OUT of docs/

- One-time migration notes → git commit message
- Session-specific debugging → handoff files
- AI planning artifacts → `.ai-context/.superpowers/`
- Per-host hardware notes → inline comments in host config
- Changelogs → git log + GitHub releases

## Current docs and their compliance

| File | Status | Action needed |
|------|--------|---------------|
| ARCHITECTURE.md | Gold standard | None |
| BUILD.md | Gold standard | None |
| STYLE.md | Gold standard | None |
| OPTIONS.md | Generated | None (auto-regen) |
| REPO-STANDARD.md | Updated | None |
| REPO-DOC-TEMPLATE.md | Updated | None |
| NETWORKING.md | Good | Minor: add opening cross-ref |
| SECRETS.md | Thin (37 lines) | Expand or merge into ARCHITECTURE |
| TESTING.md | Thin (61 lines) | Expand or merge into BUILD |
| PACKAGES.md | OK | Remove "comprehensive" |
| SECURITY-AUDIT-2026-05-04.md | One-time note | Move to git history or archive |
| STORAGE-STRATEGY.md | Host-specific | Keep (MBP storage is complex) |
| TERMINAL-TOOLS.md | Reference list | Trim AI voice |
| INSTALLATION.md | Rename + trim | → INSTALLATION.md |
| MIGRATE-MBP-SDB.md | Rename | → MIGRATE-MBP-SDB.md |
| SECURE-BOOT.md | Rename | → SECURE-BOOT.md |
