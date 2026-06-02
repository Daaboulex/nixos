#!/usr/bin/env python3
# check-scrub-tokens — pre-commit hook for Daaboulex/nixos.
#
# Reads forbidden_tokens + forbidden_patterns from
# $HOME/.ai-context/scripts/scrub-config.json, scans staged diff (or
# --from-file unified diff) for unallowed hits, exits 1 with token + file
# + line + suggested rewrite.
import argparse
import glob
import json
import os
import re
import subprocess
import sys

DEFAULT_CONFIG = os.path.expanduser("~/.ai-context/scripts/scrub-config.json")

DOC_CONTEXTS = {"README.md", "LICENSE", "SECURITY.md", "CHANGELOG.md"}
# Self-reference: scrub infra legitimately mentions tokens in its own
# implementation, fixtures, and test runner.
SKIP_DIRS = (
    ".ai-context/",
    "secrets/",
    "repos/",
    "parts/_build/checks/",
    "parts/_build/tests/",
)
SKIP_FILES = {"flake.lock", "parts/_build/tests.nix"}


def load_config(path):
    if not os.path.exists(path):
        return None  # exit 0 — fresh clone, submodule uninitialized
    try:
        with open(path, "r") as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        print(f"check-scrub-tokens: malformed scrub-config.json: {e}", file=sys.stderr)
        sys.exit(1)


def build_regex(cfg):
    parts = []
    for arr in cfg.get("forbidden_tokens", {}).values():
        for t in arr:
            if not t or len(t) < 3:
                continue
            esc = re.escape(t)
            l = r"\b" if re.match(r"\w", t) else ""
            r_ = r"\b" if re.search(r"\w$", t) else ""
            parts.append(l + esc + r_)
    for arr in cfg.get("forbidden_patterns", {}).values():
        for p in arr:
            try:
                re.compile(p, re.IGNORECASE)
            except re.error as e:
                print(f"check-scrub-tokens: invalid pattern {p!r}: {e}", file=sys.stderr)
                sys.exit(1)
            parts.append(p)
    if not parts:
        return None
    return re.compile("(" + "|".join(parts) + ")", re.IGNORECASE)


def is_doc_context(path):
    if path in DOC_CONTEXTS:
        return True
    if path.startswith("docs/"):
        return True
    if ".example" in path:
        return True
    if path == ".github/workflows/ci.yml":
        return True
    return False


def glob_match(path, pattern):
    """Bash-globstar via Python 3.13 stdlib glob.translate."""
    return re.fullmatch(glob.translate(pattern, recursive=True, include_hidden=True), path) is not None


def token_allowed_here(token, path, context_allowlist):
    # Case-insensitive lookup: the regex is case-insensitive, so token may be
    # "daaboulex" while allowlist key is "Daaboulex".
    token_lower = token.lower()
    for k, globs in context_allowlist.items():
        if k.lower() == token_lower:
            return any(glob_match(path, g) for g in globs)
    return False


def parse_diff(text):
    """Yield (path, lineno, line) for every '+' line in a unified diff."""
    cur_file = None
    cur_lineno = 0
    for raw in text.split("\n"):
        if raw.startswith("+++ b/"):
            cur_file = raw[6:]
            cur_lineno = 0
            continue
        if raw.startswith("@@"):
            m = re.search(r"\+(\d+)", raw)
            if m:
                cur_lineno = int(m.group(1)) - 1
            continue
        if cur_file is None:
            continue
        if raw.startswith("+") and not raw.startswith("+++"):
            cur_lineno += 1
            yield (cur_file, cur_lineno, raw[1:])
        elif raw.startswith(" "):
            cur_lineno += 1
        # '-' lines do not advance + lineno


def scan(diff_text, cfg, regex):
    if regex is None:
        return []
    allow_in_docs = set(cfg.get("allow_in_docs", []))
    context_allowlist = cfg.get("context_allowlist", {})
    rewrites = cfg.get("rewrites", {})

    hits = []
    for path, lineno, content in parse_diff(diff_text):
        if any(path.startswith(d) for d in SKIP_DIRS):
            continue
        if path in SKIP_FILES:
            continue
        for m in regex.finditer(content):
            tok = m.group(0)
            if tok.lower() in {t.lower() for t in allow_in_docs} and is_doc_context(path):
                continue
            if token_allowed_here(tok, path, context_allowlist):
                continue
            # rewrites map is case-sensitive; fall back to placeholder
            suggestion = rewrites.get(tok, f"<{tok}-placeholder>")
            hits.append((path, lineno, tok, content[:120], suggestion))
    return hits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--from-file", help="Path to a unified-diff file (test mode)")
    ap.add_argument("--config", default=DEFAULT_CONFIG,
                    help="Path to scrub-config.json (default: $HOME/.ai-context/scripts/scrub-config.json)")
    args = ap.parse_args()

    cfg = load_config(args.config)
    if cfg is None:
        sys.exit(0)  # config absent — fresh clone, do nothing

    regex = build_regex(cfg)

    if args.from_file:
        with open(args.from_file, "r") as f:
            diff_text = f.read()
    else:
        try:
            diff_text = subprocess.check_output(
                ["git", "diff", "--cached", "--unified=0"],
                encoding="utf-8", errors="replace",
            )
        except subprocess.CalledProcessError as e:
            print(f"check-scrub-tokens: git diff failed: {e}", file=sys.stderr)
            sys.exit(1)

    hits = scan(diff_text, cfg, regex)
    if not hits:
        sys.exit(0)

    print("⚠ check-scrub-tokens: forbidden tokens in staged diff:", file=sys.stderr)
    for path, lineno, tok, text, suggestion in hits[:20]:
        print(f"  {path}:{lineno}  [{tok}] → suggested: {suggestion}", file=sys.stderr)
        print(f"    {text}", file=sys.stderr)
    if len(hits) > 20:
        print(f"  ... {len(hits) - 20} more", file=sys.stderr)
    print("", file=sys.stderr)
    print("Edit the staged file(s) to use the suggested replacement, or add a", file=sys.stderr)
    print("context_allowlist entry to ~/.ai-context/scripts/scrub-config.json if", file=sys.stderr)
    print("the token is legitimately public in this path. Bypass once: git commit --no-verify", file=sys.stderr)
    sys.exit(1)


if __name__ == "__main__":
    main()
