#!/usr/bin/env python3
"""check-dangling-refs — unguarded cross-module reference gate (AUDIT.md §19).

Flags RUNTIME-resource references — another module's BINARY or `.desktop` id —
emitted by a `home/modules/<consumer>/` module WITHOUT a guard on that
provider's `config.myModules.home.<provider>.enable`. Such a reference dangles:
disable the provider and the consumer is left invoking a command that is not on
PATH / a launcher whose .desktop is absent — a silent runtime break.

WHY these and not others:
  - option-reads (`config.myModules.home.X…`) are INERT — every module's options
    always exist (files are imported unconditionally); a disabled provider just
    yields its default. Not a runtime break → not flagged.
  - shared-conduit writes (`programs.plasma|zsh|bash`) are inert if the conduit
    is off → conduits are never treated as danglable providers.
  - the healthy form is GUARDED optional consumption (the provider's `.enable`
    wraps the reference, so it self-heals). Detected and passed.

SCOPE: home/modules/**/*.nix only. Host configs (home/hosts/**) are the
composition root and may integrate apps freely — they are exempt by design.

DETECTION is syntactic and deliberately HIGH-CONFIDENCE (gate, not advisory):
  binary    — `terminal <bin>`, `exec <bin>`, `require("<bin>")`, `| <bin>`,
              `getExe pkgs.<bin>`, or a command string `= "<bin> -…"` / `"<bin>"`.
  desktop   — `<reverse.dns>.<module>.desktop`, mapped to a module by EXACT dotted
              segment (so `git` ⊄ `gitlab`).
  guarded   — `<provider>.enable` appears within GUARD_WINDOW lines above the ref
              (their guard style is consistent: optionalString/optionalAttrs/mkIf/
              `if … <provider>.enable`). A ref inside `if X.enable then "…X.desktop"`
              is therefore correctly treated as self-guarded.

Suppress a deliberate reference with a trailing `# dangling-ok: <reason>` comment.

Invocation:
  check-dangling-refs <file…>   # check the given files (tests / manual)
  check-dangling-refs --all     # scan every home/modules/**/*.nix under cwd
  check-dangling-refs           # scan staged home/modules/**/*.nix (pre-commit)
Exit: 0 clean, 1 on any unguarded reference (each printed with reason + fix).
"""
import os
import re
import subprocess
import sys

MODROOT = "home/modules"
GUARD_WINDOW = 18

# Providers that are never danglable: shared HM conduits + ubiquitous base tools.
CONDUIT = {"plasma", "zsh", "bash", "fish", "theme", "xdg"}
UBIQUITOUS = {"git", "gpg", "gnupg", "coreutils"}

# module dir name -> extra binary names it provides (the dir name is always one).
BIN_ALIASES = {
    "neovim": ["nvim"],
    "ripgrep": ["rg"],
    "nix-output-monitor": ["nom"],
}

# High-confidence binary-invocation patterns; each captures the invoked binary.
# Deliberately tight: a flag/`terminal`/`require`/command-key context, never a
# bare word (which FPs on regex alternations and identifier args).
INVOKE = [
    re.compile(r"\bterminal\s+(?P<bin>[a-z][a-z0-9_-]{1,})\b"),
    re.compile(r"\bexec\s+(?P<bin>[a-z][a-z0-9_-]{1,})\b"),
    re.compile(r'\brequire\("(?P<bin>[a-z][a-z0-9_-]{1,})"\)'),
    re.compile(r"\bgetExe'?\b[^\n]*?\bpkgs\.(?P<bin>[a-z][a-z0-9_-]{1,})"),
    # command string: a binary immediately followed by a flag (shell command).
    re.compile(r"""["'](?P<bin>[a-z][a-z0-9_-]{2,})\s+--?"""),
    # command-valued config key = "<bin>" (editor / pager / LSP command / …).
    re.compile(
        r"""\b(?:scrollback_editor|editor|pager|browser|shell|command|serverPath)\b"""
        r"""[^\n]*?["'](?P<bin>[a-z][a-z0-9_-]{1,})["']"""
    ),
]
DESK = re.compile(r"([A-Za-z0-9_]+(?:\.[A-Za-z0-9_-]+)+)\.desktop")
SUPPRESS = re.compile(r"#\s*dangling-ok\b")


