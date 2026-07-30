#!/usr/bin/env python3
"""check-no-foreign-config — dendritic-invariant gate (AUDIT.md §19).

Enforces: a module MUST NOT assign config under another module's `myModules`
namespace. "A module owns its whole domain; no other module may modify it."

This is the cross-cutting standard that applies to BOTH layers:
  - home/modules/<dir>/   owns  myModules.home.<dir>.*
  - parts/<scope>/<name>  owns  myModules.<scope>.<leaf>.*  (its own leaf; a
    sanctioned contribution to a sibling's accumulator needs `# foreign-ok:`)

A foreign WRITE is an assignment whose LHS is `(config.)?myModules.<ns>.… =`
targeting a namespace the file does not own. READS are fine — the sanctioned
way to express a hard cross-module dependency is an `assertion` reading
`config.myModules.<other>.enable` (a value, never an LHS), so reads are never
flagged. Guarded optional consumption (themeCtx, mkIf …enable) likewise reads,
never writes.

Distinct from inert option-reads and from shared-conduit writes
(`programs.plasma|zsh|bash`, governed elsewhere): this gate is specifically the
`myModules.*` ownership boundary, which has NO legitimate exception.

Suppress a deliberate cross-write with a trailing `# foreign-ok: <reason>`.

Invocation:
  check-no-foreign-config <file…>   # check the given files
  check-no-foreign-config --all     # scan home/modules + parts under cwd / $ROOT
  check-no-foreign-config           # scan staged home/modules + parts (pre-commit)
Exit: 0 clean, 1 on any foreign write (each printed with owner + target + fix).
"""
import os
import re
import subprocess
import sys

ROOTS = ["home/modules", "parts"]
EXCLUDE = ("/_build/", "/hosts/")

OWN_RE = re.compile(r"options\.myModules\.([a-z0-9-]+(?:\.[a-z0-9-]+)*)")
WRITE_RE = re.compile(
    r"""^\s*(?:config\.)?myModules\.(?P<scope>[a-z0-9-]+)(?:\.(?P<leaf>[a-z0-9-]+))?[\w."'\[\] ]*="""
)
SUPPRESS = re.compile(r"#\s*foreign-ok\b")


def base_root():
    return os.environ.get("FOREIGN_ROOT", ".")


def owner(path, root):
    """(scope, leaf-or-None) namespace this file is allowed to write."""
    rel = os.path.relpath(path, root).replace("\\", "/")
    if rel.startswith("home/modules/"):
        return ("home", rel.split("/")[2])  # myModules.home.<dir>
    if rel.startswith("parts/"):
        # scope from the file's own option declaration (authoritative); fall back
        # to the directory for nested parts/<scope>/<name>.nix.
        try:
            decl = OWN_RE.search(open(path, encoding="utf-8", errors="replace").read())
        except OSError:
            decl = None
        if decl:
            # leaf = the module's identity: a parts/<scope>/<name> file owns
            # myModules.<scope>.<leaf>.*, not a sibling leaf in the same scope.
            full = decl.group(1).split(".")
            return (full[0], full[1] if len(full) > 1 else None)
        parts = rel.split("/")
        return (parts[1] if len(parts) > 2 else os.path.splitext(parts[1])[0], None)
    return None


def is_foreign(own, wscope, wleaf):
    oscope, oleaf = own
    if wscope != oscope:
        return True
    # same top scope — for home, the leaf (module dir) is the real identity.
    if oleaf is not None and wleaf is not None and wleaf != oleaf:
        return True
    return False


def scan(path, root):
    own = owner(path, root)
    if own is None:
        return []
    try:
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    except OSError:
        return []
    out = []
    for i, raw in enumerate(lines, 1):
        if SUPPRESS.search(raw):
            continue
        code = raw.split("#", 1)[0]
        m = WRITE_RE.match(code)
        if not m:
            continue
        if is_foreign(own, m.group("scope"), m.group("leaf")):
            ns = "myModules." + m.group("scope") + (("." + m.group("leaf")) if m.group("leaf") else "")
            out.append((path, i, own, ns, raw.strip()))
    return out


def report(findings):
    for path, line, own, ns, snip in findings:
        owns = "myModules." + own[0] + (("." + own[1]) if own[1] else "")
        print(f"check-no-foreign-config: {path}:{line}")
        print(f"  {snip}")
        print(f"  this file owns `{owns}.*` but assigns into `{ns}.*` — another module's domain.")
        print(f"  fix: move this config into the module that owns `{ns}`, expose an option there and")
        print(f"       set it from the host, or assert the dependency; if deliberate, add `# foreign-ok: <reason>`.")
        print()


def main(argv):
    root = base_root()
    args = [a for a in argv if a != "--all"]
    all_mode = "--all" in argv
    if args:
        files = args
    elif all_mode:
        files = []
        for base in ROOTS:
            for dp, _, fns in os.walk(os.path.join(root, base)):
                if any(x in (dp + "/") for x in EXCLUDE):
                    continue
                files += [os.path.join(dp, fn) for fn in fns if fn.endswith(".nix")]
    else:
        try:
            staged = subprocess.run(
                ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR", "--", *ROOTS],
                capture_output=True, text=True, check=True,
            ).stdout.split()
        except (subprocess.CalledProcessError, FileNotFoundError):
            staged = []
        files = [f for f in staged if f.endswith(".nix") and not any(x in f for x in EXCLUDE)]

    findings = []
    for f in files:
        findings += scan(f, root)

    if findings:
        report(findings)
        print(f"check-no-foreign-config FAILED: {len(findings)} foreign-namespace write(s) (dendritic invariant).")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