def modules(root):
    p = os.path.join(root, MODROOT)
    return sorted(d for d in os.listdir(p) if os.path.isdir(os.path.join(p, d)))


def bin_index(mods):
    """binary name -> provider module (skip conduits / ubiquitous)."""
    idx = {}
    for m in mods:
        if m in CONDUIT or m in UBIQUITOUS:
            continue
        for b in [m] + BIN_ALIASES.get(m, []):
            idx[b] = m
    return idx


def guarded(lines, idx, provider):
    # Strip `#` comments first — a comment that mentions `<provider>.enable`
    # must not be mistaken for an actual guard (it would mask a real dangling).
    pat = re.compile(r"\b%s\.enable\b" % re.escape(provider))
    lo = max(0, idx - GUARD_WINDOW)
    ctx = "\n".join(l.split("#", 1)[0] for l in lines[lo : idx + 1])
    return bool(pat.search(ctx))


def consumer_of(path):
    norm = path.replace("\\", "/")
    if MODROOT + "/" not in norm:
        return None
    return norm.split(MODROOT + "/", 1)[1].split("/")[0]


def scan(path, binidx, modset):
    consumer = consumer_of(path)
    if consumer is None:
        return []
    try:
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    except OSError:
        return []
    out = []
    for i, raw in enumerate(lines):
        if SUPPRESS.search(raw):
            continue
        code = raw.split("#", 1)[0]
        if not code.strip():
            continue
        seen = set()
        # binary invocations
        for rx in INVOKE:
            for m in rx.finditer(code):
                b = m.group("bin")
                prov = binidx.get(b)
                if not prov or prov == consumer or prov in seen:
                    continue
                if guarded(lines, i, prov):
                    continue
                seen.add(prov)
                out.append((consumer, prov, "binary", b, i + 1, raw.strip()))
        # .desktop ids
        for did in DESK.findall(code):
            segs = did.lower().split(".")
            prov = next(
                (m for m in modset if m in segs and m != consumer
                 and m not in CONDUIT and m not in UBIQUITOUS),
                None,
            )
            if not prov or prov in seen or guarded(lines, i, prov):
                continue
            seen.add(prov)
            out.append((consumer, prov, "desktop-id", did + ".desktop", i + 1, raw.strip()))
    return out


def report(findings):
    for consumer, prov, kind, res, line, snip in findings:
        print(f"check-dangling-refs: home/modules/{consumer} → {prov} [{kind}]")
        print(f"  {consumer}/…:{line}  {snip}")
        print(f"  references {prov}'s {kind} `{res}` with no `config.myModules.home.{prov}.enable` guard in scope.")
        print(f"  fix: wrap it in `lib.optionalString config.myModules.home.{prov}.enable ''…''`")
        print(f"       (or `lib.optionalAttrs …` / `lib.mkIf …`); if intentional, add `# dangling-ok: <reason>`.")
        print()


def main(argv):
    root = os.environ.get("DANGLING_ROOT", ".")
    args = [a for a in argv if a != "--all"]
    all_mode = "--all" in argv
    mods = modules(root)
    binidx = bin_index(mods)
    modset = set(mods)

    if args:
        files = args
    elif all_mode:
        files = []
        for dp, _, fns in os.walk(os.path.join(root, MODROOT)):
            files += [os.path.join(dp, fn) for fn in fns if fn.endswith(".nix")]
    else:
        try:
            staged = subprocess.run(
                ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR", "--", MODROOT],
                capture_output=True, text=True, check=True,
            ).stdout.split()
        except (subprocess.CalledProcessError, FileNotFoundError):
            staged = []
        files = [f for f in staged if f.endswith(".nix")]

    findings = []
    for f in files:
        findings += scan(f, binidx, modset)

    if findings:
        report(findings)
        print(f"check-dangling-refs FAILED: {len(findings)} unguarded cross-module reference(s).")
        print("Disabling the referenced module would break these at runtime (AUDIT.md §19).")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
